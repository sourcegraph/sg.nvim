"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function myplugin(plugin) {
    plugin.registerAutocmd("BufEnter", async () => {
        // const buf = await plugin.nvim.buffer;
        // const bufnr = buf.id;
        const textDocument = {
            uri: "file:///home/tjdevries/projects/cody/cody.ts",
            content: (await plugin.nvim.buffer.lines).join("\n"),
        };
        // Notify agent of focused file...
    }, { pattern: "*" });
    plugin.registerAutocmd("BufReadPost", async () => {
        // const buf = await plugin.nvim.buffer;
        const textDocument = {
            uri: "file:///home/tjdevries/projects/cody/cody.ts",
            content: (await plugin.nvim.buffer.lines).join("\n"),
        };
        // Notify agent of opened file...
    }, { pattern: "*" });
    plugin.registerFunction("CodyTesting", async () => {
        const buf = await plugin.nvim.buffer;
        buf.setLines(["Hello", "World"], { start: 0, end: -1, strictIndexing: false });
        return 42;
    }, { sync: true });
}
exports.default = myplugin;
