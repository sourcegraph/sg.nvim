"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/index.ts
var src_exports = {};
__export(src_exports, {
  activate: () => activate
});
module.exports = __toCommonJS(src_exports);
var import_coc = require("coc.nvim");
var CodyCompletionItemProvider = class {
  provideCompletionItems(_document, _position, _token, _context) {
    return new Promise((resolve) => {
      (async () => {
        const { nvim } = import_coc.workspace;
        const items = await nvim.callAsync("sg#cody_request", [
          "ignored"
        ]);
        resolve({ isIncomplete: false, items });
      })();
    });
  }
  resolveCompletionItem(_item, _token) {
    return _item;
  }
};
async function activate(context) {
  import_coc.languages.registerCompletionItemProvider(
    "coc-cody-async-comp",
    "cody",
    null,
    new CodyCompletionItemProvider(),
    [".", " ", "(", "{"],
    100
  );
}
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  activate
});
