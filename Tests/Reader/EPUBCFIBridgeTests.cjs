// npm install --prefix <test-runtime> jsdom@26.1.0 epubjs@0.3.93
// node Tests/Reader/EPUBCFIBridgeTests.cjs <absolute-test-runtime>/node_modules
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const modules = process.argv[2];
const {JSDOM} = require(modules ? path.join(modules, 'jsdom') : 'jsdom');
const EpubCFI = require(modules ? path.join(modules, 'epubjs/lib/epubcfi.js') : 'epubjs/lib/epubcfi.js').default;
const dom = new JSDOM('<html><head></head><body><p id="first">Önce <em>ara</em> İstanbul, ığüşöç ve 😀 Harry Potter burada okunuyor.</p><p>Sonraki bölüm</p></body></html>', {runScripts: 'outside-only'});
const {window} = dom;
global.Node = window.Node;
global.NodeFilter = window.NodeFilter;
global.XPathResult = window.XPathResult;
const document = window.document;
const target = document.getElementById('first').lastChild;
const offset = target.textContent.indexOf('Harry');
// jsdom has no layout engine. Stub ONLY geometry; real DOM/Range/EPUB.js code handles all anchors.
window.Range.prototype.getClientRects = function () {
    return this.startContainer === target && this.endOffset > offset
        ? [{left: 10, right: 60, top: 10, bottom: 30, width: 50, height: 20}] : [];
};
const source = fs.readFileSync(path.join(__dirname, '../../App/Ekitapligim/Reader/EPUBCFIBridge.js'), 'utf8');
window.eval(source);
const partial = window.ekReaderCFI.current();
const cfi = 'epubcfi(/6/4!' + partial + ')';
const webRange = new EpubCFI(cfi).toRange(document);
assert.equal(webRange.startContainer, target, 'iOS CFI must select the same mixed-content text node in EPUB.js');
assert.equal(webRange.startOffset, offset, 'UTF-16 character anchor must survive, including emoji before the anchor');
assert.equal(target.data.slice(webRange.startOffset, webRange.startOffset + 5), 'Harry');

const webSavedRange = document.createRange();
webSavedRange.setStart(target, offset + 6);
webSavedRange.collapse(true);
const webSaved = new EpubCFI(webSavedRange, '/6/4');
const steps = webSaved.path.steps.map(step => step.type === 'text' ? step.index * 2 + 1 : (step.index + 1) * 2);
const resolved = JSON.parse(window.ekReaderCFI.resolve(steps, webSaved.path.terminal.offset));
const parent = document.querySelector(resolved.selector);
const restoredText = parent.childNodes[resolved.textNodeIndex];
assert.equal(restoredText, target, 'Web CFI must resolve to the same Readium DOM range parent/text index');
assert.equal(resolved.offset, offset + 6);
document.body.style.fontSize = '28px';
assert.deepEqual(JSON.parse(window.ekReaderCFI.resolve(steps, webSaved.path.terminal.offset)), resolved, 'Text anchor is independent of font setting');
assert.throws(() => window.ekReaderCFI.resolve([4, 200, 1], 0), /missing/);
assert.throws(() => window.ekReaderCFI.resolve(steps, 10000), /invalid/);
// Validate that the exact character range, rather than the paragraph rectangle, drives scrolling.
let measuredStart = null, measuredOffset = null, scrolled = null;
window.Range.prototype.getBoundingClientRect = function () {
    measuredStart = this.startContainer; measuredOffset = this.startOffset;
    return {left: 500, right: 510, top: 900, bottom: 920, width: 10, height: 20};
};
Object.defineProperty(document, 'scrollingElement', {value: document.documentElement});
Object.defineProperty(document.documentElement, 'scrollWidth', {value: 2000});
Object.defineProperty(document.documentElement, 'scrollHeight', {value: 3000});
window.readium = {scrollToPosition: (...args) => { scrolled = args; }};
const unchangedDOM = document.body.innerHTML;
assert.equal(window.ekReaderCFI.restore(steps, offset + 6), true);
assert.equal(measuredStart, target);
assert.equal(measuredOffset, offset + 6);
assert.deepEqual(scrolled, [0.25, 'ltr', false]);
document.documentElement.style.setProperty('--USER__view', 'readium-scroll-on');
window.ekReaderCFI.restore(steps, offset + 6);
assert.deepEqual(scrolled, [0.3, 'ltr', false]);
assert.equal(document.body.innerHTML, unchangedDOM, 'Restoring must not split or mutate text nodes');
console.log('EPUB.js ↔ Readium CFI bridge: mixed DOM, Unicode, font-independent anchors and invalid positions passed.');
