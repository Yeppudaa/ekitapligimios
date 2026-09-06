/* Point anchors shared with EPUB.js. This runs only inside Readium's current book resource. */
globalThis.ekReaderCFI = (() => {
    const textNodes = element => Array.from(element.childNodes).filter(n => n.nodeType === 3);
    const selector = element => {
        const steps = [];
        while (element && element !== document.documentElement) {
            const parent = element.parentElement;
            if (!parent) throw new Error('Detached EPUB node');
            steps.unshift(':nth-child(' + (Array.from(parent.children).indexOf(element) + 1) + ')');
            element = parent;
        }
        return ':root' + (steps.length ? ' > ' + steps.join(' > ') : '');
    };
    const path = node => {
        const steps = [];
        if (node.nodeType === 3) {
            steps.unshift(textNodes(node.parentElement).indexOf(node) * 2 + 1);
            node = node.parentElement;
        }
        while (node && node !== document.documentElement) {
            const parent = node.parentElement;
            if (!parent) throw new Error('Detached EPUB node');
            steps.unshift((Array.from(parent.children).indexOf(node) + 1) * 2);
            node = parent;
        }
        return '/' + steps.join('/');
    };
    const visible = rect => rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.top < innerHeight && rect.right > 0 && rect.left < innerWidth;
    function current() {
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        let node;
        while ((node = walker.nextNode())) {
            if (!node.data.trim()) continue;
            const style = getComputedStyle(node.parentElement);
            if (style.visibility === 'hidden' || style.display === 'none' || style.opacity === '0') continue;
            const range = document.createRange();
            range.selectNodeContents(node);
            if (!Array.from(range.getClientRects()).some(visible)) continue;
            // DOM and EPUB CFI offsets both use UTF-16, including Turkish and supplementary characters.
            for (let offset = 0; offset < node.length; offset++) {
                const size = node.data.codePointAt(offset) > 0xFFFF ? 2 : 1;
                range.setStart(node, offset);
                range.setEnd(node, offset + size);
                if (node.data.slice(offset, offset + size).trim() && Array.from(range.getClientRects()).some(visible)) {
                    return path(node) + ':' + offset;
                }
                if (size === 2) offset++;
            }
        }
        // Image-only/fixed-layout pages still have a stable element anchor.
        const element = Array.from(document.body.querySelectorAll('img,svg,image')).find(e => visible(e.getBoundingClientRect()));
        if (element) return path(element);
        throw new Error('No visible EPUB anchor');
    }
    function resolveNode(steps, offset) {
        let node = document.documentElement;
        for (const step of steps) {
            node = step % 2 === 0 ? node.children[step / 2 - 1] : textNodes(node)[(step - 1) / 2];
            if (!node) throw new Error('Saved EPUB node is missing');
        }
        if (node.nodeType === 3) {
            if (offset > node.length) throw new Error('Saved EPUB offset is invalid');
        }
        return node;
    }
    function resolve(steps, offset) {
        const node = resolveNode(steps, offset);
        if (node.nodeType === 3) {
            return JSON.stringify({selector: selector(node.parentElement), textNodeIndex: Array.from(node.parentElement.childNodes).indexOf(node), offset});
        }
        return JSON.stringify({selector: selector(node), textNodeIndex: null, offset: null});
    }
    function restore(steps, offset) {
        const node = resolveNode(steps, offset);
        const range = document.createRange();
        if (node.nodeType === 3) {
            range.setStart(node, offset);
            range.setEnd(node, Math.min(node.length, offset + (node.data.codePointAt(offset) > 0xFFFF ? 2 : 1)));
        } else {
            range.selectNode(node);
        }
        const rect = range.getBoundingClientRect();
        const root = document.scrollingElement;
        const style = getComputedStyle(document.documentElement);
        const vertical = style.getPropertyValue('writing-mode').startsWith('vertical');
        const rtl = style.getPropertyValue('direction') === 'rtl' || style.getPropertyValue('writing-mode') === 'vertical-rl';
        const scrolling = document.documentElement.style.getPropertyValue('--USER__view').trim() === 'readium-scroll-on';
        const offsetInResource = scrolling && !vertical ? rect.top + scrollY : Math.abs(rect.left + scrollX);
        const extent = scrolling && !vertical ? root.scrollHeight : root.scrollWidth;
        if (!extent || !globalThis.readium?.scrollToPosition) throw new Error('Reader layout is unavailable');
        // Readium 3.9 ignores domRange in scrollToLocator. Resolve the exact DOM character range,
        // then let its public scrollToPosition perform column snapping/RTL/scroll-mode handling.
        readium.scrollToPosition(Math.min(1, Math.max(0, offsetInResource / extent)), rtl ? 'rtl' : 'ltr', false);
        return true;
    }
    return {current, resolve, restore};
})();
