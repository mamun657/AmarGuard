const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const en = JSON.parse(fs.readFileSync(path.join(root, 'lib/l10n/app_en.arb'), 'utf8'));
const bn = JSON.parse(fs.readFileSync(path.join(root, 'lib/l10n/app_bn.arb'), 'utf8'));

const enKeys = Object.keys(en);
const bnKeys = Object.keys(bn);

console.log('EN keys:', enKeys.length);
console.log('BN keys:', bnKeys.length);

const missingInBn = enKeys.filter((k) => bnKeys.indexOf(k) < 0);
const extraInBn = bnKeys.filter((k) => enKeys.indexOf(k) < 0);

console.log('missing in bn:', missingInBn.join(', '));
console.log('extra in bn:', extraInBn.join(', '));
