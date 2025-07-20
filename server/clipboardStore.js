let clipboard = {
  formats: {},
  timestamp: Date.now(),
  source: 'unknown'
};

function setClipboard(data) {
  clipboard = {
    formats: data.formats || {},
    timestamp: Date.now(),
    source: data.source || 'unknown'
  };
  
  console.log(`Clipboard updated from ${clipboard.source} at ${new Date(clipboard.timestamp).toISOString()}`);
  console.log('Formats:', Object.keys(clipboard.formats));
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