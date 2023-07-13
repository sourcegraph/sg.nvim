(loadfile "./scripts/init.lua")()

require("plenary.test_harness").test_directory("lua/tests/", { minimal = "./scripts/init.lua" })
