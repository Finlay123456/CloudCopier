//cloudLinker/src/clipboardStore.js
let clipboard = {
    type: 'text' | 'image', // or 'image'
    data: ''
};
  
function setClipboard(newClipboard) {
    clipboard = newClipboard;
}
  
function getClipboard() {
    return clipboard;
}
  
module.exports = {
    setClipboard,
    getClipboard
};
  