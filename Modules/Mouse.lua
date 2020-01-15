local windowHandler = require('Window')
local keyboard = require('Keyboard')

local mx = {}
function p(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end

local m = {
    timePosition = 0,
    last_timePosition = 0,
    
    track = nil,
    last_track = nil,
    
    LMB = false,
    last_LMB = false,
    
    x = 0,
    y = 0,
    
    lx = 0,
    ly = 0,

    dx = 0,
    dy = 0,
    
    leftButtonDown = false,
    leftButtonUp = false,
    leftDragStart = false,
    leftDrag = false,
    leftDragEnd = false,
    
    RMB = false,
    last_RMB = false,

    rightButtonDown = false,
    rightButtonUp = false,
    rightDragStart = false,
    rightDrag = false,
    rightDragEnd = false,
}

local mainWindow
local arrangeWindow

function mx.init()
    mainWindow = reaper.GetMainHwnd() -- GET MAIN WINDOW
    arrangeWindow = reaper.JS_Window_FindChildByID(mainWindow, 0x3E8)
end

--=====HOOKS=====--
mx.leftDragStart = nil
mx.leftDrag = nil
mx.leftDragEnd = nil
mx.rightDragStart = nil
mx.rightDrag = nil
mx.rightDragEnd = nil
mx.idle = nil
--===============--

function mx.updateMouse()
    local x, y = reaper.GetMousePosition()
    m.timePosition, m.track = windowHandler.arrangePositionFromMouse(x,y)
    
    --Lock updates when dragging
    m.LMB = not m.rightDrag and reaper.JS_Mouse_GetState(95)&1 == 1 or false 
    m.RMB = not m.leftDrag and reaper.JS_Mouse_GetState(95)&2 == 2 or false
    
    m.x = x
    m.y = y

    m.dx = x - m.lx
    m.dy = y - m.ly
    
    m.focusedWindowIsArrange = windowHandler.focusedWindowIsArrange()
    m.inArrange = windowHandler.mouseInArrange(x,y)

    if not m.last_focusedWindowIsArrange and m.focusedWindowIsArrange then
        keyboard.interceptKeys()
    elseif m.last_focusedWindowIsArrange and not m.focusedWindowIsArrange then
        keyboard.releaseKeys()
    elseif not m.last_focusedWindowIsArrange and not m.focusedWindowIsArrange then
        keyboard.releaseKeys()
    end
    
    if m.inArrange or (m.leftDrag or m.rightDrag) then
        --LEFT DRAG
        if not m.rightDrag then
            if not m.last_LMB and m.LMB then
                m.leftDrag = true
                m.leftDragStart = true
                if mx.leftDragStart ~= nil then mx.leftDragStart(m) end
            elseif m.last_LMB and m.LMB then
                if mx.leftDrag ~= nil then mx.leftDrag(m) end
                m.leftDragStart = false
            elseif m.last_LMB and not m.LMB then
                m.leftDrag = false
                m.leftDragEnd = true
                if mx.leftDragEnd ~= nil then mx.leftDragEnd(m) end
            elseif not m.last_LMB and not m.LMB then
                m.leftDragEnd = false
            end
        end

        --RIGHT DRAG
        if not m.leftDrag then
            if not m.last_RMB and m.RMB then
                m.rightDrag = true
                m.rightDragStart = true
                if mx.rightDragStart ~= nil then mx.rightDragStart(m) end
            elseif m.last_RMB and m.RMB then
                if mx.rightDrag ~= nil then mx.rightDrag(m) end
                m.rightDragStart = false
            elseif m.last_RMB and not m.RMB then
                m.rightDrag = false
                m.rightDragEnd = true
                if mx.rightDragEnd ~= nil then mx.rightDragEnd(m) end
            elseif not m.last_RMB and not m.RMB then
                m.rightDragEnd = false
            end
        end

        if not m.leftDrag and not m.rightDrag then
            if mx.idle ~= nil then mx.idle(m) end
        end
    end
    
    m.last_LMB = m.LMB
    m.last_RMB = m.RMB
    m.lx = m.x
    m.ly = m.y
    m.last_timePosition, m.last_track = m.timePosition, m.track
    m.last_focusedWindowIsArrange = m.focusedWindowIsArrange
    m.last_inArrange = m.inArrange
    return m
end

return mx