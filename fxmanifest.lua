game 'gta5'
fx_version 'cerulean'
lua54 'yes'
author 'ahezu'
description 'HUD created for WestSide, now its public.'

shared_scripts {	
	'@es_extended/imports.lua',
	'@ox_lib/init.lua',
	'config.lua'
}

ui_page 'html/hud.html'
client_scripts {
	'client.lua',
	'compoments/*.lua'
}

files {
	'html/img/*.png',
    'html/hud.html',
    'html/hud.css',
    'html/hud.js',
	'stream/int3232302352.gfx'	
}
server_script 'server.lua'

data_file "SCALEFORM_DLC_FILE" "stream/int3232302352.gfx"

--[[
escrow_ignore {
	'config.lua',
	'server.lua',
	'compoments/*.lua'
}
]]