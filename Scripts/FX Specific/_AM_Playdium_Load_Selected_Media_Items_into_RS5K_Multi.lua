-- @version 1.0
-- @author Analogmad, MPL, JROPE
-- Initial Script by MPL and Analogmad (Chris Kowalski), modified by JROPE
-- "_Multi" version sends each track's selected items to their own instance of RS5K


local script_title = 'Playdium :Export selected items to RS5k instances per track'
-------------------------------------------------------------------------------   
function GlueSelectedItemsOnTrack(track_items)
  -- store GUIDs for items on this track
    local GUIDs = {}
    for i = 1, #track_items do
      local it_GUID = reaper.BR_GetMediaItemGUID(track_items[i])
      GUIDs[#GUIDs+1] = it_GUID
    end
    
  -- glue items
    local new_GUIDs = {}
    for i = 1, #GUIDs do
      local item = reaper.BR_GetMediaItemByGUID(0, GUIDs[i])
      if item then 
        reaper.Main_OnCommand(40289, 0) -- unselect all items
        reaper.SetMediaItemSelected(item, true)
        reaper.Main_OnCommand(40362, 0) -- glue without time selection
        local cur_item = reaper.GetSelectedMediaItem(0, 0)
        if cur_item then new_GUIDs[#new_GUIDs+1] = reaper.BR_GetMediaItemGUID(cur_item) end
      end
    end
  
  reaper.Main_OnCommand(40289, 0) -- unselect all items
  -- return new items
    local new_items = {}
    for i = 1, #new_GUIDs do
      local item = reaper.BR_GetMediaItemByGUID(0, new_GUIDs[i])
      if item then new_items[#new_items+1] = item end
    end
  return new_items
end
-------------------------------------------------------------------------------
function GetItemsByTrack()
  local tracks_items = {}
  
  -- Get all selected items and group them by track
  for item_idx = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, item_idx)
    local track = reaper.GetMediaItem_Track(item)
    
    if not tracks_items[track] then
      tracks_items[track] = {}
    end
    
    table.insert(tracks_items[track], item)
  end
  
  return tracks_items
end
-------------------------------------------------------------------------------
function GetRS5kID(tr)
  local id = -1
  for i = 1, reaper.TrackFX_GetCount(tr) do
    if ({reaper.TrackFX_GetFXName(tr, i-1, '')})[2]:find('RS5K') then return i-1 end
  end
  return id
end

function GetMidiRandID(tr)
  local id = -1
  for i = 1, reaper.TrackFX_GetCount(tr) do
    if ({reaper.TrackFX_GetFXName(tr, i-1, '')})[2]:find('_AM_Playdium_Random_Midi_Velocity_Generator') then return i-1 end
  end
  return id
end
-------------------------------------------------------------------------------
function ExportItemsToRs5k(track, items)   
  local number_of_samples = #items
  
  -- Get the index of the _AM_Playdium_Random_Midi_Velocity_Generator plugin
  local midirand_pos = GetMidiRandID(track)
  
  -- Add the _AM_Playdium_Random_Midi_Velocity_Generator plugin if it doesn't exist
  if midirand_pos == -1 then
    midirand_pos = reaper.TrackFX_AddByName(track, '_AM_Playdium_Random_Midi_Velocity_Generator', false, -1)
  end

  -- Get the index of the ReaSamplOmatic5000 plugin
  local rs5k_pos = GetRS5kID(track)

  -- Add the ReaSamplOmatic5000 plugin if it doesn't exist
  if rs5k_pos == -1 then
    rs5k_pos = reaper.TrackFX_AddByName(track, 'ReaSamplOmatic5000 (Cockos)', false, -1)
  end

  -- Iterate through samples and add them to the ReaSamplOmatic5000 instance
  for i = 1, number_of_samples do
    local item = items[i]
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local tk_src = reaper.GetMediaItemTake_Source(take)
      local filename = reaper.GetMediaSourceFileName(tk_src, '')
      
      reaper.TrackFX_SetParam(track, midirand_pos, 1, number_of_samples) -- setting amount of samples in sampler in velocity Generator
      reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 3, 0) -- note range start
      reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 8, .17) -- max voices = 12
      reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 9, 0) -- attack
      reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 11, 1) -- obey note offs
      reaper.TrackFX_SetNamedConfigParm(track, rs5k_pos, "FILE"..(i-1), filename)
    end
  end
  if rs5k_pos then reaper.TrackFX_SetNamedConfigParm(track, rs5k_pos, "DONE","") end
end

-------------------------------------------------------------------------------  
function main()   
  -- item check
    local item = reaper.GetSelectedMediaItem(0,0)
    if not item then return true end        
   
  -- Get items grouped by track
    local tracks_items = GetItemsByTrack()
    
  -- Process each track separately
    for track, items in pairs(tracks_items) do
      -- glue items for this track
      local glued_items = GlueSelectedItemsOnTrack(items)
      
      -- export to RS5k for this track
      ExportItemsToRs5k(track, glued_items)
      MIDI_prepare(track)
    end
    
    reaper.UpdateArrange()
end
-------------------------------------------------------------------------------
function MIDI_prepare(tr)
  local bits_set=tonumber('111111'..'00000',2)
  reaper.SetMediaTrackInfo_Value( tr, 'I_RECINPUT', 4096+bits_set ) -- set input to all MIDI
  reaper.SetMediaTrackInfo_Value( tr, 'I_RECMON', 1) -- monitor input
  reaper.SetMediaTrackInfo_Value( tr, 'I_RECARM', 1) -- arm track
  reaper.SetMediaTrackInfo_Value( tr, 'I_RECMODE',1) -- record STEREO out
end

-------------------------------------------------------------------------------    
reaper.Undo_BeginBlock()
main()  
reaper.Undo_EndBlock(script_title, 1)
