
test:
	nvim --headless --noplugin -u scripts/init.lua -c "PlenaryBustedDirectory lua/tests/ { minimal = './scripts/init.lua' }"

docgen:
	nvim --noplugin -u scripts/init.lua -l scripts/gendocs.lua
