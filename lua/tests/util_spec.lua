local utils = require "sg.utils"
local get_word_around_character = utils.get_word_around_character

local eq = assert.are.same

describe("sg.utils", function()
  describe("get_word_around_character", function()
    it("should return only one word when there is only one word", function()
      eq("hello", get_word_around_character("hello", 2))
    end)

    it("should return only the word when there are two words", function()
      eq("hello", get_word_around_character("hello world", 2))
    end)

    it("should return only the word when there are commas", function()
      eq("hello", get_word_around_character("hello, world", 2))
    end)

    it("should return only the word when there are commas and spaces in front", function()
      eq("hello", get_word_around_character("  hello, world", 4))
    end)

    it("with starter should return only one word when there is only one word", function()
      eq("chat", get_word_around_character("asdf chat", 7))
    end)

    it("with starter should return only the word when there are two words", function()
      eq("bar", get_word_around_character("asdf bar world", 7))
    end)

    it("with starter should return only the word when there are commas", function()
      eq("foo", get_word_around_character("asdf foo, world", 7))
    end)
    it("with starter should return only the word when there are commas", function()
      eq("foo_is_cool", get_word_around_character("asdf foo_is_cool, world", 7))
    end)
  end)
end)
