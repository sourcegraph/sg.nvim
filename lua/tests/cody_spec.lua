require("plenary.async").tests.add_to_env()

local rpc = assert(require "sg.cody.rpc", "able to load cody rpc")

local find_initialized = function()
  return vim.tbl_filter(function(msg)
    return msg.type == "notify" and msg.method == "initialized"
  end, rpc.messages)[1]
end

local eq = assert.are.same
describe("cody", function()
  a.it("should have initialized", function()
    vim.wait(1000, function()
      return find_initialized()
    end)

    local initialized = find_initialized()
    eq(initialized, { type = "notify", method = "initialized" })
  end)

  a.it("should be able to list recipes", function()
    vim.wait(1000, function()
      return find_initialized()
    end)

    local err, data = rpc.execute.list_recipes()
    eq(err, nil)

    local chat_question = vim.tbl_filter(function(recipe)
      return recipe.id == "chat-question"
    end, data)[1]

    eq(chat_question, { id = "chat-question", title = "chat-question" })
  end)
end)
