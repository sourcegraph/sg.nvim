local cli = require "sg.cli"
local lib = require "sg.lib"
local log = require "sg.log"
local rpc = require "sg.lsp.rpc"
local transform = require "sg.lsp.transform"
local utils = require "sg.utils"

local protocol = vim.lsp.protocol

local Config = {}

local methods = {}

function methods.initialize(params, id)
  if Initialized then
    error "already initialized!"
  end

  Config.root = params.rootPath or params.rootUri

  log.info("Config.root = %q", Config.root)

  -- analyze.load_completerc(Config.root)
  -- analyze.load_luacheckrc(Config.root)

  --ClientCapabilities = params.capabilities
  Initialized = true

  -- hopefully this is modest enough
  return rpc.respond(id, nil, {
    capabilities = {
      -- completionProvider = {
      --   triggerCharacters = {".",":"},
      --   resolveProvider = false
      -- },
      definitionProvider = true,
      textDocumentSync = {
        openClose = true,

        -- Always send everything
        change = protocol.TextDocumentSyncKind.Full,

        -- Please send the whole text when you save
        -- because I'm too noob to do incremental stuff at the moment.
        save = { includeText = true },
      },
      hoverProvider = false,
      documentSymbolProvider = false,
      referencesProvider = true,
      --documentHighlightProvider = false,
      --workspaceSymbolProvider = false,
      --codeActionProvider = false,
      --documentFormattingProvider = false,
      --documentRangeFormattingProvider = false,
      --renameProvider = false,
    },
  })
end

local file_states = {}

-- interface DidOpenTextDocumentParams {
--     -- The document that was opened.
--     textDocument: TextDocumentItem;
-- }
methods["textDocument/didOpen"] = function(params)
  file_states[params.textDocument.uri] = vim.split(params.textDocument.text, "\n")
end

methods["textDocument/didChange"] = function(_)
  return
end

-- interface DidSaveTextDocumentParams {
--  -- The document that was saved.
--  textDocument: TextDocumentIdentifier;
--
--  -- Optional the content when saved.
--  -- Depends on the includeText value when the save notification was requested.
--  text?: string;
-- }
methods["textDocument/didSave"] = function(_)
  return
end

methods["textDocument/didClose"] = function(_)
  return
end

local DefinitionGraphQL = [[
query ($repository: String!, $revision: String!, $path: String!, $line: Int!, $character: Int!, $query: String!) {
  repository(name: $repository) {
    commit(rev: $revision) {
      blob(path: $path) {
        name
        path
        lsif {
          definitions(line: $line, character: $character) {
            nodes {
              url
              resource {
                path
              }
              range {
                start {
                  line
                  character
                }
                end {
                  line
                  character
                }
              }
            }
          }
        }
      }
    }
  }

  search(patternType: regexp, query: $query) {
    results {
      results {
        __typename
        ... on FileMatch {
          symbols {
            name
            canonicalURL
            location {
              range {
                start {
                  line
                  character
                }
                end {
                  line
                  character
                }
              }
            }
          }
        }
      }
    }
  }
}
]]

-- query:  "repo:^github.com/neovim/neovim$@HEAD type:symbol patternType:regexp ^nlua_traverse_table$"

-- interface TextDocumentPositionParams {
--   textDocument: TextDocumentIdentifier
--   position: Position
-- }
methods["textDocument/definition"] = function(params, id)
  local uri = lib.get_remote_file(params.textDocument.uri)

  local repository = uri.remote
  local rev = uri.commit
  local path = uri.path
  local line = params.position.line
  local character = params.position.character

  local state = file_states[params.textDocument.uri]
  local symbol = utils.get_word_around_character(state[line + 1], character)

  log.info("definition request...", "commit=", rev)
  local output = cli.api(DefinitionGraphQL, {
    -- $repository: String!
    repository = repository,
    -- $revision: String!
    revision = rev,
    -- $path: String!
    path = path,
    -- $line: Int!
    line = line,
    -- $character: Int!
    character = character,
    -- $query: String!
    query = string.format("repo:^%s$@%s type:symbol patternType:regexp ^%s$", repository, rev, symbol),
  })

  log.info(
    "definiton: output",
    string.format("^%s$@%s type:symbol patternType:regexp ^%s$", repository, rev, symbol),
    output
  )

  --[[
  data = {
    repository = {
      commit = {
        blob = {
          lsif = {
            definitions = {
              nodes = { {
                  range = {
                    end = {
                      character = 16,
                      line = 48
                    },
                    start = {
                      character = 5,
                      line = 48
                    }
                  },
                  resource = {
                    path = "lib/output/progress.go"
                  },
                  url = "..."
                } }
            }
          },
          name = "output.go",
          path = "lib/output/output.go"
        }
      }
    }
  }
  --]]
  local lsif_keypath = { "data", "repository", "commit", "blob", "lsif", "definitions", "nodes" }
  local lsif_results = output
  for _, key in ipairs(lsif_keypath) do
    if not lsif_results or (type(lsif_results) ~= "table") then
      lsif_results = nil
      break
    end

    lsif_results = lsif_results[key]
  end

  if type(lsif_results) == "table" and #lsif_results >= 1 then
    local node = lsif_results[1]
    return rpc.respond(id, nil, transform.node_to_location(node))
  end

  if true then
    return
  end

  --[[
    {
      data = {
        repository = {
          commit = {
            blob = {
              lsif = vim.NIL,
              name = "examiner.h",
              path = "src/examiner.h"
            }
          }
        },
        search = {
          results = {
            results = { {
                __typename = "FileMatch",
                symbols = { {
                    canonicalURL = "...",
                    location = {
                      range = {
                        end = {
                          character = 19,
                          line = 28
                        },
                        start = {
                          character = 2,
                          line = 28
                        }
                      }
                    },
                    name = "exam_test_table_t"
                  } }
              } }
          }
        }
      }
    }
  --]]
  local search_keypath = { "data", "search", "results", "results" }
  local search_results = output
  for _, key in ipairs(search_keypath) do
    if not search_results or not type(search_results) == "table" then
      search_results = nil
      break
    end

    search_results = search_results[key]
  end

  if type(search_results) == "table" and #search_results > 0 then
    local symbols = search_results[1].symbols
    if not symbols or #symbols == 0 then
      log.info "NO FIRST RESULT SYMBOLS OR 0"
      return nil
    end

    local node = symbols[1]

    return rpc.respond(id, nil, transform.node_to_location(node))
  end

  log.info "No results found: search or lsif"
  return nil
end

local ReferencesGraphQL = [[
query ($repository: String!, $revision: String!, $path: String!, $line: Int!, $character: Int!) {
  repository(name: $repository) {
    commit(rev: $revision) {
      blob(path: $path) {
        name
        path
        lsif {
          references(line: $line, character: $character) {
            nodes {
              url
              resource {
                path
              }
              range {
                start {
                  line
                  character
                }
                end {
                  line
                  character
                }
              }
            }
          }
        }
      }
    }
  }
}
]]

-- query:  "repo:^github.com/neovim/neovim$@HEAD type:symbol patternType:regexp ^nlua_traverse_table$"

-- interface TextDocumentPositionParams {
--   textDocument: TextDocumentIdentifier
--   position: Position
-- }
--
-- interface ReferenceParams {
--   TextDocumentPositionParams
--   context: ReferencesContext {
--      includeDeclaration: bool
--   }
-- }
methods["textDocument/references"] = function(params, id)
  local uri = URI:new(params.textDocument.uri)

  local repository = uri.remote
  local rev = uri.commit
  local path = uri.filepath
  local line = params.position.line
  local character = params.position.character

  -- local state = file_states[params.textDocument.uri]
  -- local symbol = utils.get_word_around_character(state[line + 1], character)

  log.info("references request...", "commit=", rev)
  local output = cli.api(ReferencesGraphQL, {
    -- $repository: String!
    repository = repository,
    -- $revision: String!
    revision = rev,
    -- $path: String!
    path = path,
    -- $line: Int!
    line = line,
    -- $character: Int!
    character = character,
    -- $query: String!
    -- query = string.format("repo:^%s$@%s type:symbol patternType:regexp ^%s$", repository, rev, symbol),
  })

  log.info("references: output", output)

  --[[
  "data": {
    "repository": {
      "commit": {
        "blob": {
          "name": "contains.go",
          "path": "lib/codeintel/lsif/protocol/contains.go",
          "lsif": {
            "references": {
              "nodes": [
                {
                  "url": "/github.com/sourcegraph/sourcegraph@61148f/-/tree/lib/codeintel/lsif/protocol/contains.go?L3:6-3:14",
                  "resource": {
                    "path": "lib/codeintel/lsif/protocol/contains.go"
                  },
                  "range": {
                    "start": {
                      "line": 2,
                      "character": 5
                    },
                    "end": {
                      "line": 2,
                      "character": 13
                    }
                  }
                },
                ...
              ]
  --]]
  local lsif_keypath = { "data", "repository", "commit", "blob", "lsif", "references", "nodes" }
  local lsif_results = output
  for _, key in ipairs(lsif_keypath) do
    if not lsif_results or (type(lsif_results) ~= "table") then
      lsif_results = nil
      break
    end

    lsif_results = lsif_results[key]
  end

  if type(lsif_results) == "table" and #lsif_results >= 1 then
    return rpc.respond(
      id,
      nil,
      vim.tbl_map(function(node)
        return transform.node_to_location(node)
      end, lsif_results)
    )
  end

  -- TODO: Handle search based references as well
  if true then
    return
  end

  --[[
    {
      data = {
        repository = {
          commit = {
            blob = {
              lsif = vim.NIL,
              name = "examiner.h",
              path = "src/examiner.h"
            }
          }
        },
        search = {
          results = {
            results = { {
                __typename = "FileMatch",
                symbols = { {
                    canonicalURL = "...",
                    location = {
                      range = {
                        end = {
                          character = 19,
                          line = 28
                        },
                        start = {
                          character = 2,
                          line = 28
                        }
                      }
                    },
                    name = "exam_test_table_t"
                  } }
              } }
          }
        }
      }
    }
  --]]
  local search_keypath = { "data", "search", "results", "results" }
  local search_results = output
  for _, key in ipairs(search_keypath) do
    if not search_results or not type(search_results) == "table" then
      search_results = nil
      break
    end

    search_results = search_results[key]
  end

  if type(search_results) == "table" and #search_results > 0 then
    local symbols = search_results[1].symbols
    if not symbols or #symbols == 0 then
      log.info "NO FIRST RESULT SYMBOLS OR 0"
      return nil
    end

    local node = symbols[1]
    return rpc.respond(id, nil, transform.node_to_location(node))
  end

  log.info "No results found: search or lsif"
  return nil
end

methods["shutdown"] = function()
  vim.schedule(function()
    vim.cmd [[qa!]]
  end)
end

methods["initizlied"] = function() end

return methods
