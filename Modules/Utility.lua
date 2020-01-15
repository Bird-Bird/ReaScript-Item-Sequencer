local u = {}
function p(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end

function u.getTrackUnderMouse(x, y)
    local track, info = reaper.GetTrackFromPoint(x, y)
    if reaper.ValidatePtr(track, 'MediaTrack*') then
        return track
    else
        return nil
    end
end

function u.getItemUnderMouse(x, y)
    local item, take = reaper.GetItemFromPoint( x, y, false )
    return item
end

function u.offsetItemInPlace(track, item, dx)
    local nextItem = u.getNextItem(track, item)
    local prevItem = u.getPreviousItem(track, item)
    
    local start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local snapOffset = reaper.GetMediaItemInfo_Value(item, 'D_SNAPOFFSET')
    local targetPos = start + dx
    reaper.SetMediaItemInfo_Value(item, 'D_POSITION', targetPos)
    reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', snapOffset - dx)

    --trim items as necessary
    local source = reaper.GetTrackMediaItem(track, 0)
    local sourceLength = reaper.GetMediaItemInfo_Value(source, 'D_LENGTH')
    if prevItem ~= nil then --trim previous item if necessary
        local s,e,l = u.getItemCoords(prevItem)
        if e > targetPos then
            u.setItemRightEdge(prevItem, targetPos)
        elseif l < sourceLength  then --item fits the gap
            u.setItemRightEdge(prevItem, math.min(targetPos, s + sourceLength))
        end
    end
    if nextItem ~= nil then
        local s,e,l = u.getItemCoords(nextItem)
        local is, ie, il = u.getItemCoords(item)
        if targetPos + length > s then
            u.setItemRightEdge(item, s)
        elseif length < sourceLength then
            u.setItemRightEdge(item, math.min(s, is + sourceLength))
        end
    end
end

function u.getItemCoords(item)
    local start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local endPos = start + length

    return start, endPos, length
end

function u.getParsedItemChunk(item)
    local take = reaper.GetMediaItemTake(item, 0)
    local source = reaper.GetMediaItemTake_Source(take)

    local m_type = reaper.GetMediaSourceType(source, "")

    local chunk = ({reaper.GetItemStateChunk( item, '', false )})[2]

    local item_is_MIDI = m_type:find('MIDI')

    local chunk_lines = {}
    for line in chunk:gmatch('[^\r\n]+') do
      chunk_lines[#chunk_lines + 1] = line
    end

    for j = 1, #chunk_lines do
    local line = chunk_lines[j]
    if string.match(line, 'IGUID {(%S+)}') then
        local new_guid = reaper.genGuid()
        chunk_lines[j] = 'IGUID ' .. new_guid
    elseif string.match(line, "GUID {(%S+)}") then
        local new_guid = reaper.genGuid()
        chunk_lines[j] = 'GUID ' .. new_guid
    end

    if item_is_MIDI then
        if string.match(line, "POOLEDEVTS {(%S+)}") then
        local new_guid = reaper.genGuid()
        chunk_lines[j] = 'POOLEDEVTS' .. new_guid
        end

        if line == 'TAKE' then
        for k = j+1, #chunk_lines do -- scan chunk ahead to modify take chunk
            local take_line = chunk_lines[k]

            if string.match( take_line, 'POOLEDEVTS' ) then
            local new_guid = reaper.genGuid()
            chunk_lines[k] = 'POOLEDEVTS ' .. new_guid
            elseif string.match( take_line , 'GUID' ) then
            local new_guid = reaper.genGuid()
            chunk_lines[k] = 'GUID ' .. new_guid
            end

            if take_line == '>' then
            j = k
            goto take_chunk_break
            end
        end

        ::take_chunk_break::
        end
    end
    end

    chunk = table.concat(chunk_lines, "\n")

    return chunk
end

function u.placeItemCopyAtPosition(item, position)
    local chunk = u.getParsedItemChunk(item)
    local track = reaper.GetMediaItem_Track(item)
    local snapOffset = reaper.GetMediaItemInfo_Value(item, 'D_SNAPOFFSET')
    local newItem = reaper.AddMediaItemToTrack(track)
    
    reaper.SetItemStateChunk(newItem, chunk, true)
    reaper.SetMediaItemPosition(newItem, position - snapOffset, true)

    return newItem
end

function u.gridEmptyInRange(track, start, endPos) --returns false if there is an item
    local items = u.get_items_in_range(track, start, endPos)
    if #items == 0 then return true end
    
    local gridEmpty = true
    for i = 1, #items do
        local item = items[i]
        local position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        local snapOffset = reaper.GetMediaItemInfo_Value(item, 'D_SNAPOFFSET')
        snapOffset = snapOffset + position
        
        if math.abs(start - snapOffset) < 0.000001 then
            return false
        end
    end
    
    return true
end

function u.getItemsToTrim(track, start, endPos)
    local items = u.get_items_in_range(track, start, endPos)
    local b = {}
    for i = 1, #items do
        local item = items[i]
        local position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        local snapOffset = reaper.GetMediaItemInfo_Value(item, 'D_SNAPOFFSET')
        snapOffset = snapOffset + position
        
        if not (math.abs(start - snapOffset) < 0.000001) then
            table.insert(b, item)
        end
    end

    return b
end

function u.tryPlaceItem(track, item, start, endPos)
    reaper.PreventUIRefresh(1)
    
    local positionEmpty = u.gridEmptyInRange(track, start, endPos)
    local nextGrid = reaper.BR_GetNextGridDivision(endPos + 0.00000001)
    
    if positionEmpty then --if position is available 
        local items = u.getItemsToTrim(track, start, endPos)
        for i = 1, #items do
            u.setItemRightEdge(items[i], start)
        end
    else
        return
    end
    
    local newItem = u.placeItemCopyAtPosition(item, start)
    u.trimToNextItemIfNecessary(track, newItem, endPos)

    reaper.PreventUIRefresh(-1)
end

function u.tryDeleteItem(track, item, start, endPos)
    local items = u.get_items_in_range(track, start, endPos)
    local b = {}
    for i = 1, #items do
        local item = items[i]
        local position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        local snapOffset = reaper.GetMediaItemInfo_Value(item, 'D_SNAPOFFSET')
        snapOffset = snapOffset + position
        
        if math.abs(start - snapOffset) < 0.000001 or u.is_between(position, start, endPos) then
            table.insert(b, item)
        end
    end
    
    if reaper.ValidatePtr(item, 'MediaItem*') then --if not empty track
        local sourceLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        local sourceFade = reaper.GetMediaItemInfo_Value(item, 'D_FADEOUTLEN_AUTO')
        for i = #b, 1, -1 do
            local d_item = b[i]
            
            local prevItem = u.getPreviousItem(track, d_item)
            local nextItem = u.getNextItem(track, d_item)
            if prevItem ~= nil and nextItem == nil then --last item on track, restore original length
                local prevItemLength = reaper.GetMediaItemInfo_Value(prevItem, 'D_LENGTH')
                local prevItemPosition = reaper.GetMediaItemInfo_Value(prevItem, 'D_POSITION')
                if prevItem ~= nil and prevItemLength < sourceLength then
                    reaper.SetMediaItemInfo_Value(prevItem, 'D_LENGTH', sourceLength)
                    if not u.takeIsMIDI(prevItem) then
                        reaper.SetMediaItemInfo_Value(prevItem, 'D_FADEOUTLEN_AUTO', sourceFade)
                    end
                end
            elseif prevItem ~= nil and nextItem ~= nil then --middle item
                local nextItemPosition = reaper.GetMediaItemInfo_Value(nextItem, 'D_POSITION')
                local prevItemLength = reaper.GetMediaItemInfo_Value(prevItem, 'D_LENGTH')
                local prevItemPosition = reaper.GetMediaItemInfo_Value(prevItem, 'D_POSITION')
                if prevItem ~= nil and prevItemLength < sourceLength then
                    local targetLength = math.min(sourceLength, nextItemPosition - prevItemPosition)
                    reaper.SetMediaItemInfo_Value(prevItem, 'D_LENGTH', targetLength)
                    if targetLength == sourceLength and not u.takeIsMIDI(prevItem) then --restore fade
                        reaper.SetMediaItemInfo_Value(prevItem, 'D_FADEOUTLEN_AUTO', sourceFade)
                    end
                end
            elseif prevItem == nil and newItem == nil then

            end

            reaper.DeleteTrackMediaItem(track, b[i])
        end
    end
end

function u.takeIsMIDI(item)
    local take = reaper.GetMediaItemTake(item, 0)
    return  reaper.TakeIsMIDI(take)
end

function u.trimToNextItemIfNecessary(track, item, trimPos)
    local itemID = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
    local nextItem = reaper.GetTrackMediaItem(track, itemID + 1)
    if nextItem == nil then return end
    local nextItemPosition = reaper.GetMediaItemInfo_Value(nextItem, 'D_POSITION')
    
    local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    if itemPos + itemLength > nextItemPosition then
        u.setItemRightEdge(item, nextItemPosition)
    end
end

function u.lengthenPreviousIfNecessary(track, item, pos)

end

function u.getPreviousItem(track, item)
    local itemID = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
    local prevItem = reaper.GetTrackMediaItem(track, itemID - 1)

    return prevItem
end

function u.getNextItem(track, item)
    local itemID = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
    local prevItem = reaper.GetTrackMediaItem(track, itemID + 1)

    return prevItem
end


function u.get_items_in_range(track, start_pos, end_pos)
	local items_in_range = {}
  local track_item_count = reaper.CountTrackMediaItems(track)
  local floating_point_threshold = 0.000001
	
	for i = 0, track_item_count-1 do
    local item = reaper.GetTrackMediaItem(track, i)
		local item_position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
		
		local item_end_position = item_position + item_length - floating_point_threshold
		item_position = item_position + floating_point_threshold

		local item_overlaps_start = u.is_between(start_pos, item_position, item_end_position)
		local item_overlaps_end = u.is_between(end_pos, item_position, item_end_position)
		
    if (u.is_between(start_pos, item_position, item_end_position) or u.is_between(end_pos, item_position, item_end_position)) or 
      (item_position >= start_pos and item_end_position <= end_pos) then --item is in range
  
      table.insert(items_in_range, item) 
    end
  end
  
	return items_in_range
end

function u.setItemRightEdge(item, position)
    local itemPosition = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

    local targetLength = position - itemPosition
    reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', targetLength)
    if not u.takeIsMIDI(item) then
        reaper.SetMediaItemInfo_Value(item, 'D_FADEOUTLEN_AUTO', 0.005)
    end
end

function u.is_between(x, a,b)
	if x >= a and x <=b then
		return true
	else
		return false
	end
end

function u.delete_items_in_range_on_track(track, as_start, as_end)
  --save item selection
    reaper.PreventUIRefresh(-1)

    local selected_items = {}
    local selected_item_count = reaper.CountSelectedMediaItems(0)
    for i = 0, selected_item_count-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(selected_items, item)
    end

    local loop_start, loop_end = reaper.GetSet_LoopTimeRange(0, false, 1, 1, 0) --save time selection

    reaper.Main_OnCommand(40289, 0) --unselect all items
    reaper.GetSet_LoopTimeRange(1, false, as_start, as_end, 0) --make time selection

    --select items in range
    local items_in_range = u.get_items_in_range(track, as_start, as_end)

    for j = 1, #items_in_range do
    local item = items_in_range[j]
    reaper.SetMediaItemSelected(item, true)
    end
        
    reaper.Main_OnCommand(40061, 0) --split items at time selection
    reaper.Main_OnCommand(40006, 0) -- remove selected items

    reaper.GetSet_LoopTimeRange(1, false, loop_start, loop_end, 0) --restore time selection

    --restore item selection
    for i = 1, #selected_items do 
        local item = selected_items[i]
        if reaper.ValidatePtr( item, 'MediaItem' ) then
            reaper.SetMediaItemSelected(item, true)
        end
    end

    reaper.PreventUIRefresh(1)
end

function u.split_items_in_range_on_track(track, as_start, as_end)
  --save item selection
  local selected_items = {}
  local selected_item_count = reaper.CountSelectedMediaItems(0)
  for i = 0, selected_item_count-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(selected_items, item)
  end

  local loop_start, loop_end = reaper.GetSet_LoopTimeRange(0, false, 1, 1, 0) --save time selection
  
  reaper.Main_OnCommand(40289, 0) --unselect all items
	reaper.GetSet_LoopTimeRange(1, false, as_start, as_end, 0) --make time selection
	
	--select items in range
  local items_in_range = u.get_items_in_range(track, as_start, as_end)

  for j = 1, #items_in_range do
    local item = items_in_range[j]
    reaper.SetMediaItemSelected(item, true)
  end
		
  reaper.Main_OnCommand(40061, 0) --split items at time selection
  reaper.Main_OnCommand(40289, 0) --unselect all items
  
  reaper.GetSet_LoopTimeRange(1, false, loop_start, loop_end, 0) --restore time selection

  --restore item selection
  for i = 1, #selected_items do 
    local item = selected_items[i]
    if reaper.ValidatePtr( item, 'MediaItem' ) then
      reaper.SetMediaItemSelected(item, true)
    end
  end
end

--Thanks MPL for including these useful functions in your various functions script!
------------------------------------------------------------------------------------------------------
function u.WDL_DB2VAL(x) return math.exp((x)*0.11512925464970228420089957273422) end  --https://github.com/majek/wdl/blob/master/WDL/db2val.h
--function dBFromVal(val) if val < 0.5 then return 20*math.log(val*2, 10) else return (val*12-6) end end
------------------------------------------------------------------------------------------------------
function u.WDL_VAL2DB(x, reduce)   --https://github.com/majek/wdl/blob/master/WDL/db2val.h
if not x or x < 0.0000000298023223876953125 then return -150.0 end
local v=math.log(x)*8.6858896380650365530225783783321
if v<-150.0 then return -150.0 else 
    if reduce then 
    return string.format('%.2f', v)
    else 
    return v 
    end
end
end
------------------------------------------------------------------------------------------------------

return u