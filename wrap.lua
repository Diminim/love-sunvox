local ffi = require("ffi")

-- add library to path
-- add library to save directory
-- load library

local library_path = assert(package.searchpath("sunvox", package.cpath))
local C = ffi.load(library_path)

local path = (...):gsub("wrap", "")
local Object = require(path .. "object")


local Sunvox = Object:extend()
local Slot = Object:extend()
local Module = Object:extend()
local Pattern = Object:extend()

-- TODO: Have the sunvox object contain all the sub-objects?
-- TODO: Have the sunvox object have all the methods so you can use it instead if you want?
-- TODO: error wrapping?

function Sunvox:__new(config, sample_rate, channels, flags)
   self.slots = {}
   -- TODO: make a table for flags and convert it with bor
   C.sv_init(config, sample_rate, channels, flags)
end

function Sunvox:open_slot(int)
   C.sv_open_slot(int)
   return Slot(int)
end

function Sunvox:close_slot(int)
   C.sv_close_slot(int)
   local slot = self.ids_to_slots[id]
   self.slots_to_ids[slot] = nil
   self.ids_to_slots[id] = nil

   return C.sv_close_slot(slot)
end

function Sunvox:get_sample_rate()
   return C.sv_get_sample_rate()
end

function Slot:__new(id)
   self.id = id
end

function Slot:lock()
   C.sv_lock_slot(self.id)
end

function Slot:unlock()
   C.sv_unlock_slot(self.id)
end

function Slot:play(t)
   if t then
      C.sv_rewind(self.id, t)
   end
   C.sv_play(self.id)
end

function Slot:pause(t)
   if t then
      C.sv_rewind(self.id, t)
   end
   C.sv_stop(self.id)
end

function Slot:stop()
   C.sv_rewind(self.id, 0)
   C.sv_stop(self.id)
end

function Slot:seek(t)
   C.sv_rewind(self.id, t)
end

function Slot:tell()
   return C.sv_get_current_line(self.id)
end

function Slot:status()
   local status = C.sv_end_of_song(self.id)

   if status == 0 then
      return "play"
   else
      return "pause"
   end
end

-- function Slot:set_looping(bool)
--    C.sv_set_autostop(self.id, bool and 1 or 0)
-- end
-- function Slot:get_looping()
--    return C.sv_get_autostop(self.id) == 0 and true or false
-- end

function Slot:load(filename)
   return C.sv_load(self.id, filename)
end

function Slot:get_module(name)
   local module_id = C.sv_find_module(self.id, name)
   if module_id == -1 then
      error("no module by that name")
   end

   return Module(self.id, module_id)
end

function Module:__new(slot, id)
   self.slot = slot
   self.id = id

   self.controls = self:get_controls()
end

function Module:get_controls()
   local controls = {}
   local num_of_ctrls = C.sv_get_number_of_module_ctls(self.slot, self.id)

   for i = 0, num_of_ctrls-1 do
      local name = ffi.string(C.sv_get_module_ctl_name(self.slot, self.id, i))
      controls[name] = i
   end

   return controls
end

function Module:set_control(name, v)
   local control_id = self.controls[name]

   local min = C.sv_get_module_ctl_min(self.slot, self.id, control_id, 2)
   local max = C.sv_get_module_ctl_max(self.slot, self.id, control_id, 2)
   if min > v or v > max then
      error(string.format("Out of range value, got %d, expected %d-%d", v, min, max))
   end
   C.sv_set_module_ctl_value(self.slot, self.id, control_id, v, 2)

end

function Module:get_control(name)
   local control_id = self.controls[name]

   return C.sv_get_module_ctl_value(self.slot, self.id, control_id, 2)
end

function Module:shift_control(name, v)
   self:set_control(name, self:get_control(name) + v)
end

function Module:send_event(event)
   local mode = 1 -- 1 = set timestep, 0 = automatic
   local timestep = 0 -- 0 = instant, 0< = timestep + latency*2
   C.sv_set_event_t(self.slot, mode, timestep)

   local track = event.track or 0
   local note = event.note or 0
   local vel = event.vel or 0
   local ctl = event.ctl or 0
   local ctl_val = event.ctl_val or 0

   C.sv_send_event(self.slot, track, note, vel, self.id+1, ctl, ctl_val)
end


return Sunvox