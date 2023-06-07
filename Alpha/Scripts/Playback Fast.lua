
-- Function to be executed when spacebar is pressed
function speedUp()
  reaper.Main_OnCommand(40522, 0)
  reaper.Main_OnCommand(40522, 0)
  reaper.Main_OnCommand(40522, 0)
  reaper.Main_OnCommand(40522, 0)
  reaper.Main_OnCommand(40522, 0)
  reaper.Main_OnCommand(40522, 0)
  reaper.Main_OnCommand(40522, 0)
  reaper.Main_OnCommand(40522, 0)
end

function speedNormal()
  reaper.Main_OnCommand(40521, 0)
end

-- Function to be executed when spacebar is released
function resetSpeed()
  local playRate = reaper.Master_GetPlayRate(0)
  if playRate > startingPlayrate then
    speedNormal()
  else
    speedUp()
  end
end

function tick()
  if reaper.GetPlayState() == 1 then
    reaper.defer(tick)
    else
    resetSpeed()
  end 
end


  reaper.Undo_BeginBlock()
startingPlayrate = reaper.Master_GetPlayRate(0)
if startingPlayrate > 1 then
  speedNormal()
else
  speedUp()
end
reaper.Main_OnCommand(40044,0)
tick()
  reaper.Undo_EndBlock("Play Fast",0)

