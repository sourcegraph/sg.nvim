import type { NvimPlugin } from "neovim";

export interface ProtocolTextDocument {
    // Use TextDocumentWithUri.fromDocument(TextDocument) if you want to parse this `uri` property.
    uri: string
    content?: string
    selection?: Range
}

export default function myplugin(plugin: NvimPlugin) {
    plugin.registerAutocmd("BufEnter", async () => {
        // const buf = await plugin.nvim.buffer;
        // const bufnr = buf.id;
        const textDocument: ProtocolTextDocument = {
            uri: "file:///home/tjdevries/projects/cody/cody.ts",
            content: (await plugin.nvim.buffer.lines).join("\n"),
        };

        // Notify agent of focused file...
    }, { pattern: "*" })

    plugin.registerAutocmd("BufReadPost", async () => {
        // const buf = await plugin.nvim.buffer;
        const textDocument: ProtocolTextDocument = {
            uri: "file:///home/tjdevries/projects/cody/cody.ts",
            content: (await plugin.nvim.buffer.lines).join("\n"),
        };

        // Notify agent of opened file...
    }, { pattern: "*" })

    plugin.registerFunction("CodyTesting", async () => {
        const buf = await plugin.nvim.buffer;
        buf.setLines(["Hello", "World"], { start: 0, end: -1, strictIndexing: false })

        return 42;
    }, { sync: true })
}
