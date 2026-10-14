fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pvp_hud'
description 'HUD PvP: vida, colete, armas, kills, headshot e velocimetro'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/icons.js',
    'html/img/*',
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
