
if reaper.CountSelectedMediaItems(0) == 0 then
return
elseif reaper.CountSelectedMediaItems(0) > 1 then
return
end

selectedItem = reaper.GetSelectedMediaItem(0,0)
activeTake = reaper.GetMediaItemInfo_Value(selectedItem,"I_CURTAKE")
selectedTake = reaper.GetTake(selectedItem,activeTake)
PCM_src = reaper.GetMediaItemTake_Source(selectedTake)


isSection = reaper.PCM_Source_GetSectionInfo(PCM_src)

if isSection then

reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_NUDGSECTLOOPOLNEG"),0)
reaper.Main_OnCommand(40547, 0)
reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_ITEMTRKCOL"),0)

else

reaper.Main_OnCommand(40547, 0)
reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_NUDGSECTLOOPOLPOS"),0)
reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_ITEMCUSTCOL1"),0)

end

