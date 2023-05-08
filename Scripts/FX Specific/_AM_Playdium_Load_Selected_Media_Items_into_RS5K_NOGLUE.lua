-- @version 1.0
-- @author Analogmad, MPL 
-- Initial Script by MPL Modified by Analogmad (Chris Kowalski)
-- MPL Helped me with this via the Reaper Forums. I had an issue of putting all samples into one RS5K. Added Arming for Audio Recording. Added Velocity Randomizer

local script_title = 'Playdium :Export selected items to single RS5k instance on selected track NO GLUE'
-------------------------------------------------------------------------------   
function ExportSelItemsToRs5k(track)   
  local number_of_samples = reaper.CountSelectedMediaItems(0)
  
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

  -- Iterate through samples and add them to the same ReaSamplOmatic5000 instance
  for i = 1, number_of_samples do
    local item = reaper.GetSelectedMediaItem(0, i-1)
    local take = reaper.GetActiveTake(item)
    if not take or reaper.TakeIsMIDI(take) then goto skip_to_next_item end
    
    local tk_src = reaper.GetMediaItemTake_Source(take)
    local filename = reaper.GetMediaSourceFileName(tk_src, '')
    
    reaper.TrackFX_SetParam(track, midirand_pos, 1, number_of_samples) -- setting amount of samples in sampler in velocity Generator
    reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 3, 0) -- note range start
    reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 8, .17) -- max voices = 12
    reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 9, 0) -- attack
    reaper.TrackFX_SetParamNormalized(track, rs5k_pos, 11, 1) -- obey note offs
    reaper.TrackFX_SetNamedConfigParm(track, rs5k_pos, "FILE"..(i-1), filename)
    ::skip_to_next_item::
  end
  if rs5k_pos then reaper.TrackFX_SetNamedConfigParm(track, rs5k_pos, "DONE","") end
end

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
function main(track)
-- track check
local track = reaper.GetSelectedTrack(0,0)
if not track then return end

-- item check
local item = reaper.GetSelectedMediaItem(0,0)
if not item then return true end

-- export to RS5k
ExportSelItemsToRs5k(track)
MIDI_prepare(track)

end
function MIDI_prepare(tr)
local bits_set=tonumber('111111'..'00000',2)
reaper.SetMediaTrackInfo_Value( tr, 'I_RECINPUT', 4096+bits_set ) -- set input to all MIDI
reaper.SetMediaTrackInfo_Value( tr, 'I_RECMON', 1) -- monitor input
reaper.SetMediaTrackInfo_Value( tr, 'I_RECARM', 1) -- arm track
reaper.SetMediaTrackInfo_Value( tr, 'I_RECMODE',1) -- record STEREO out
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock(script_title, 1)

