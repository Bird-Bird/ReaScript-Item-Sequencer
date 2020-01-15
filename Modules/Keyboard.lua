function p(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end
local K = {} --module

local allKeys = {
    {"a" , 65},
    {"b" , 66},
    {"c" , 67},
    {"d" , 68},
    {"e" , 69},
    {"f" , 70},
    {"g" , 71},
    {"h" , 72},
    {"i" , 73},
    {"j" , 74},
    {"k" , 75},
    {"l" , 76},
    {"m" , 77},
    {"n" , 78},
    {"o" , 79},
    {"p" , 80},
    {"q" , 81},
    {"r" , 82},
    {"s" , 83},
    {"t" , 84},
    {"u" , 85},
    {"v" , 86},
    {"w" , 87},
    {"x" , 88},
    {"y" , 89},
    {"z" , 90},
    {"backspace", 8}
}

local keys = {}
local previousBuffer = {}
local startTime = 0
function K.init()
    --reaper.JS_VKeys_Intercept(-1, 1)
    startTime = reaper.time_precise()
end

function K.subscribeAllKeys()
    for i = 1, #allKeys do
        local key = allKeys[i]
        local keyName = key[1]
        local keyID = key[2]

        K.subscribeKey(keyName, keyID)
    end
end

function K.subscribeKey(name, id)
    local obj = {}
    obj.name = name
    obj.id = id
    obj.isDown = false
    obj.isHeld = false
    obj.isUp = false

    previousBuffer[name] = {isHeld = false, isDown = false}
    table.insert(keys, obj)
end

function K.updateKeys()
    local tempBuffer = {}
    
    --fill the buffer here
    local keyStates = reaper.JS_VKeys_GetState(startTime)
    
    for i = 1, #keys do
        local key = keys[i]
        local keyState = keyStates:byte(key.id)
        
        local isDown = false
        local isHeld = false
        local isUp = false

        if keyState ~= 0 then --if the key has been pressed
            isHeld = true
            if previousBuffer[key.name].isHeld == false then
                isDown = true
            elseif previousBuffer[key.name].isHeld == true then
                isDown = false
            end 
        else
            if previousBuffer[key.name].isHeld then
                isUp = true    
            end
            
            isHeld = false
            isDown = false
        end

        local obj = {isHeld = isHeld, isDown = isDown, isUp = isUp}
        tempBuffer[key.name] = obj
    end

    previousBuffer = tempBuffer
    return tempBuffer
end

function K.interceptKeys()
    for i = 1, #keys do
        local key = keys[i]
        reaper.JS_VKeys_Intercept( key.id, 1 )
    end
end

function K.releaseKeys()
    for i = 1, #keys do
        local key = keys[i]
        reaper.JS_VKeys_Intercept( key.id, -1 )
    end
end

return K