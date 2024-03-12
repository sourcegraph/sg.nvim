(loadfile "./scripts/init.lua")()

require("plenary.test_harness").test_directory("lua/tests/e2e/", { minimal = "./scripts/init.lua" })
