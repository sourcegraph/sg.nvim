(loadfile "./scripts/init.lua")()

require("plenary.test_harness").test_directory("lua/e2e_tests/", { minimal = "./scripts/init.lua" })
