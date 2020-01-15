--[[
   * Author: BirdBird
   * Licence: GPL v3
   * Version: 1.0
	 * NoIndex: true
--]]
local maths = require('MathHelper')

local utility = require('Utility')

local w = {}
function p(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end

local mainWindow
local arrangeWindow
local arrange_DC

function w.init()
    mainWindow = reaper.GetMainHwnd() -- GET MAIN WINDOW
    arrangeWindow = reaper.JS_Window_FindChildByID(mainWindow, 0x3E8)
    arrange_DC = reaper.JS_GDI_GetWindowDC(arrangeWindow)
end

function w.intercept(message)
    local intercept = reaper.JS_WindowMessage_Intercept(arrangeWindow, message, false)
end

function w.release(message)
    reaper.JS_WindowMessage_Release(arrangeWindow, message)
end

--ALWAYS PASS SCREEN COORDINATES TO WINDOW FUNCTIONS
function w.arrangePositionFromMouse(mx, my)
    local ret, left, top, right, bottom = reaper.JS_Window_GetClientRect( arrangeWindow )
    local x, y = reaper.JS_Window_ScreenToClient( arrangeWindow, mx, my )
    x = x + left --Offset since client coordinates are offset

    local a_start, a_end = reaper.GetSet_ArrangeView2(0, false, 0, 0)
    local a_length = a_end - a_start
    
    local xo = (x - left)/(right - left)
    local timePos = maths.lerp(a_start, a_end, xo)

    return timePos, utility.getTrackUnderMouse(mx, my)
end

function w.mouseInArrange(mx , my)
    --[[
    local ret, left, top, right, bottom = reaper.JS_Window_GetClientRect( arrangeWindow )
    local x, y = reaper.JS_Window_ScreenToClient( arrangeWindow, mx, my )
    x,y = x + left, y + top

    return maths.isBetween(x, left, right) and maths.isBetween(y, top, bottom)
    --]]

    local focus = reaper.JS_Window_FromPoint( mx, my )
    return focus == arrangeWindow
end

function w.arrangePosToScreen(time, track)
    local ret, left, top, right, bottom = reaper.JS_Window_GetClientRect( arrangeWindow )
    local a_start, a_end = reaper.GetSet_ArrangeView2(0, false, 0, 0)
    
    local to = (time - a_start)/(a_end - a_start)
    local x = maths.lerp(left, right, to)
    local y = 0
    
    if reaper.ValidatePtr(track, 'MediaTrack*') then --return top for master track
        local trackHeight = reaper.GetMediaTrackInfo_Value( track, 'I_TCPH' )
        local trackVertical = reaper.GetMediaTrackInfo_Value(track, 'I_TCPY')
        y = top + trackVertical
    else
        y = top
    end

    return x,y
end

function w.focusedWindowIsArrange()
    local focusedWindow =  reaper.JS_Window_GetFocus() 
    --local focusedWindow = reaper.JS_Window_GetForeground()
    local windowClass = reaper.JS_Window_GetClassName( focusedWindow )
    return focusedWindow == arrangeWindow
end

function w.timePositionToScreen(time)
    local ret, left, top, right, bottom = reaper.JS_Window_GetRect( arrangeWindow )
    local a_start, a_end = reaper.GetSet_ArrangeView2(0, false, 0, 0)

    local to = (time - a_start)/(a_end - a_start)
    local x = maths.lerp(left, right, to)
    return x    
end

function w.getGridCoordinates(time, track)
    local x1 = reaper.BR_GetPrevGridDivision(time)
    local x2 = reaper.BR_GetNextGridDivision(x1)
    
    x1 = w.timePositionToScreen(x1)
    x2 = w.timePositionToScreen(x2)

    local width = x2 - x1
    
    local F, ty = w.arrangePosToScreen(time, track)
    local trackHeight = reaper.GetMediaTrackInfo_Value( track, 'I_TCPH' )

    local y1 = ty
    local y2 = ty + trackHeight

    x1,y1,x2,y2 = maths.round(x1), maths.round(y1), maths.round(x2), maths.round(y2)
    
    x1,y1 = reaper.JS_Window_ScreenToClient(arrangeWindow, x1, y1)
    x2,y2 = reaper.JS_Window_ScreenToClient(arrangeWindow, x2, y2)

    return x1, y1, x2-x1, y2-y1
end

function w.screenToClient(x1, y1)
    local a,b = reaper.JS_Window_ScreenToClient(arrangeWindow, x1, y1)
    return a,b
end

function w.getScreenFromTimeTrack(track, x1, x2)
    local x1 = w.timePositionToScreen(x1)
    local x2 = w.timePositionToScreen(x2)

    local width = x2 - x1
    
    local F, ty = w.arrangePosToScreen(x1, track)
    local trackHeight = reaper.GetMediaTrackInfo_Value( track, 'I_TCPH' )
    
    local y1 = ty
    local y2 = ty + trackHeight

    x1,y1,x2,y2 = maths.round(x1), maths.round(y1), maths.round(x2), maths.round(y2)
    
    x1,y1 = reaper.JS_Window_ScreenToClient(arrangeWindow, x1, y1)
    x2,y2 = reaper.JS_Window_ScreenToClient(arrangeWindow, x2, y2)

    return x1, y1, x2-x1, y2-y1
end

function w.getGridCoordinatesInArrange(time)
    local x1 = reaper.BR_GetPrevGridDivision(time)
    local x2 = reaper.BR_GetNextGridDivision(x1)
    
    return x1 , x2
end

function w.drawRect(bm, x,y,w,h, color)
    reaper.JS_LICE_Clear(bm, color)
    reaper.JS_LICE_FillRect(bm, x, y, w, h, color, 0.1, "ALPHA")

    local composite = reaper.JS_Composite(arrangeWindow, x, y, w, h, bm, 0, 0, 1, 1)
    reaper.JS_Window_InvalidateRect(arrangeWindow, x, y, w, h, false) -- EVEN IF THIS IS COMMENTED OUT
end

function w.cleanup()
    reaper.JS_Window_InvalidateRect(arrangeWindow, 0, 0, 6000, 6000, false)
end

return w