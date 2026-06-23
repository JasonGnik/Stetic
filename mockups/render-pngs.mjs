import puppeteer from 'puppeteer-core';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { mkdirSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const SRC = 'file://' + join(__dirname, 'stetic-score-cards.html');
const OUT = join(__dirname, 'png');
mkdirSync(OUT, { recursive: true });

// card order in the HTML
const names = ['david-laid', 'brad-pitt-troy', 'ronnie-coleman', 'your-analysis'];

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--no-sandbox', '--force-color-profile=srgb'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1400, height: 1200, deviceScaleFactor: 3 });
await page.goto(SRC, { waitUntil: 'networkidle0' });
// let the icon webfont settle
await new Promise(r => setTimeout(r, 600));

const cards = await page.$$('.card');
for (let i = 0; i < cards.length; i++) {
  const file = join(OUT, `stetic-${names[i] || 'card-' + i}.png`);
  await cards[i].screenshot({ path: file });
  console.log('wrote', file);
}

await browser.close();
console.log('done');
