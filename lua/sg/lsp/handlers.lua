local cli = require "sg.cli"
local log = require "sg.log"
local rpc = require "sg.lsp.rpc"
local bufread = require "sg.bufread"
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
      --referencesProvider = false,
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

methods["textDocument/didChange"] = function(params)
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
methods["textDocument/didSave"] = function(params)
  return
end

methods["textDocument/didClose"] = function(params)
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
  local parts = bufread._deconstruct_path(params.textDocument.uri)

  local repository = parts.url
  local rev = parts.commit
  local path = parts.filepath
  local line = params.position.line
  local character = params.position.character

  local state = file_states[params.textDocument.uri]
  local symbol = utils.get_word_around_character(state[line + 1], character)

  log.info "definition request..."
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

    local scrubbed_url = string.gsub(node.url, "/tree/", "/blob/")
    local uri = "sg:/" .. scrubbed_url

    return rpc.respond(id, nil, {
      uri = uri,
      range = node.range,
    })
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

    local scrubbed_url = string.gsub(node.canonicalURL, "/tree/", "/blob/")
    local uri = "sg:/" .. scrubbed_url

    return rpc.respond(id, nil, {
      uri = uri,
      range = node.location.range,
    })
  end

  log.info "No results found: search or lsif"
  return nil
end

methods["shutdown"] = function()
end

return methods
