--[[
@description Set all selected video items to Ignore Audio
@version 1.0
@author Claudiohbsantos
@link http://claudiohbsantos.com
@date 2018 03 09
@about
  # Set all selected video items to Ignore Audio
  
@changelog
  - initial release
--]]

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

------------------

local numSelectedItems = reaper.CountSelectedMediaItems(0)

for i=0, numSelectedItems-1 do
  local item = reaper.GetSelectedMediaItem(0,i)
  local chunk = ""
  local retval,chunk = reaper.GetItemStateChunk(item,chunk,false)
  if retval then 
    local ignoreAudioSetting = "AUDIO 0\n"
    local chunk,nmatches = chunk:gsub("<SOURCE VIDEO\nFILE ","<SOURCE VIDEO\n"..ignoreAudioSetting.."FILE ")
    if nmatches > 0 then
      reaper.SetItemStateChunk(item,chunk,false)
    end
  end
end

-- Get the number of selected items

-- Create a table to store items with the same take name (minus the last four characters)
local itemsToMove = {}
local targetTracks = {}

-- Loop through each selected item
for i = 0, numSelectedItems - 1 do
  -- Get the current item
  local item = reaper.GetSelectedMediaItem(0, i)

  -- Get the take of the item
  local take = reaper.GetActiveTake(item)

  -- Check if the take exists and has a name
  if take and reaper.TakeIsMIDI(take) == false then
    local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

    -- Extract the base take name (minus the last four characters)
    local baseTakeName = string.sub(takeName, 1, -5)

    -- Check if an item with the same base take name has already been found
    if itemsToMove[baseTakeName] then
      local storedItem = itemsToMove[baseTakeName]
      local currentItem = item
      
      local storedTake =  reaper.GetActiveTake(storedItem)
      local currentTake = reaper.GetActiveTake(currentItem)
      
      local _, storedName = reaper.GetSetMediaItemTakeInfo_String(storedTake, "P_NAME", "", false)
      local _, currentName = reaper.GetSetMediaItemTakeInfo_String(currentTake, "P_NAME", "", false)
      
      local storedExt = storedName:match("%.(%w+)$")
      local currentExt = currentName:match("%.(%w+)$")
      
      -- make sure .wav items are on top
      if string.match(currentExt,"wav") then
        local targetTrack = reaper.GetMediaItemTrack(storedItem)
        local originalTrack = reaper.GetMediaItemTrack(currentItem)
        reaper.MoveMediaItemToTrack(currentItem, targetTrack)
        reaper.DeleteTrack(originalTrack)
        table.insert(targetTracks,targetTrack)
      else
        local targetTrack = reaper.GetMediaItemTrack(currentItem)
        local originalTrack = reaper.GetMediaItemTrack(storedItem)
        reaper.MoveMediaItemToTrack(storedItem, targetTrack)
        reaper.DeleteTrack(originalTrack)
        table.insert(targetTracks,targetTrack)
      end
      
    else
      -- Store the item in the table for future reference
      itemsToMove[baseTakeName] = item
    end
  end
end

--group items that are now on the same track
for index, track in ipairs(targetTracks) do
  reaper.Main_OnCommand(40289,0)
  reaper.SetOnlyTrackSelected(track)
  reaper.Main_OnCommand(40421, 0)
  reaper.Main_OnCommand(40032,0)
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("PodCube AV Combine",0)

reaper.UpdateArrange()
