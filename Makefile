
test:
	nvim --headless --noplugin -u scripts/init.lua -c "PlenaryBustedDirectory lua/tests/ { minimal = './scripts/init.lua' }"

docgen:
	nvim --headless --noplugin -u scripts/init.lua -c "luafile ./scripts/gendocs.lua" -c 'qa'
