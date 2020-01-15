--[[
 * ReaScript Name: BirdBird_Item Sequencer
 * Author: BirdBird
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
 * Provides: Modules/*.lua
--]]
 
--[[
 * Changelog:
 * v1.0 (2020-12-15)
 	+ Initial Release
--]]

function p(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end

--==========MODULES===========--
local info = debug.getinfo(1,'S');
local full_script_path = info.source
local script_path = full_script_path:sub(2,-5) -- remove "@" and "file extension" from file name
if reaper.GetOS() == "Win64" or reaper.GetOS() == "Win32" then
	package.path = package.path .. ";" .. script_path:match("(.*".."\\"..")") .. "\\Modules\\?.lua"
else
	package.path = package.path .. ";" .. script_path:match("(.*".."/"..")") .. "/Modules/?.lua"
end

local keyboardHandler = require('Keyboard')
local mouseHandler = require('Mouse')
local program = require('Program')
local windowHandler = require('Window')

--=====MAIN LOOP OF THE PROGRAM=====--
function main()
    local keys = keyboardHandler.updateKeys()
    local mouse = mouseHandler.updateMouse()
    program.update(keys, mouse)
    reaper.defer(main)
end

function exit()
    program.exit()
end
reaper.atexit(exit)

--=====INITIALIZE MODULES=====--
keyboardHandler.init()
mouseHandler.init()
windowHandler.init()
program.init(keyboardHandler, mouseHandler, terminate)
--============================--

main()