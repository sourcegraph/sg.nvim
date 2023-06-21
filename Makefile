
test:
	nvim --headless --noplugin -u scripts/init.lua -c "PlenaryBustedDirectory lua/tests/ { minimal = './scripts/init.lua' }"
