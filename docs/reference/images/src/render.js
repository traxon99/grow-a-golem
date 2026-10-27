const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  for (const [name, h] of [['hud-layout',720],['shop-layout',720],['reward-popup',720],['mobile-safe-areas',720],['rarity-colors',420],['ui-materials',500]]) {
    await p.setViewportSize({ width: 1280, height: h });
    await p.goto('file://' + path.join(__dirname, name + '.html'));
    await p.screenshot({ path: path.join(__dirname, '..', name + '.png') });
  }
  await b.close();
})();
