
--[[ ====================================
============ USER VARIABLES =============
=====================================]]--

glueDistance = 0.5
minLength = 1.2


--[[ ===== DEBUGGING FUNCTIONS ======]]--
function pt(table)
  for k,v in pairs(table) do
    reaper.ShowConsoleMsg("Key: "..tostring(k).."\nValue: "..tostring(v).."\n---\n")
  end
end

function p(name,prop)
  reaper.ShowConsoleMsg(name..": "..tostring(prop).."\n")
end

--[[=====================================
==== FUNCTION DEFINITION SECTION ========
=====================================]]--



-- GET PROJECT-BASED INDEX OF MEDIA ITEM
function GetMediaItem_Index(MediaItem)
  local Track=reaper.GetMediaItem_Track(MediaItem)
  local Trackid=-1
  -- get the index of the parent track of the item
  for i=0, reaper.CountTracks(0) do
    if Track~=reaper.GetTrack(0,i) then
      Trackid=Trackid+1
    elseif Track==reaper.GetTrack(0,i) then
      Trackid=Trackid+1
      break
    end
  end

  -- now use the index, to count together all items in the tracks
  local ItemCount=-1
  for i=0, Trackid-1 do
    ItemCount=ItemCount+reaper.CountTrackMediaItems(reaper.GetTrack(0,i))
  end

  -- and then add the trackindex of the item for the final number
  ItemCount=ItemCount+reaper.GetMediaItemInfo_Value(MediaItem, "IP_ITEMNUMBER")
  return ItemCount+1
end











-- BUILD TABLE OF ALL SELECTED MEDIA ITEMS ===========================================================
function getIdx()
  -- Get the current project
  local proj = reaper.EnumProjects(-1)
  
  -- Create a table to store the item indexes
  local indexes = {}
  
  local sel_items = reaper.CountSelectedMediaItems(proj)
  -- Iterate over the selected items and store their indexes in the table
  for i = 0, sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(proj, i)
    local index = GetMediaItem_Index(item)
    table.insert(indexes, index)
  end
  
  table.sort(indexes)
  return indexes
end









-- CREATE GROUPS FOR GLUING  ============================================================================
function buildGlueGroups(itemTable, range)

    local glueTable = {} -- Initialize an empty table to hold items that are within range
    local glueGroups = {} -- Initialize an empty table to hold glueTables for later processing
    
    -- Iterate over all the items in the table
    for i = 1, #itemTable do
        local itemA = reaper.GetMediaItem(0, itemTable[i])
        
        -- If the item is not null, check if any other items in the table are within the range
        if itemA ~= nil then
            
            -- If the glueTable is empty, add the item to it
            if #glueTable == 0 then
                table.insert(glueTable, itemA)
                
            else
                local itemB = glueTable[#glueTable] -- Get the last item in the glueTable
                local posA = reaper.GetMediaItemInfo_Value(itemA, "D_POSITION")
                local lenA = reaper.GetMediaItemInfo_Value(itemA, "D_LENGTH")
                local posB = reaper.GetMediaItemInfo_Value(itemB, "D_POSITION")
                local lenB = reaper.GetMediaItemInfo_Value(itemB, "D_LENGTH")
                
                -- If the two items are within the specified range, add the second item to the glueTable
                if math.abs(posB + lenB - posA) <= range then
                    table.insert(glueTable, itemA)
                    
                -- If the two items are not within range, store the glue group
                else
                    table.insert(glueGroups,glueTable)
                    glueTable = {itemA} -- Start a new glueTable with the current item
                end
            end
        end
    end
    
    if #glueTable > 0 then
      table.insert(glueGroups,glueTable)
    end
    return glueGroups
end




-- DUPLICATE MEDIA ITEMS (ADAPTED FROM AMAGALMA'S CODE)=================================================
local function DuplicateItemInPlace( item )
  local track = reaper.GetMediaItem_Track(item)
  local position = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local _, chunk = reaper.GetItemStateChunk( item, "", false )
  chunk = chunk:gsub("{.-}", "") -- Reaper auto-generates all GUIDs
  local new_item = reaper.AddMediaItemToTrack( track )
  reaper.SetItemStateChunk( new_item, chunk, false )
  reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , position )
  return new_item
end





-- ACTUALLY GLUE THINGS TOGETHER ========================================================================
--[[
function doGlueGroups(glueGroups)
  
  local glueSources = {}
  
  for i = 1, #glueGroups do
    reaper.SelectAllMediaItems(0,false)
    -- REMOVE TIME SELECTION
    reaper.Main_OnCommand(40020,0)
    local glueTable = glueGroups[i]
    for j = 1, #glueTable do
      local item = glueTable[j]
      reaper.SetMediaItemSelected(item, true)
    end
    
    -- Check if it's too short
    local selItems = reaper.CountSelectedMediaItems(0)
    local firstItem = reaper.GetSelectedMediaItem(0,0)
    local lastItem = reaper.GetSelectedMediaItem(0,selItems-1)
    local startPos = reaper.GetMediaItemInfo_Value(firstItem, "D_POSITION")
    local endPos = reaper.GetMediaItemInfo_Value(lastItem,"D_POSITION") + reaper.GetMediaItemInfo_Value(lastItem,"D_LENGTH")
    
    local selStart, selEnd = reaper.GetSet_LoopTimeRange(true,false,startPos,endPos,false)
    local selLength = math.abs(selStart - selEnd)
    
    for t = 0, selItems-1 do
      it = reaper.GetSelectedMediaItem(0,t)
      nit = DuplicateItemInPlace(it)
      reaper.SetMediaItemSelected(nit,true)
      reaper.SetMediaItemSelected(it,false)
    end
    
    if selLength < minLength then
    
      local adjustment = math.abs((minLength-selLength))
      reaper.GetSet_LoopTimeRange(true,false,selStart, selEnd+adjustment,false)
      
      
    -- Glue expanding to time selection
      reaper.Main_OnCommand(41588,0)
    
    else
     -- Glue items
      reaper.Main_OnCommand(40362, 0)
    
    end
    
    -- Send glued item to table
      local gluedItem = reaper.GetSelectedMediaItem(-1,0)
      local gluedSource = reaper.GetMediaItemTake_Source(reaper.GetMediaItemTake(gluedItem,0))
      local gluedPath = reaper.GetMediaSourceFileName(gluedSource)
      glueSources[gluedPath] = gluedItem
      createSubTrack(reaper.GetMediaItem_Track(gluedItem))
      reaper.MoveMediaItemToTrack(gluedItem,reaper.GetSelectedTrack(0,0))
  end
  
  reaper.UpdateArrange()
  return glueSources
  
end

]]



-- GLUE ONE GROUP TOGETHER ========================================================================
function doGlueGroup(glueTable)
  
  local glueSources = {}
  
  -- DESELCT ALL ITEMS
  reaper.SelectAllMediaItems(0,false)
  -- REMOVE TIME SELECTION
  reaper.Main_OnCommand(40020,0)
  
  for j = 1, #glueTable do
    local item = glueTable[j]
    reaper.SetMediaItemSelected(item, true)
  end
  
  -- Check if it's too short
  local selItems = reaper.CountSelectedMediaItems(0)
  local firstItem = reaper.GetSelectedMediaItem(0,0)
  local lastItem = reaper.GetSelectedMediaItem(0,selItems-1)
  local startPos = reaper.GetMediaItemInfo_Value(firstItem, "D_POSITION")
  local endPos = reaper.GetMediaItemInfo_Value(lastItem,"D_POSITION") + reaper.GetMediaItemInfo_Value(lastItem,"D_LENGTH")
  
  local selStart, selEnd = reaper.GetSet_LoopTimeRange(true,false,startPos,endPos,false)
  local selLength = math.abs(selStart - selEnd)
  
  for t = 0, selItems-1 do
    it = reaper.GetSelectedMediaItem(0,t)
    nit = DuplicateItemInPlace(it)
    reaper.SetMediaItemSelected(nit,true)
    reaper.SetMediaItemSelected(it,false)
  end
  
  if selLength < minLength then
  
    local adjustment = math.abs((minLength-selLength))
    reaper.GetSet_LoopTimeRange(true,false,selStart, selEnd+adjustment,false)
    
    
  -- Glue expanding to time selection
    reaper.Main_OnCommand(41588,0)
  
  else
   -- Glue items
    reaper.Main_OnCommand(40362, 0)
  
  end
  
  -- Send glued item to table
  local gluedItem = reaper.GetSelectedMediaItem(-1,0)
  local gluedSource = reaper.GetMediaItemTake_Source(reaper.GetMediaItemTake(gluedItem,0))
  local gluedPath = reaper.GetMediaSourceFileName(gluedSource)
  glueSources[gluedPath] = gluedItem
  createSubTrack(reaper.GetMediaItem_Track(gluedItem))
  reaper.MoveMediaItemToTrack(gluedItem,reaper.GetSelectedTrack(0,0))
  
  return glueSources
  
end






-- SEND THE FILES TO TRANSCRIBER  ============================================================================
function transcribeChunk(source)

  local aiPath = '\"'.. reaper.GetResourcePath() ..'\\WhisperAI\\main.exe\" ' 
  
  local modelPath = '-m \"'.. reaper.GetResourcePath() ..'\\WhisperAI\\models\\ggml-medium.en.bin\" '
  
  local aiOptions = '-gpu \"NVIDIA GeForce RTX 3070\" -mc 0 -osrt '
  
  local path = '-f \"'..source..'\"'
  
  command = aiPath .. modelPath .. aiOptions .. path
  
  local retval = reaper.ExecProcess(command,0)
  srtPath = source:match("(.+)%..+$") .. ".srt"
  return srtPath
end









-- IMPORT SRT FILES (Calls HeDa's Script, modified) ===========================================================
function importSRT(item, srtFile)
  local itemStart = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local itemEnd = itemStart+reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
  reaper.SetEditCurPos(reaper.GetMediaItemInfo_Value(item,"D_POSITION"),false,false)
  local newText = read_lines(srtFile)
  local finalSub = newText[#newText]
  local finalSubStart = reaper.GetMediaItemInfo_Value(finalSub,"D_POSITION")
  reaper.SetMediaItemInfo_Value(finalSub,"D_LENGTH",itemEnd-finalSubStart)
  return newText
end



function createBossBufTracks()

  reaper.InsertTrackAtIndex(0,false)
  local bossTrack = reaper.GetTrack(0,0)
  reaper.SetMediaTrackInfo_Value(bossTrack,"I_FOLDERDEPTH",1)
  reaper.GetSetMediaTrackInfo_String(bossTrack,"P_NAME","ST_BOSS",true)
  AddVideoProc(bossTrack,2)
  
  
  reaper.InsertTrackAtIndex(1,false)
  bufTrack = reaper.GetTrack(0,1)
  reaper.SetMediaTrackInfo_Value(bufTrack,"I_FOLDERDEPTH",-1)
  
  return bufTrack
  
end


-- CREATE SUBTITLE TRACK ======================================================================================
function createSubTrack(track)
  -- Get the incoming item's track
  local parent_track = track
  
  -- 
  for existingTrack,existingParent in pairs(subTracks) do
    if parent_track == existingParent then
      reaper.SetOnlyTrackSelected(existingTrack)
      return
    end
  end
  
  local ret, parent_name = reaper.GetTrackName(parent_track)
  local speaker_name = parent_name:match("[^_]*$")
  local child_name = "ST_"..speaker_name
  
  -- Create a new track below the parent track
  local track_index = reaper.GetMediaTrackInfo_Value(bufTrack, "IP_TRACKNUMBER") - 1
  reaper.InsertTrackAtIndex(track_index, false)
  local new_track = reaper.GetTrack(0,track_index)
  
  --[[ Make the new track a child of the parent track
  local parent_depth = reaper.GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")
  reaper.SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", parent_depth + 1)]]
  
  -- Set the name of the new track
  reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", child_name, true)
  
  subTracks[new_track] = parent_track
  
  -- Add the video processor
  AddVideoProc(new_track,0)
  
  reaper.SetOnlyTrackSelected(new_track)
end



--[[XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX]]--
--[[XXXX   MPL'S WORK, ADD FX CHAIN. NEEDED TO IMPORT IT HERE TO MODIFY IT    XXXX]]--
--[[XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX]]--

function AddVideoProc(tr,chunkSel) -- && add empty fx chain chunk if not exists
    
    local chunk1 = [[BYPASS 0 0
    <VIDEO_EFFECT "Video processor" ""
      <CODE
        |// FEED NAME
        |n = 0;
      >
      CODEPARM 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
    >
    WAK 0 0
    ]]
    

local chunk2 = [[BYPASS 0 0
<VIDEO_EFFECT "Video processor" ""
  <CODE
    |// SUBTITLE BOSS
    |font="Arial";
    |//@param1:lineSpacing 'Subtitle Spacing' 20 1 80 40 1
    |//@param2:size 'text height' 0.04 0.01 0.1 0.05 0.001
    |
    |//@param4:fgr 'text red' 1.0 0 1 0.5 0.01
    |//@param5:fgg 'text green' 1.0 0 1 0.5 0.01
    |//@param6:fgb 'text blue' 1.0 0 1 0.5 0.01
    |//@param7:fgc 'text bright' 1.0 0 1 0.5 0.01
    |//@param8:fga 'text opacity' 1.0 0 1 0.5 0.01
    |
    |//@param10:bgr 'bg red' 0.75 0 1 0.5 0.01
    |//@param11:bgg 'bg green' 0.75 0 1 0.5 0.01
    |//@param12:bgb 'bg blue' 0.75 0 1 0.5 0.01
    |//@param13:bgc 'bg bright' 0.75 0 1 0.5 0.01
    |//@param14:bga 'bg opacity' 0.5 0 1 0.5 0.01
    |
    |//@param16:border 'bg padding' 0.1 0 1 0.5 0.01
    |
    |// black to 100% transparent 
    |colorspace="RGBA";
    |input_info(0,project_w,project_h)?(
    |  gfx_img_resize(-1,project_w,project_h);
    |  gfx_blit(0);
    |  gfx_evalrect(0,0,project_w,project_h,"r+g+b==0?a=0");
    |);
    |
    |//lineSpacing = 20;
    |//num_speakers = num_speakers + 1;
    |
    |// MEASURE LINE WIDTH
    |gfx_setfont(size*project_h,font);
    |#testStr = "W";
    |gfx_str_measure(#testStr,charW,charH);
    |charPerLine = ceil(project_w/charW);
    |
    |// COUNT NUMBER OF INPUTS
    |num_tracks = input_track_count();
    |
    |// loop thru input tracks and XXXtable those that match ST_XX
    |#matchStr = "ST_*";
    |filter = -10000;
    |
    |
    |
    |//offX = 0;
    |//offY = 0;
    |inc = 500; // INTEGERS FOR STRINGS
    |prevBoxH = 0;
    |prevBoxW = 0;
    |//boxH = 0;
    |//boxW = 0;
    | 
    |inputTk = 0;
    | 
    |loop(num_tracks,
    |    string = inc+2;
    |    spkString = inc+1;
    |    input_get_name(inputTk,#FirstCheck);
    |    // if the input has a track name, that's the speaker
    |    firstSTTrack = input_match(inputTk,#matchStr);
    |    firstSTTrack != filter ?
    |    (
    |      // see if the next item is dialog
    |      inputChk = input_next_item(inputTk);
    |      input_get_name(inputChk,#SecondCheck);
    |      
    |      input_get_name(inputChk,string);
    |  
    |      //compare start of the next input with the ST code
    |      str_setlen(string,3);
    |      isDialog = strcmp(string,"ST_");
    |      isDialog == 0 ?
    |      //if equal, skip ahead
    |      (
    |        inputTk = inputTk + 1;
    |      )://else,
    |      (
    |        // set the spkString as the speaker name
    |        input_get_name(inputTk,spkString);
    |        str_delsub(spkString,0,3);
    |        strcat(spkString,": ");
    |  
    |        inputTk = inputChk;
    |        input_get_name(inputTk, string);
    |        
    |        textLength = strlen(string);
    |          
    |        textLength > 0 ?
    |          (
    |            inputChk = inputTk;
    |            spkCheck = strlen(spkString);
    |            spkCheck > 5 ? 
    |            (
    |              str_insert(string,spkString,0);
    |            );
    |            // PROCESS 'string' INTO SUBTITLES
    |            textLength = strlen(string);
    |            numLines = ceil(textLength/charPerLine);
    |            lineLength = ceil(textLength/numLines);
    |            breakpoint = lineLength;
    |        
    |            numLines > 1 ?
    |          
    |            loop(numLines-1,
    |              //find a space character
    |              while ( str_getchar(string,breakpoint) !=32 )
    |              (
    |                breakpoint=breakpoint+1;
    |              );
    |            
    |              // break string and remove space
    |              str_delsub(string,breakpoint,1);
    |              str_insert(string,"\n",breakpoint);
    |            
    |              // adjust breakpoint for next line
    |              breakpoint=lineLength+breakpoint;
    |            );
    |            
    |        
    |            //Measure the string again because now we gotta draw a background
    |            gfx_str_measure(string,txtw,txth);
    |        
    |            // Add padding to box
    |            b = (border*txth);
    |            boxW = (txtw+b*2);
    |            boxH = (txth+b*2);
    |          
    |            //Offset of each subtitle block
    |            offX = (project_w-boxW)/2;
    |            offY = project_h - boxH - (prevBoxH*1) - lineSpacing;
    |        
    |            //backdrop 
    |            gfx_set(bgc*bgr,bgc*bgg,bgc*bgb,bga);
    |            bga>0?gfx_fillrect(offX+b, offY, boxW, boxH);
    |            //text
    |            gfx_set(fgc*fgr,fgc*fgg,fgc*fgb,fga);
    |            gfx_str_draw(string,offX+b*2,offY+b);
    |            
    |            prevBoxH=(prevBoxH)+boxH+lineSpacing;
    |          );
    |        );
    |        inc = inc+3;
    |      
    |    );
    |    
    |);
  >
  CODEPARM 26 0.045 0.4 1 1 1 1 1 0 0.75 0.67 0.75 0.75 0.78 0 0.1 0.1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
>
WAK 0 0
]]
  if chunkSel > 0 then chunk = chunk2 else chunk = chunk1 end
  
    local _, chunk_ch = reaper.GetTrackStateChunk(tr, '', false)
    if not chunk_ch:match('FXCHAIN') then chunk_ch = chunk_ch:sub(0,-3)..'<FXCHAIN\nSHOW 0\nLASTSEL 0\n' end
    chunk_ch = chunk_ch .. chunk ..  "DOCKED 0\n>\n>\n"
    reaper.SetTrackStateChunk(tr, chunk_ch, false)
  end 

--[[XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX]]--
--[[XXXX   HEDA'S WORK. NEEDED TO IMPORT IT HERE TO MODIFY IT    XXXX]]--
--[[XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX]]--
--[[
 * ReaScript Name: Import SRT
 * Description: Imports SRT subtitles file as Text items
 * Instructions: Note that the initial cursor position is very important 
 * Author: HeDa
 * Author URl: http://forum.cockos.com/member.php?u=47822
 * Version: 0.3 beta
 * Repository: 
 * Repository URl: 
 * File URl: 
 * License: GPL v3
 * Forum Thread:
 * Forum Thread URl: 
 * REAPER: 5.0
 * Extensions: 
]]

  function HeDaSetNote(item,newnote)  -- HeDa - SetNote v1.0
    --ref: Lua: boolean retval, string str reaper.GetSetItemState(MediaItem item, string str)
    local retval, s = reaper.GetSetItemState(item, "")  -- get the current item's chunk
    --dbug("\nChunk=" .. s .. "\n")
    local has_notes = s:find("<NOTES")  -- has notes?
    if has_notes then
      -- there are notes already
      chunk, note, chunk2 = s:match("(.*<NOTES\n)(.*)(\n>\nIMGRESOURCEFLAGS.*)")
      newchunk = chunk .. newnote .. chunk2
      -- dbug(newchunk .. "\n")
      
    else
      --there are still no notes
      chunk,chunk2 = s:match("(.*IID%s%d+)(.*)")
      newchunk = chunk .. "\n<NOTES\n" .. newnote .. "\n>\nIMGRESOURCEFLAGS 0" .. chunk2
      -- dbug(newchunk .. "\n")
    end
    reaper.GetSetItemState(item, newchunk)  -- set the new chunk with the note
  end

----------------------------------------------------------------------
function CreateTextItem(starttime, endtime, notetext)

  --ref: Lua: number startOut retval, number endOut reaper.GetSet_LoopTimeRange(boolean isSet, boolean isLoop, number startOut, number endOut, boolean allowautoseek)
  reaper.GetSet_LoopTimeRange(1,0,starttime,endtime,0)  -- define the time range for the empty item
  
  --ref: Lua:  reaper.Main_OnCommand(integer command, integer flag)
  reaper.Main_OnCommand(41932,0) -- insert empty video item
  
  --ref: Lua: MediaItem reaper.GetSelectedMediaItem(ReaProject proj, integer selitem)
  item = reaper.GetSelectedMediaItem(0,0) -- get the selected item
  reaper.SetMediaItemPosition(item, starttime, true)
  reaper.SetMediaItemLength(item, endtime-starttime, true)
  table.insert(createdTextItems,item)
  
  HeDaSetNote(item, notetext) -- set the note  add | character to the beginning of each line. only 1 line for now.
  
  reaper.SetEditCurPos(endtime, 1, 0)  -- moves cursor for next item
end

function ReadFile(which)
  if reaper.file_exists(which) then 
       local f = io.open(which)
       local file = {}
       local k = 1
       for line in f:lines() do
        file[k] = line
        k = k + 1
       end
       f:close()
       return file
  else 
    p("file doesn't exist",which)
    return nil
  end
end

function read_lines(filepath)
  
  local initialtime = reaper.GetCursorPosition();  -- store initial cursor position as time origin 00:00:00
  local items={}
  local lines={}
  local srtfile = ReadFile(filepath)
    if srtfile then 
    local num=0
    for f, s in ipairs(srtfile) do
      if s~=nil then
        if string.find(s,'-->') then
          --00:04:22,670 --> 00:04:26,670
          sh, sm, ss, sms, eh, em, es, ems = s:match("(.*):(.*):(.*),(.*)%-%->(.*):(.*):(.*),(.*)")
          if sh then
            positionStart = tonumber(sh)*3600 + tonumber(sm)*60 + tonumber(ss) + (tonumber(sms)/1000)
            positionEnd = tonumber(eh)*3600 + tonumber(em)*60 + tonumber(es) + (tonumber(ems)/1000)
            table.insert(items, {["positionStart"]=positionStart, ["positionEnd"]=positionEnd, ["lines"]={},})
            num=num+1
            endsub=nil
            local i=0
            while not endsub and i<10 do 
              i=i+1
              line=srtfile[f+i]
              if line~="\r" and line~="\n" and line~="" and line~="\r\n" then 
                table.insert(items[num].lines, line)
              else
                endsub=true
              end
            end
        
          end
        end
      end
    end
    local  numcount=0
    for j,k in ipairs(items) do 
      local textline = ""
      for a,line in ipairs(k.lines) do 
        textline = textline .. "|" .. line .. "\n"
      end
      CreateTextItem(k.positionStart + initialtime, k.positionEnd + initialtime, textline)
      numcount=numcount+1
    end
    
  end
  
  reaper.Main_OnCommand(40020,0) -- remove time selection
  reaper.Main_OnCommand(40289,0) -- unselect all items
  
  --ref: reaper.SetEditCurPos(number time, boolean moveview, boolean seekplay)
  reaper.SetEditCurPos(initialtime, 1, 1) -- move cursor to original position before running script
  return createdTextItems
  
end


--[[XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX]]--
--[[XXXX  X-RAYM'S WORK. NEEDED TO IMPORT IT HERE TO MODIFY IT  XXXX]]--
--[[XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX]]--
--[[
 * ReaScript Name: Convert selected item notes to take name
 * About: Convert selected item notes to take name
 * Instructions: Select an item. Use it.
 * Author: X-Raym
 * Author URI: https://www.extremraym.com
 * Repository: GitHub > X-Raym > REAPER-ReaScripts
 * Repository URI: https://github.com/X-Raym/REAPER-ReaScripts
 * Licence: GPL v3
 * Version: 1.1
 * Version Date: 2015-03-25
 * REAPER: 5.0 pre 15
 * Extensions: SWS/S&M 2.6.0

 * Changelog:
 * v1.1 (2015-03-25)
  + bug fix (if empty item was selected)
 * v1.0 (2015-03-24)
  + Initial Release
--]]

function note_to_name(item)

    local take = reaper.GetActiveTake(item)

    if take ~= nil then
      -- GET NOTES
      local note = reaper.ULT_GetMediaItemNote(item)
      note = note:gsub("\n", " ")
      --reaper.ShowConsoleMsg(note)

      -- MODIFY TAKE
      local retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", note, 1)
    end

end

--[[XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX]]--



























































--[[======================================================================]]--
--[[=========XXXXXXX      M A I N      F U N C T I O N     XXXXXXX========]]--
--[[======================================================================]]--
function main()
  reaper.Undo_BeginBlock()
  
-- ripple off
  reaper.Main_OnCommand(40309,0)
  
-- automation move off
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_MVPWIDOFF"),0)
  
  -- TABLE OF CREATED SUBTITLE ITEMS
  createdTextItems = {}
  -- TABLE OF CREATED SUBTITLE TRACKS
  subTracks = {}

  -- get user input
  local user_ok, user_input = reaper.GetUserInputs("Set Max Gap", 1, "Max Gap (default: 0.5s):", "")
    if user_ok then
      local gap = tonumber(user_input)
      if gap ~= nil and gap >= 0.1 and gap <= 15 then
        glueDistance = gap
      else
        reaper.ShowMessageBox("Invalid input. Max Gap must be between 0.1 and 15 seconds.", "Error", 0)
      end
    else
      return
    end
  
-- make SRT Boss/Buf
  bufTrack = createBossBufTracks()
-- build item list from selection
  local items = getIdx()

-- build groups for gluing
  local glueGroups = buildGlueGroups(items,glueDistance)

-- FORCE media offline, so transcriber can read it
  reaper.Main_OnCommand(40100,0)
  
-- DESELECT ALL TRACKS 
  reaper.Main_OnCommand(40297,0)

  local tipX, tipY = reaper.GetMousePosition()
-- DO IT LETS GOOOO
  reaper.PreventUIRefresh(1)
  for idx = 1, #glueGroups do
    local progress = math.floor(idx*100/#glueGroups)
    local progressString = "SUBTITLING: "..tostring(idx).."/"..tostring(#glueGroups).." -- "..tostring(progress).."%"
    reaper.TrackCtl_SetToolTip(progressString,tipX,tipY,true)
    
    local glueSourcesT = doGlueGroup(glueGroups[idx])
    for source,item in pairs(glueSourcesT) do
    
      reaper.SelectAllMediaItems(0,false)
      local file = transcribeChunk(source)
      if reaper.file_exists(file) then
        local subTrack = reaper.GetMediaItemTrack(item)
        reaper.SetOnlyTrackSelected(subTrack)
        local subtitle_items = importSRT(item,file)
        for i=1, #subtitle_items do
          local stItem = subtitle_items[i]
          note_to_name(stItem)
        end
          os.remove(file)
      end
      
      -- CLEAN UP EXCESS FILES
      reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item),item)
      os.remove(source)
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.TrackCtl_SetToolTip("",tipX,tipY,true)
  
-- Bring media back online
  reaper.Main_OnCommand(40101,0)




-- update the view & set the undo
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Transcribe",0)
  

end
-- UNCOMMENT TO RUN 

main()

--]]










