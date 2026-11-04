const fs = require('fs');
const path = require('path');

function load(file) {
  let raw = fs.readFileSync(file, 'utf8');
  if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
  return JSON.parse(raw);
}

const original = load(path.join('tool', 'orig_en_snapshot.arb'));
const originalBengali = load(path.join('tool', 'orig_bn_snapshot.arb'));
const english = load(path.join('lib', 'l10n', 'app_en.arb'));
const bengali = load(path.join('lib', 'l10n', 'app_bn.arb'));

const originalKeys = Object.keys(original);
const englishKeys = Object.keys(english);
const bengaliKeys = Object.keys(bengali);

const missingEnglish = originalKeys.filter((key) => !(key in english));
const missingBengali = englishKeys.filter((key) => !(key in bengali));
const extraBengali = bengaliKeys.filter((key) => !(key in english));
const missingOriginalBengali = Object.keys(originalBengali).filter(
  (key) => !(key in bengali)
);

const placeholderMismatch = [];
for (const key of englishKeys) {
  if (!(key in bengali)) continue;
  const en = english[key];
  const bn = bengali[key];
  if (typeof en !== 'object' || en === null) continue;
  const enPlaceholders = Object.keys(en.placeholders || {});
  const bnPlaceholders = Object.keys((bn && bn.placeholders) || {});
  if (enPlaceholders.join(',') !== bnPlaceholders.join(',')) {
    placeholderMismatch.push({ key, enPlaceholders, bnPlaceholders });
  }
}

console.log('ORIGINAL_KEYS=' + originalKeys.length);
console.log('ENGLISH_KEYS=' + englishKeys.length);
console.log('BENGALI_KEYS=' + bengaliKeys.length);
console.log('MISSING_IN_ENGLISH=' + JSON.stringify(missingEnglish));
console.log('MISSING_IN_BENGALI=' + JSON.stringify(missingBengali));
console.log('EXTRA_IN_BENGALI=' + JSON.stringify(extraBengali));
console.log('MISSING_ORIGINAL_BENGALI=' + JSON.stringify(missingOriginalBengali));
console.log('PLACEHOLDER_MISMATCH=' + JSON.stringify(placeholderMismatch));
