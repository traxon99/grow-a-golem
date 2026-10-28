// Original vector artwork for #83. Run from any directory: node assets/ui-icons/build.cjs
// Requires sharp 0.35.x. SVG sources and the manifest are the editable contract.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = __dirname;
const ink = '#111827', white = '#f4f6ff', accent = '#91a1b8';
const p = (d, fill=white, width=6) => `<path d="${d}" fill="${fill}" stroke="${ink}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"/>`;
const line = d => p(d, 'none');
const rune = (d, width=8) => p(d, 'none', width+6) + p(d, 'none', width).replace(`stroke="${ink}"`, `stroke="${white}"`);
const circle = (x,y,r,fill=white) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${ink}" stroke-width="6"/>`;
const gem = (x=64,y=56,s=1) => `<g transform="translate(${x} ${y}) scale(${s})">${p('M0 -32 24 -6 0 32 -24 -6Z')}${p('M0 -32 0 32 24 -6Z',accent,3)}</g>`;
const star = (n,r=43,inner=21) => p(Array.from({length:n*2},(_,i)=>{const a=i*Math.PI/n-Math.PI/2; const d=i%2?inner:r;return `${i?'L':'M'}${64+Math.cos(a)*d} ${64+Math.sin(a)*d}`}).join(' ')+'Z');
const icons=[];
function add(id,label,category,art,fallback,issues=[83]) { icons.push({id,label,category,art,fallback,issues}); }
add('forge','Forge','menu',p('M20 66H107L89 83H73V98H86V108H36V98H49V83H32Z')+p('M51 19 67 19 67 34 82 34 82 49 51 49Z',accent)+line('M61 48 44 66')+p('M61 78 67 84 61 90 55 84Z',ink,2),'F',[83,84,86]);
add('travel','Travel','menu',p('M26 100V58A38 38 0 0 1 102 58V100H85V58A21 21 0 0 0 43 58V100Z')+p('M64 44 78 66 64 88 50 66Z',accent)+line('M18 104H110'),'T',[83,84,87]);
add('artifacts','Artifacts','menu',gem(64,51)+p('M36 89H92L102 106H26Z',accent)+line('M18 47H25 M103 47H110 M64 13V18'),'A',[83,84,88,97]);
add('skills','Skills','menu',rune('M64 106V38 M64 77 29 55V34 M64 64 99 43V26')+gem(64,27,.42)+gem(28,27,.36)+gem(99,23,.36)+p('M44 106H84',accent),'S',[83,84,92]);
add('awaken','Awaken','menu',star(4,38,14)+line('M25 102 38 91 M103 102 90 91 M64 112V103'),'Aw',[83,84,92]);
add('quests','Quests','menu',p('M32 21H94Q108 21 108 37H92V89Q92 108 75 108H22V92H35V37Q35 21 22 21Z')+line('M48 51H78 M48 66H72')+p('M52 83 61 92 79 76','none'),'Q',[83,84,91]);
add('events','Events','menu',line('M25 16V111 M20 23H108')+p('M37 23H100V92L69 77 37 92Z')+gem(68,50,.42),'E',[83,84,93]);
add('party','Party','menu',rune('M39 74Q64 102 89 74',6)+gem(38,49,.72)+gem(90,49,.72),'P',[83,84,95]);
add('hub','Hub','menu',p('M33 106 40 41H88L95 106Z')+p('M32 22H47V32H57V17H72V32H82V22H97V45H32Z',accent)+p('M54 106V80Q64 65 74 80V106Z',ink),'H',[83,84,94]);
add('trade','Trade','menu',gem(64,40,.6)+p('M15 63 31 63 44 76 58 76Q68 81 59 88H39L52 101H24Z')+p('M113 63 97 63 84 76 70 76Q60 81 69 88H89L76 101H104Z'),'Tr',[83,84,94]);
add('wardrobe','Wardrobe','menu',p('M33 91 59 18 83 31 72 43 95 91Z',accent)+p('M17 94Q64 76 111 94L104 107H24Z')+gem(64,75,.3),'W',[83,84,90]);
add('shop','Shop','menu',p('M36 36H92L104 105H24Z')+rune('M48 40V29A16 16 0 0 1 80 29V40',6)+gem(64,73,.55),'Sh',[83,84,89]);
add('ranks','Ranks','menu',p('M24 98 15 38 42 58 64 23 86 58 113 38 104 98Z')+p('M25 98H103V110H25Z',accent)+gem(64,73,.35),'R',[83,84,95]);
add('stone','Stone','mineral',p('M20 53 43 24 82 20 107 56 99 98 59 109 22 91Z')+p('M43 24 54 67 22 91 M54 67 99 98','none'),'St');
add('copper','Copper','mineral',p('M22 58 37 28 88 28 108 58 96 99H34Z',accent)+p('M42 43H85L95 68 79 86H48L33 67Z')+line('M42 43 48 65H89'),'Cu');
add('iron','Iron','mineral',p('M18 76 34 38H90L111 76 93 99H35Z')+p('M18 76H111L93 99H35Z',accent)+line('M34 38 45 65H94'),'Fe');
add('crystal','Crystal','mineral',gem(64,61,1.4),'Cr');
add('stormglass','Stormglass','mineral',p('M45 18H85L107 65 64 111 21 65Z')+p('M70 32 44 66H61L54 92 84 54H65Z',ink,3),'Sg');
add('abyssite','Abyssite','mineral',p('M31 34 73 18 107 53 92 99 46 108 19 73Z')+p('M77 38Q38 35 39 69Q41 98 77 87Q57 76 58 62Q59 47 77 38Z',ink,3),'Ab');
add('sunsteel','Sunsteel','mineral',p('M26 47 46 30H90L107 75 87 99H39L18 75Z')+circle(65,64,17,accent)+line('M65 37V43 M65 85V91 M38 64H44 M86 64H92'),'Ss');
add('aether','Aether','mineral',p('M64 18 97 48 83 96 45 106 25 63Z',accent)+p('M64 31 73 56 94 64 73 73 64 96 55 73 34 64 55 56Z'),'Ae');
add('xp','XP','currency',star(5),'XP',[83,85,92,97]);
add('eventPoints','Event points','currency',p('M25 30H103V50Q85 64 103 78V98H25V78Q43 64 25 50Z')+gem(64,64,.55),'EP',[83,93]);
add('quake','Quake','spell',p('M24 24H104V104H24Z',accent)+p('M68 24 48 58 72 64 51 104','none',9)+line('M15 42 10 32 M113 86 118 96'),'Q',[83,96]);
add('mend','Mend','spell',p('M64 109Q15 80 18 49Q22 20 48 31L64 46 80 31Q106 20 110 49Q113 80 64 109Z')+p('M57 49H71V63H85V77H71V91H57V77H43V63H57Z',ink,2),'E',[83,96]);
add('magnet','Magnet','spell',p('M28 22H49V66Q49 89 64 89Q79 89 79 66V22H100V66Q100 111 64 111Q28 111 28 66Z')+line('M28 44H49 M79 44H100')+gem(64,40,.3),'R',[83,96]);
add('common','Common','rarity',circle(64,64,37),'1',[83,82,88]);
add('uncommon','Uncommon','rarity',p('M64 18 109 64 64 110 19 64Z'),'2',[83,82,88]);
add('rare','Rare','rarity',p('M64 19 109 103H19Z'),'3',[83,82,88]);
add('epic','Epic','rarity',star(4),'4',[83,82,88]);
add('legendary','Legendary','rarity',star(5),'5',[83,82,88]);
add('mythic','Mythic','rarity',star(6),'6',[83,82,88]);
add('tick','Complete','status',rune('M21 66 48 94 108 33',12),'OK',[83,85,91,94]);
add('lock','Locked','status',rune('M39 54V40A25 25 0 0 1 89 40V54',8)+p('M27 54H101V109H27Z')+circle(64,76,7,ink)+line('M64 83V93'),'L',[83,87]);
add('alert','Attention','status',circle(64,64,46)+p('M58 33H70V71H58Z',ink,2)+circle(64,88,5,ink),'!',[83,84]);
add('close','Close','status',rune('M30 30 98 98 M98 30 30 98',12),'X',[83,84]);
add('guide','Wizard guide','portrait',p('M25 102Q64 73 103 102L110 116H18Z',accent)+p('M35 57H93V82Q64 118 35 82Z')+p('M32 56 59 13 83 24 73 34 96 56Z',accent)+p('M21 53H107V66H21Z')+circle(50,77,3,ink)+circle(78,77,3,ink)+line('M54 90Q64 98 74 90'),'G',[83,87]);
const manifest={version:1,sourceIssue:83,sheet:'mystical.png',tintableSheet:'mystical-mono.png',sheetSize:[1024,640],cellSize:128,columns:8,icons:[]};
const svg=(body,w=128,h=128)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
const colorFor = c=>({menu:'#8ddcf5',mineral:'#b7a3ee',currency:'#8ddcf5',spell:'#9ed49a',rarity:'#ddd8f4',status:'#f4f6ff',portrait:'#b7a3ee'})[c];
(async()=>{
 fs.mkdirSync(path.join(root,'src'),{recursive:true});fs.mkdirSync(path.join(root,'png'),{recursive:true});
 let mono='',colored='',preview='';
 for(const [i,a] of icons.entries()) {
  const x=i%8*128,y=Math.floor(i/8)*128;
  const art=a.art; let color=colorFor(a.category);
  if(a.id==='forge'||a.id==='copper'||a.id==='quake')color='#f3b07c';
  if(a.id==='legendary'||a.id==='sunsteel')color='#efce7b';
  const painted=art.replaceAll(white,color);
  const src=svg(painted);fs.writeFileSync(path.join(root,'src',a.id+'.svg'),src+'\n');
  await sharp(Buffer.from(src)).png().toFile(path.join(root,'png',a.id+'.png'));
  mono+=`<g transform="translate(${x} ${y})">${art.replaceAll(accent,'#b4b4b4').replaceAll(white,'#f6f6f6').replaceAll(ink,'#181818')}</g>`;
  colored+=`<g transform="translate(${x} ${y})">${painted}</g>`;
  const px=i%8*160,py=Math.floor(i/8)*206+110;
  preview+=`<g transform="translate(${px+16} ${py})">${painted}</g><text x="${px+80}" y="${py+146}" text-anchor="middle" fill="#e9efff" font-family="sans-serif" font-size="14">${a.label}</text><g transform="translate(${px+37} ${py+159}) scale(.25)">${painted}</g><g transform="translate(${px+88} ${py+159}) scale(.25)">${art.replaceAll(accent,'#b4b4b4').replaceAll(white,'#f6f6f6').replaceAll(ink,'#181818')}</g>`;
  manifest.icons.push({id:a.id,label:a.label,category:a.category,offset:[x,y],size:[128,128],fallback:a.fallback,issues:a.issues});
 }
 for(const [name,body] of [['mystical',colored],['mystical-mono',mono]]) {
  const src=svg(body,1024,640);fs.writeFileSync(path.join(root,name+'.svg'),src+'\n');
  await sharp(Buffer.from(src)).png().toFile(path.join(root,name+'.png'));
 }
 const proof=svg(`<rect width="1280" height="1160" fill="#141e32"/><text x="32" y="44" fill="#f4f6ff" font-family="sans-serif" font-size="28" font-weight="bold">GROW A GOLEM / MYSTICAL ICONS</text><text x="32" y="77" fill="#b4c7e4" font-family="sans-serif" font-size="16">Issue #83 · 37 original symbols · 128 px and 32 px · color + grayscale proofs</text>${preview}`,1280,1160);
 fs.writeFileSync(path.join(root,'preview.svg'),proof+'\n');
 await sharp(Buffer.from(proof)).png().toFile(path.join(root,'preview.png'));
 fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 console.log(`Built ${icons.length} icons and two 1024x640 atlases.`);
})();
