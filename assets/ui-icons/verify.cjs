// Validate the exported assets against the game's actual inventory and registry.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const root = __dirname;
const project = path.resolve(root, '../..');
const m = JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
const config = fs.readFileSync(path.join(project,'src/shared/Config.luau'),'utf8');
const menus = fs.readFileSync(path.join(project,'src/client/Menus.luau'),'utf8');
const ids = new Set(m.icons.map(a=>a.id));
assert.equal(ids.size,m.icons.length,'Duplicate icon key');
const order = name => [...config.match(new RegExp(`Config.${name} = \\{([^}]+)`))[1].matchAll(/"([^"]+)"/g)].map(x=>x[1]);
const minerals = [...order('MineralOrder'), ...[...config.matchAll(/table.insert\(Config.MineralOrder, "([^"]+)"\)/g)].map(x=>x[1])];
const tabs = [...menus.slice(menus.indexOf('local TABS')).matchAll(/\{ id = "([^"]+)", name =/g)].map(x=>x[1]);
assert.equal(tabs.length,13,'Menu detection failed or inventory changed');
for(const id of [...minerals,...order('SpellOrder'),...tabs]) assert(ids.has(id),`Missing game icon ${id}`);
(async()=>{
 const crypto = require('node:crypto');
 const provenance = require('./source.json');
 const original = fs.readFileSync(path.join(root,provenance.source));
 assert.equal(crypto.createHash('sha256').update(original).digest('hex'),provenance.sha256,'Source bytes changed');
 assert.equal(provenance.crops.length,48);
 for(const crop of provenance.crops) {
  const expected = await sharp(original).extract(crop.rect).raw().toBuffer();
  const actual = await sharp(path.join(root,'crops',crop.id+'.png')).raw().toBuffer();
  assert(expected.equals(actual),`${crop.id}: crop differs from original pixels`);
 }
 const {normalized} = require('./build.cjs');
 for(const icon of m.icons) {
  assert(provenance.crops.some(c=>c.id===icon.sourceCrop),`${icon.id}: unknown source crop`);
  const expected = await normalized(path.join(root,'crops',icon.sourceCrop+'.png'));
  const actual = fs.readFileSync(path.join(root,'png',icon.id+'.png'));
  assert(expected.equals(actual),`${icon.id}: does not match original crop`);
  for(const sheet of [m.sheet,m.tintableSheet]) {
   const input = sheet===m.sheet ? sharp(expected) : sharp(expected).greyscale().toColourspace('srgb');
   const pixels = await input.raw().toBuffer();
   const packed = await sharp(path.join(root,sheet)).extract({left:icon.offset[0],top:icon.offset[1],width:128,height:128}).raw().toBuffer();
   assert(pixels.equals(packed),`${icon.id}: atlas differs from original crop`);
  }
 }

 for(const sheet of [m.sheet,m.tintableSheet]) {
  const {data,info} = await sharp(path.join(root,sheet)).raw().toBuffer({resolveWithObject:true});
  assert.equal(info.width,m.sheetSize[0]);assert.equal(info.height,m.sheetSize[1]);assert.equal(info.channels,4);
  for(const a of m.icons) {
   const [x,y]=a.offset,[w,h]=a.size;
   assert(x>=0&&y>=0&&x+w<=info.width&&y+h<=info.height,`${a.id}: out of bounds`);
   const expected=`${a.id} = { x = ${x}, y = ${y}, fallback = "${a.fallback}" }`;
   assert(config.includes(expected),`${a.id}: registry drift`);
   let visible=0;
   for(let cy=0;cy<h;cy++) for(let cx=0;cx<w;cx++) {
    const offset=((y+cy)*info.width+x+cx)*4;
    const alpha=data[offset+3];if(alpha)visible++;
    if(cx<4||cy<4||cx>=w-4||cy>=h-4)assert.equal(alpha,0,`${a.id}: missing transparent gutter`);
    if(sheet===m.tintableSheet&&alpha)assert(data[offset]===data[offset+1]&&data[offset+1]===data[offset+2],`${a.id}: not neutral grayscale`);
   }
   assert(visible>100,`${a.id}: empty icon`);
  }
 }
 console.log(`PASS: ${m.icons.length} icons; all ${tabs.length} tabs, ${minerals.length} minerals and 3 spells; registry, dimensions, neutral tint sheet, alpha gutters.`);
})();
