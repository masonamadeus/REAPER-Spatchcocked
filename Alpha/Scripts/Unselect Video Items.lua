local selected_items = reaper.CountSelectedMediaItems(0)
local videoSources = {}
for i=0, selected_items-1 do
  local itemV = reaper.GetSelectedMediaItem(0,i)
  local sourceV = reaper.GetMediaItemTake_Source(reaper.GetMediaItemTake(itemV,0))
  local sourceType = reaper.GetMediaSourceType(sourceV)
  if sourceType == "VIDEO" then 
    table.insert(videoSources,itemV)
  end
end

for _,video in ipairs(videoSources) do
  reaper.SetMediaItemSelected(video,false)
end
