const { Plugin } = require('obsidian');

module.exports = class NoMiddlePaste extends Plugin {
  onload() {
    const block = (e) => { if (e.button === 1) e.preventDefault(); };
    this.registerDomEvent(window, 'mouseup', block, true);
    // popout windows get their own window object
    this.registerEvent(this.app.workspace.on('window-open', (_, win) =>
      this.registerDomEvent(win, 'mouseup', block, true)));
  }
};
