// Mechanical crops only: all artwork comes from the owner's unmodified PNG.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const root = __dirname;
const source = require('./source.json');
const manifest = require('./manifest.json');
async function normalized(file) {
  // Trim transparent margins, preserving the complete painted silhouette.
  const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let left=info.width,top=info.height,right=0,bottom=0;
  for(let y=0;y<info.height;y++) for(let x=0;x<info.width;x++) {
    if(data[(y*info.width+x)*4+3]) {left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);}
  }
  return sharp(file).extract({left,top,width:right-left+1,height:bottom-top+1})
    .resize(112,112,{fit:'contain',background:'#00000000'})
    .extend({top:8,bottom:8,left:8,right:8,background:'#00000000'}).png().toBuffer();
}
async function build() {
  const input=fs.readFileSync(path.join(root,source.source));
  assert.equal(crypto.createHash('sha256').update(input).digest('hex'),source.sha256,'Original source changed');
  for(const dir of ['crops','png']) fs.mkdirSync(path.join(root,dir),{recursive:true});
  for(const crop of source.crops) await sharp(input).extract(crop.rect).png().toFile(path.join(root,'crops',crop.id+'.png'));
  const color=[],mono=[],preview=[];
  for(const icon of manifest.icons) {
    const png=await normalized(path.join(root,'crops',icon.sourceCrop+'.png'));
    fs.writeFileSync(path.join(root,'png',icon.id+'.png'),png);
    const gray=await sharp(png).greyscale().toColourspace('srgb').png().toBuffer();
    const [left,top]=icon.offset;
    color.push({input:png,left,top});mono.push({input:gray,left,top});
    const i=manifest.icons.indexOf(icon),px=(i%4)*256,py=Math.floor(i/4)*160;
    preview.push({input:png,left:px,top:py},{input:await sharp(png).resize(32,32).toBuffer(),left:px+132,top:py+48},{input:await sharp(gray).resize(32,32).toBuffer(),left:px+176,top:py+48});
    // SVG is used only for preview captions, never for icon artwork.
    preview.push({input:Buffer.from(`<svg width="250" height="28"><text x="8" y="20" fill="white" font-family="sans-serif" font-size="16">${icon.id} (${icon.sourceCrop})</text></svg>`),left:px,top:py+128});
  }
  for(const [name,layers] of [[manifest.sheet,color],[manifest.tintableSheet,mono]]) {
    // Copy decoded pixels directly; alpha compositing can round edge colors.
    const atlas=Buffer.alloc(1024*640*4);
    for(const layer of layers) {
      const pixels=await sharp(layer.input).raw().toBuffer();
      for(let y=0;y<128;y++) pixels.copy(atlas,((layer.top+y)*1024+layer.left)*4,y*128*4,(y+1)*128*4);
    }
    await sharp(atlas,{raw:{width:1024,height:640,channels:4}}).png().toFile(path.join(root,name));
  }
  await sharp({create:{width:1024,height:1600,channels:4,background:'#191c32'}}).composite(preview).png().toFile(path.join(root,'preview.png'));
  fs.copyFileSync(path.join(root,'preview.png'),path.join(root,'../../docs/reference/images/ui-icons.png'));
}
if(require.main===module) build().catch(e=>{console.error(e);process.exitCode=1;});
module.exports={normalized};
