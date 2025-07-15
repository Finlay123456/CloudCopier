//cloudLinker/src/clipboardStore.js
let clipboard = {
    formats: {},
    timestamp: Date.now(),
    source: 'unknown'
};
  
function setClipboard(newClipboard) {
    clipboard = {
        ...newClipboard,
        timestamp: Date.now()
    };
}
  
function getClipboard() {
    return clipboard;
}

function hasFormat(format) {
    return clipboard.formats && clipboard.formats.hasOwnProperty(format);
}

function getFormat(format) {
    return clipboard.formats ? clipboard.formats[format] : null;
}
  
module.exports = {
    setClipboard,
    getClipboard,
    hasFormat,
    getFormat
};
  