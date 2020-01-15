--[[
   * Author: BirdBird
   * Licence: GPL v3
   * Version: 1.1
	 * NoIndex: true
--]]

local windowHandler = require('Window')
local maths = require('MathHelper')
local utility = require('Utility')
local pr = {} --begin module

function p(msg) reaper.ShowConsoleMsg(tostring(msg)..'\n')end

--=====SETTINGS=====--

--=====MAIN=====--
local objects = {}
local windowParameters
local terminateProgram = nil
local mouse = nil
local keyboard = nil

local red = 0x1Aff0066
local blue = 0x1A006666
local dark = 0x1A000066
local purple = 0x1A51142b
local yellow = 0x1Aa37800

m = nil
k = nil
function pr.init(keyboardHandler, mouseHandler, terminate) --SUBSCRIBE KEYS HERE
    terminateProgram = terminate
    keyboard = keyboardHandler
    mouse = mouseHandler

    initializeState()
end

local bm = reaper.JS_LICE_CreateBitmap(true, 1, 1)
function pr.onCancel()
    
end

--====MAIN PROGRAM=====--
local drawOverlay = true
local programState = nil

function initializeState()
    --Keyboard stuff
    keyboard.subscribeKey('a', 65)
    keyboard.subscribeKey('q', 81)
    keyboard.subscribeKey('s', 83)
    
    programState = newIdleState()
end

function pr.update(keys, mouse)
    m = mouse
    k = keys

    programState:update()
end

function pr.draw()

end

function pr.exit()
    keyboard.releaseKeys()
    mouse.release()
    reaper.JS_LICE_DestroyBitmap(bm)
    windowHandler.cleanup()
end

--=====STATES=====--
function newPaintState(paintInfo) 
    local s = {
        paintInfo = paintInfo,
        enter = function(self)
            reaper.Undo_BeginBlock()
        end,
        update = function(self)
            if m.leftDrag == false then --exit if mouse has been released
                switchState(newIdleState())
            else
                --place item
                local x1, x2 = windowHandler.getGridCoordinatesInArrange(m.timePosition)
                utility.tryPlaceItem(paintInfo.track, paintInfo.item, x1,x2)
            
                --draw overlay
                if not reaper.ValidatePtr(self.paintInfo.track, 'MediaTrack*') then return end
                local x, y, w, h = windowHandler.getGridCoordinates(m.timePosition, self.paintInfo.track)
                windowHandler.drawRect(bm,x,y,w,h, blue)
            end
        end,
        exit = function(self)
            reaper.Undo_EndBlock('Item Sequencer - Paint', 4)
        end,
    }

    return s
end
--======IDLE STATE======--
function newIdleState()
    local s = {
        enter = function(self)

        end,
        update = function(self)
            if m.inArrange and m.track ~= nil then --idle state only runs when mouse is in arrange
                if m.leftDragStart then --paint action
                    if reaper.ValidatePtr(m.track, 'MediaTrack*') then --Only start painting when hovering over a track
                        local item = reaper.GetTrackMediaItem(m.track, 0)
                        if item == nil then --only start paint state if there is an item on the track
                            return
                        end
                        
                        local drawInfo = {}
                        
                        local startPos, x2 = windowHandler.getGridCoordinatesInArrange(m.timePosition)
                
                        drawInfo.start = startPos
                        drawInfo.item = item
                        drawInfo.track = m.track
                
                        local paintState = newPaintState(drawInfo)
                        switchState(paintState)
                    end 
                elseif m.rightDragStart then --erase action
                    if reaper.ValidatePtr(m.track, 'MediaTrack*') then --Only start painting when hovering over a track
                        local item = reaper.GetTrackMediaItem(m.track, 0)
                        if item == nil then --only start paint state if there is an item on the track
                            return
                        end
                        
                        local drawInfo = {}
                        
                        local startPos, x2 = windowHandler.getGridCoordinatesInArrange(m.timePosition)
                
                        drawInfo.start = startPos
                        drawInfo.item = item
                        drawInfo.track = m.track
                
                        local paintState = newEraseState(drawInfo)
                        switchState(paintState)
                    end  
                end
                
                local x1, x2 = windowHandler.getGridCoordinatesInArrange(m.timePosition)
                local color = reaper.CountTrackMediaItems(m.track) > 0 and blue or dark
                
                if k['q'].isHeld then
                    color = red
                    utility.delete_items_in_range_on_track(m.track, x1, x2)
                end
                if k['a'].isDown then
                    local velState = newVelocityState()
                    switchState(velState)
                elseif k['s'].isDown then
                    local velState = newOffsetState()
                    switchState(velState)
                end
                --draw overlay
                if not reaper.ValidatePtr(m.track, 'MediaTrack*') then return end
                local x, y, w, h = windowHandler.getGridCoordinates(m.timePosition, m.track)
                windowHandler.drawRect(bm,x,y,w,h, color) 
            end
        end,
        exit = function(self)

        end,
    }

    return s
end
--=====VELOCITY STATES=====--
function newVelocityState(paintInfo)
    local s = {
        paintInfo = paintInfo,
        enter = function(self)

        end,
        update = function(self)
            if k['a'].isUp then --return to idle on key release
                returnToIdle()
            end
            
            local item = utility.getItemUnderMouse(m.x, m.y)
            if item ~= nil then
                local x1, x2 = utility.getItemCoords(item)
                local x,y,w,h = windowHandler.getScreenFromTimeTrack(m.track, x1, x2)
                
                windowHandler.drawRect(bm,x,y,w,h, purple) 

                if m.leftDragStart then --switch to velocity tweaking state
                    local info = {item = item, track = reaper.GetMediaItem_Track(item)}
                    local state = newVelocityTweakingState(info)
                    switchState(state)
                end
            else
                local sx, sy = windowHandler.screenToClient(m.x, m.y)
                local rectSize = 10
                local x = sx - rectSize
                local y = sy - rectSize
                local w,h = 2*rectSize, 2*rectSize
                windowHandler.drawRect(bm,x,y,w,h, purple) 
            end
        end,
        exit = function(self)

        end,
    }

    return s
end

function newVelocityTweakingState(paintInfo)
    local s = {
        paintInfo = paintInfo,
        previewTime = 0.375,
        enter = function(self)
            --edit cursor
            self.startCursorPosition =  reaper.GetCursorPosition()
            local itemPosition = reaper.GetMediaItemInfo_Value(paintInfo.item, 'D_POSITION') 
            reaper.SetEditCurPos2(0, itemPosition, false, true)
            reaper.SetMediaTrackInfo_Value(paintInfo.track, 'I_SOLO', 1)
            reaper.Main_OnCommand(1007, -1) -- start playback

            self.lastPreviewTime = reaper.time_precise()
        end,
        update = function(self)
            if m.leftDrag == false and k['a'].isHeld == false then --go back to idle if both keys released
                returnToIdle()
            elseif m.leftDrag == false and k['a'].isHeld == true then --return to velocity tweaking state
                local velState = newVelocityState()
                switchState(velState)
            end
            if m.dy ~= 0 then --nudge item volume here
                local nudgeStep = 0.03
                local itemVol = reaper.GetMediaItemInfo_Value(paintInfo.item, 'D_VOL')
                local itemVol_DB = utility.WDL_VAL2DB(itemVol)
                itemVol_DB = itemVol_DB + (m.dy * nudgeStep * -1)
                local finalVol = utility.WDL_DB2VAL(itemVol_DB)
                reaper.SetMediaItemInfo_Value(paintInfo.item, 'D_VOL', finalVol)
            end
            local time = reaper.time_precise()
            if time - self.lastPreviewTime > self.previewTime then
                local itemPosition = reaper.GetMediaItemInfo_Value(paintInfo.item, 'D_POSITION') 
                reaper.SetEditCurPos2(0, itemPosition, false, true)
                self.lastPreviewTime = time
            end
            --draw overlay
            local x1, x2 = utility.getItemCoords(paintInfo.item)
            local x,y,w,h = windowHandler.getScreenFromTimeTrack(paintInfo.track, x1, x2)
            windowHandler.drawRect(bm,x,y,w,h, purple) 
        end,
        exit = function(self)
            reaper.Main_OnCommand(1016, -1) -- stop playback
            reaper.SetEditCurPos2(0, self.startCursorPosition, false, false)
            reaper.SetMediaTrackInfo_Value(paintInfo.track, 'I_SOLO', 0)
        end,
    }

    return s
end
--=========================--
function newOffsetState(paintInfo)
    local s = {
        paintInfo = paintInfo,
        enter = function(self)

        end,
        update = function(self)
            if k['s'].isUp then --return the idle on key release
                returnToIdle()
            end
            
            local item = utility.getItemUnderMouse(m.x, m.y)
            if item ~= nil then
                --draw overlay
                local x1, x2 = utility.getItemCoords(item)
                local x,y,w,h = windowHandler.getScreenFromTimeTrack(m.track, x1, x2)
                windowHandler.drawRect(bm,x,y,w,h, dark) 

                if m.leftDragStart then --switch to velocity tweaking state
                    local info = {item = item, track = reaper.GetMediaItem_Track(item)}
                    local state = newOffsetTweakingState(info)
                    switchState(state)
                end
            else
                local sx, sy = windowHandler.screenToClient(m.x, m.y)
                local rectSize = 10
                local x = sx - rectSize
                local y = sy - rectSize
                local w,h = 2*rectSize, 2*rectSize
                windowHandler.drawRect(bm,x,y,w,h, dark) 
            end
        end,
        exit = function(self)

        end,
    }

    return s
end

function newOffsetTweakingState(paintInfo)
    local s = {
        paintInfo = paintInfo,
        enter = function(self)

        end,
        update = function(self)
            if m.leftDrag == false and k['s'].isHeld == false then --go back to idle if both keys released
                returnToIdle()
            elseif m.leftDrag == false and k['s'].isHeld == true then --return to velocity tweaking state
                local offsetState = newOffsetState()
                switchState(offsetState)
            end
            if m.dx ~= 0 then --nudge item volume here
                local sensitivity = 0.0003 * m.dx
                utility.offsetItemInPlace(paintInfo.track, paintInfo.item, sensitivity)
            end

            --draw overlay
            local x1, x2 = utility.getItemCoords(paintInfo.item)
            local x,y,w,h = windowHandler.getScreenFromTimeTrack(paintInfo.track, x1, x2)
            windowHandler.drawRect(bm,x,y,w,h, dark) 
        end,
        exit = function(self)

        end,
    }

    return s
end

function newEraseState(paintInfo)
    local s = {
        paintInfo = paintInfo,
        enter = function(self)
            reaper.Undo_BeginBlock()
        end,
        update = function(self)
            if m.rightDrag == false then --exit if mouse has been released
                switchState(newIdleState())
            else
                --remove item
                local x1, x2 = windowHandler.getGridCoordinatesInArrange(m.timePosition)
                utility.tryDeleteItem(paintInfo.track, paintInfo.item, x1,x2)
            
                --draw overlay
                if not reaper.ValidatePtr(self.paintInfo.track, 'MediaTrack*') then return end
                local x, y, w, h = windowHandler.getGridCoordinates(m.timePosition, self.paintInfo.track)
                windowHandler.drawRect(bm,x,y,w,h, red)
            end
        end,
        exit = function(self)
            reaper.Undo_EndBlock('Item Sequencer - Erase', -1)
        end,
    }

    return s
end

function switchState(state)
    programState:exit()
    state:enter()
    programState = state
end

function returnToIdle()
    local idle = newIdleState()
    switchState(idle)
end

return pr