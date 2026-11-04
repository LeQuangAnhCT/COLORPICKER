-- grandMA2 Lua Plugin: Color Sweep System
-- Independent implementation: creates timing-only All Presets and control macros.
-- Load this plugin in a fixed Plugin Pool slot, then enter that slot during setup.

local TIMES = { 0, 0.25, 0.5, 1, 2, 4 }
local DIRECTIONS = {
  { key = "LR", label = "L-R", pattern = "up" },
  { key = "RL", label = "R-L", pattern = "down" },
  { key = "OUT", label = "OUT", pattern = "out" },
  { key = "IN", label = "IN", pattern = "in" },
}

local ALL_COLOR_MACRO_START = 92
local ALL_COLOR_CUES = 12
local ALL_COLOR_EXECUTORS = { 1, 2, 3, 4, 5, 6 }
local DEFAULT_PLUGIN_SLOT = 20
local DEFAULT_MACRO_START = 130
local DEFAULT_PRESET_START = 1

local function say(message)
  gma.feedback("[ColorSweep] " .. tostring(message))
end

local function trim(value)
  if value == nil then return "" end
  return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function input(title, default_value)
  local ok, value = pcall(gma.textinput, title, default_value or "")
  if ok then return trim(value) end
  return ""
end

local function confirm(title, message)
  if not (gma.gui and type(gma.gui.confirm) == 'function') then
    say('Confirm dialog unavailable; cancelled.')
    return false
  end
  local ok, approved = pcall(gma.gui.confirm, title, message)
  return ok and approved == true
end

local function var(key)
  return "csweep-" .. key
end

local function getvar(key, fallback)
  local value = trim(gma.show.getvar(var(key)))
  return value == "" and fallback or value
end

local function setvar(key, value)
  gma.show.setvar(var(key), tostring(value))
end

local function time_text(value)
  local text = string.format("%.2f", value)
  return text:gsub("0+$", ""):gsub("%.$", "")
end

local function preset_id(start, direction_index, time_index)
  return start + (direction_index - 1) * #TIMES + time_index - 1
end

local function macro_store(number, label, lines)
  if gma.show.getobj.handle('Macro 1.' .. number) then
    gma.cmd('Delete Macro 1.' .. number .. ' /nc')
    if gma.show.getobj.handle('Macro 1.' .. number) then
      error('Cannot replace Macro 1.' .. number .. '; earlier changes may remain.')
    end
  end
  gma.cmd("Store Macro 1." .. number .. " /o /nc")
  if not gma.show.getobj.handle('Macro 1.' .. number) then
    error('Cannot create Macro 1.' .. number .. '; earlier changes may remain.')
  end
  for line_number, command in ipairs(lines) do
    gma.cmd("Store Macro 1." .. number .. "." .. line_number .. " /o /nc")
    gma.cmd('Assign Macro 1.' .. number .. '.' .. line_number .. ' /cmd="' .. command .. '"')
    gma.cmd('Assign Macro 1.' .. number .. '.' .. line_number .. ' /wait="Follow"')
  end
  gma.cmd('Label Macro 1.' .. number .. ' "' .. label .. '"')
end

local function direction_command(pattern, time)
  if pattern == "up" then return "0 Thru " .. time_text(time) end
  if pattern == "down" then return time_text(time) .. " Thru 0" end
  if pattern == "out" then return time_text(time) .. " Thru 0 Thru " .. time_text(time) end
  return "0 Thru " .. time_text(time) .. " Thru 0"
end

local function direction_with_base(pattern, time, base)
  local low = time_text(base)
  local high = time_text(base + time)
  if pattern == 'up' then return low .. ' Thru ' .. high end
  if pattern == 'down' then return high .. ' Thru ' .. low end
  if pattern == 'out' then return high .. ' Thru ' .. low .. ' Thru ' .. high end
  return low .. ' Thru ' .. high .. ' Thru ' .. low
end

local function base_delay()
  local value = tonumber(trim(gma.show.getvar('CSWEEP_BASE_DELAY'))) or 0
  if value < 0 or value > 4 then return 0 end
  return value
end

local function target_count()
  return tonumber(getvar("target-count", "0")) or 0
end

local function run_color_cue(target_index, cue)
  local count = target_count()
  if target_index < 1 or target_index > count then
    say("Target mau khong hop le.")
    return
  end
  local page = tonumber(getvar("target-" .. target_index .. "-page", "99"))
  local executor = tonumber(getvar("target-" .. target_index .. "-executor", ""))
  local cues = tonumber(getvar("target-" .. target_index .. "-cues", "12")) or 12
  if not page or page<1 or page~=math.floor(page) or not executor or executor<1
    or executor~=math.floor(executor) or cue<1 or cue>cues then
    say("Chua co cau hinh Executor hoac Cue mau hop le.")
    return
  end
  gma.cmd('Goto Cue '..cue..' Executor '..page..'.'..executor..' /cue_mode=Assert')
end

local function create_timing_presets(preset_start, count)
  for direction_index, direction in ipairs(DIRECTIONS) do
    for time_index, time in ipairs(TIMES) do
      gma.cmd("ClearAll")
      for target = 1, count do
        local group = getvar("target-" .. target .. "-group", "")
        if group ~= "" then
          gma.cmd("Group " .. group)
          -- Use all preset types. Some Beam fixture libraries place Color1 timing
          -- outside the expected Color preset type, while RGB fixtures still work.
          gma.cmd("PresetType 0 At Delay " .. direction_command(direction.pattern, time))
        end
      end
      local id = preset_id(preset_start, direction_index, time_index)
      gma.cmd("Store Preset 0." .. id .. " /s /o /so=Prog /use=Active /v=false /vt=true /ef=false /nc")
      if not gma.show.getobj.handle('Preset 0.' .. id) then
        error('Cannot create Preset 0.' .. id .. '; check Group/attributes. Earlier changes may remain.')
      end
      gma.cmd('Label Preset 0.' .. id .. ' "Sweep ' .. time_text(time) .. 's ' .. direction.label .. '"')
    end
  end
  gma.cmd("ClearAll")
end

local function apply_current()
  if getvar('ready', 'NO') ~= 'YES' then say('Setup chua hoan tat. Khong thay doi Cue.'); return end
  local preset_start = tonumber(getvar("preset-start", tostring(DEFAULT_PRESET_START)))
  local direction_index = tonumber(getvar("direction", "1"))
  local time_index = tonumber(getvar("time", "1"))
  local count = target_count()
  if not preset_start or not direction_index or not time_index or count < 1
    or not DIRECTIONS[direction_index] or not TIMES[time_index] then
    say("Chua co cau hinh. Chay Setup truoc.")
    return
  end

  local delay_preset = preset_id(preset_start, direction_index, time_index)
  say("Dang ap Preset 0." .. delay_preset .. " cho " .. count .. " loai den.")

  -- Load each cue before storing its timing. This guarantees a 0 second sweep
  -- actively replaces any older individual delay instead of leaving it tracked.
  for target = 1, count do
    local group = getvar("target-" .. target .. "-group", "")
    local page = getvar("target-" .. target .. "-page", "99")
    local executor = getvar("target-" .. target .. "-executor", "")
    local cues = tonumber(getvar("target-" .. target .. "-cues", "12")) or 12
    if group ~= "" and executor ~= "" then
      gma.cmd("Select Executor " .. page .. "." .. executor)
      -- Color-wheel fixtures must snap to the target slot. The sweep comes from
      -- individual delay; fading Color1 would visibly pass through other colors.
      gma.cmd("Assign Fade 0 Cue 1 Thru " .. cues)
      for cue = 1, cues do
        gma.cmd("ClearAll")
        gma.cmd("Select Executor " .. page .. "." .. executor)
        gma.cmd("Group " .. group .. " At Cue " .. cue)
        local base = base_delay()
        if base > 0 then
          gma.cmd('PresetType 0 At Delay '..direction_with_base(DIRECTIONS[direction_index].pattern, TIMES[time_index], base))
        elseif time_index == 1 then
          gma.cmd("PresetType 0 At Delay 0")
        else
          gma.cmd("Call Preset 0." .. delay_preset)
        end
        -- Cue Only keeps this cue's individual delay independent of tracking,
        -- so Goto to a lower cue uses the same sweep direction as Goto forward.
        gma.cmd("Store Cue " .. cue
          .. " /ka=true /m /s /so=Prog /use=Active /cueonly=true /nc")
      end
      say("Da cap nhat Executor " .. page .. "." .. executor)
    end
  end
  gma.cmd("ClearAll")
  say("Xong. Macro mau chi dung: Goto Executor ... Cue ...")
end

local function create_control_macros(plugin_slot, macro_start)
  local macro = macro_start
  for time_index, time in ipairs(TIMES) do
    macro_store(macro, "Sweep " .. time_text(time) .. "s", {
      "SetVar $CSWEEP_PACK_KIND = 2",
      "SetVar $CSWEEP_PACK_VALUE = " .. time_index,
      "Plugin " .. plugin_slot,
    })
    macro = macro + 1
  end
  for direction_index, direction in ipairs(DIRECTIONS) do
    macro_store(macro, "Direction " .. direction.label, {
      "SetVar $CSWEEP_PACK_KIND = 3",
      "SetVar $CSWEEP_PACK_VALUE = " .. direction_index,
      "Plugin " .. plugin_slot,
    })
    macro = macro + 1
  end
  return macro - 1
end

local function finish_setup(plugin_slot, macro_start, preset_start, count)
  say("Dang tao 24 Delay Preset trong Preset 0.")
  create_timing_presets(preset_start, count)
  local macro_finish = create_control_macros(plugin_slot, macro_start)
  setvar("time", "1")
  setvar("direction", "1")
  setvar("ready", "YES")
  say("Xong. Macro " .. macro_start .. " Thru " .. macro_finish .. " da duoc tao.")
  say("Chinh Macro mau: bo 'Fade ...', chi giu Goto Executor ... Cue ...")
end

local function patch_color_macros()
  local count = target_count()
  if count < 1 then
    say("Chua co cau hinh. Chay Setup truoc.")
    return
  end

  local changed = 0
  for target = 1, count do
    local page = getvar("target-" .. target .. "-page", "99")
    local executor = tonumber(getvar("target-" .. target .. "-executor", ""))
    local cues = tonumber(getvar("target-" .. target .. "-cues", "12")) or 12
    if executor then
      -- Existing picker uses 12 color macros plus one row-header macro per fixture type:
      -- Executor 99.1 -> Macro 14..25, 99.2 -> 27..38, and so on.
      local first_macro = 14 + (executor - 1) * 13
      for cue = 1, cues do
        local macro_number = first_macro + cue - 1
        local macro_handle = gma.show.getobj.handle("Macro 1." .. macro_number)
        if macro_handle then
          gma.cmd("Store Macro 1." .. macro_number .. ".1 /o /nc")
          gma.cmd('Assign Macro 1.' .. macro_number .. '.1 /cmd="Goto Cue '
            .. cue .. " Executor " .. page .. "." .. executor .. ' /cue_mode=Assert"')
          changed = changed + 1
        else
          say("Bo qua Macro " .. macro_number .. ": khong ton tai.")
        end
      end
    end
  end
  say("Da sua " .. changed .. " Macro mau sang Goto Assert.")
end

local function patch_all_color_macros()
  local changed = 0

  for cue = 1, ALL_COLOR_CUES do
    local macro_number = ALL_COLOR_MACRO_START + cue - 1
    local macro_handle = gma.show.getobj.handle("Macro 1." .. macro_number)
    if macro_handle then
      local commands = {}
      for _, executor in ipairs(ALL_COLOR_EXECUTORS) do
        commands[#commands + 1] = "Goto Cue " .. cue
          .. " Executor 99." .. executor .. " /cue_mode=Assert"
      end

      -- Only replace line 1. Existing Copy Image/appearance lines stay intact.
      gma.cmd("Store Macro 1." .. macro_number .. ".1 /o /nc")
      gma.cmd('Assign Macro 1.' .. macro_number .. '.1 /cmd="'
        .. table.concat(commands, " ; ") .. '"')
      changed = changed + 1
    else
      say("Bo qua Macro ALL " .. macro_number .. ": khong ton tai.")
    end
  end

  say("Da sua " .. changed .. " Macro ALL.")
  say("Moi Macro ALL se goi cung Cue tren Executor 99.1 Thru 99.6.")
end

local function patch_beam_color_macros()
  local target_index = 1
  local count = target_count()
  if count < target_index then
    say("Chua co Target 1. Chay Setup truoc.")
    return
  end

  local page = tonumber(getvar("target-" .. target_index .. "-page", "99"))
  local executor = tonumber(getvar("target-" .. target_index .. "-executor", ""))
  local cues = tonumber(getvar("target-" .. target_index .. "-cues", "12")) or 12
  if not page or page<1 or page~=math.floor(page) or not executor or executor<1
    or executor~=math.floor(executor) or cues<1 or cues~=math.floor(cues) then
    say("Target 1 chua co Executor hoac Cue mau hop le.")
    return
  end
  local first_macro = 14 + (executor - 1) * 13
  local last_macro = first_macro + cues - 1
  local pack_first = tonumber(trim(gma.show.getvar('CSWEEP_CONTROL_FIRST')))
  local pack_last = tonumber(trim(gma.show.getvar('CSWEEP_CONTROL_LAST')))
  if (first_macro<=139 and last_macro>=130) or (first_macro<=103 and last_macro>=92)
    or (pack_first and pack_last and first_macro<=pack_last and last_macro>=pack_first) then
    say('Beam color Macro range overlaps Sweep or ALL controls. Nothing changed.');return
  end
  local selected={}
  for cue = 1, cues do
    local macro_number = first_macro + cue - 1
    local macro_handle = gma.show.getobj.handle("Macro 1." .. macro_number)
    if macro_handle then
      selected[#selected+1]={number=macro_number,cue=cue,handle=macro_handle}
    else
      say("Bo qua Macro Beam " .. macro_number .. ": khong ton tai.")
    end
  end
  if #selected==0 then say('Khong tim thay Macro mau Beam.');return end
  local ids={};for _,item in ipairs(selected) do ids[#ids+1]=tostring(item.number) end
  if not confirm('BEAM COLOR DIRECT','Replace only line 1 of Macro '..table.concat(ids,', ')..' with Goto cues on Executor '..page..'.'..executor..'?\nOther macro lines are kept. No Dimmer Dip. Backup the show first.') then return end
  for _,item in ipairs(selected) do
    local current=gma.show.getobj.handle('Macro 1.'..item.number)
    if not current or (gma.show.getobj.compare and not gma.show.getobj.compare(current,item.handle)) then
      say('Macro Pool changed after confirmation. Nothing changed.');return
    end
  end
  for _,item in ipairs(selected) do
    local line='Macro 1.'..item.number..'.1'
    gma.cmd('Store '..line..' /o /nc')
    gma.cmd('Assign '..line..' /cmd="Goto Cue '..item.cue..' Executor '..page..'.'..executor..' /cue_mode=Assert"')
  end
  say('Da sua '..#selected..' Macro mau Beam: goi Cue truc tiep, khong ha Dimmer.')
end

local function rebuild_after_fixture_change()
  local preset_start = tonumber(getvar("preset-start", tostring(DEFAULT_PRESET_START)))
  local count = target_count()
  if not preset_start or count < 1 then
    say("Chua co cau hinh. Chay Setup truoc.")
    return
  end

  say("Dang tao lai Delay Preset theo Group hien tai.")
  create_timing_presets(preset_start, count)
  apply_current()
  say("Da lam moi Sweep sau khi them/xoa Fixture.")
end

local function setup()
  local plugin_slot = DEFAULT_PLUGIN_SLOT
  local macro_start = DEFAULT_MACRO_START
  local preset_start = DEFAULT_PRESET_START
  local count = tonumber(input("So loai den can ap dung (Beam/Spot/LED...)", getvar("target-count", "1")))
  if not count or count < 1 or count > 12 then
    say("Du lieu Setup khong hop le.")
    return
  end
  count = math.floor(count)

  local targets = {}
  for target = 1, count do
    local label = input("Ten loai den " .. target, getvar("target-" .. target .. "-label", "Beam"))
    local default_group = target == 1 and "10" or tostring(target)
    local group = input("Group ID " .. label, getvar("target-" .. target .. "-group", default_group))
    local executor = input("Executor mau " .. label .. " (Page 99)", getvar("target-" .. target .. "-executor", tostring(target)))
    local cues = input("So Cue mau " .. label, getvar("target-" .. target .. "-cues", "12"))
    local group_number, executor_number, cue_count = tonumber(group), tonumber(executor), tonumber(cues)
    if not group_number or group_number < 1 or group_number ~= math.floor(group_number)
      or not executor_number or executor_number < 1 or executor_number ~= math.floor(executor_number)
      or not cue_count or cue_count < 1 or cue_count ~= math.floor(cue_count) then
      say('Group, Executor and Cue count must be positive integers. Setup stopped.')
      return
    end
    group, executor, cues = tostring(group_number), tostring(executor_number), tostring(cue_count)
    local color_first=14+(executor_number-1)*13
    local color_last=color_first+cue_count-1
    local pack_first=tonumber(trim(gma.show.getvar('CSWEEP_CONTROL_FIRST')))
    local pack_last=tonumber(trim(gma.show.getvar('CSWEEP_CONTROL_LAST')))
    if color_first<=139 and color_last>=130 then
      say('Color Macro range '..color_first..'-'..color_last..' overlaps Plugin 20 Macro 130-139. Setup stopped.')
      return
    end
    if pack_first and pack_last and color_first<=pack_last and color_last>=pack_first then
      say('Color Macro range '..color_first..'-'..color_last..' overlaps Sweep Controls '..pack_first..'-'..pack_last..'. Setup stopped.')
      return
    end
    local group_handle = gma.show.getobj.handle("Group " .. group)
    if not group_handle then
      say("Khong tim thay Group " .. group .. ". Setup da dung.")
      return
    end
    local group_name = gma.show.getobj.label(group_handle) or ("Group " .. group)
    say("Target " .. target .. ": Group " .. group .. " [" .. group_name
      .. "] -> Executor 99." .. executor .. ", " .. cues .. " Cue.")
    targets[target] = {label=label, group=group, executor=executor, cues=cues}
  end

  local occupied, snapshot = {}, {}
  for id = macro_start, macro_start + #TIMES + #DIRECTIONS - 1 do
    local path='Macro 1.' .. id
    snapshot[path]=gma.show.getobj.handle(path) or false
    if snapshot[path] then occupied[#occupied + 1] = path end
  end
  for id = preset_start, preset_start + #TIMES * #DIRECTIONS - 1 do
    local path='Preset 0.' .. id
    snapshot[path]=gma.show.getobj.handle(path) or false
    if snapshot[path] then occupied[#occupied + 1] = path end
  end
  if not (gma.gui and type(gma.gui.confirm) == 'function') then
    say('Confirm dialog unavailable. No Macro or Preset created.'); return
  end
  local warning = #occupied > 0 and ('\nExisting Macros will be replaced and Presets overwritten: '..table.concat(occupied, ', '))
    or '\nAll target Macro and Preset slots are empty.'
  local ok, approved = pcall(gma.gui.confirm, 'COLOR SWEEP SETUP',
    'Create Macro 130-139 and Preset 0.1-0.24?'..warning
    ..'\nProgrammer will be cleared. Control macros later edit configured Page 99 cues and set Cue Fade to 0. Back up the show first.')
  if not ok or approved ~= true then say('Setup cancelled. No Macro or Preset created.'); return end
  for path, previous in pairs(snapshot) do
    local current=gma.show.getobj.handle(path) or false
    if (not not current) ~= (not not previous) then
      say('Macro or Preset Pool changed during confirmation. Nothing created.'); return
    end
    if current and gma.show.getobj.compare and not gma.show.getobj.compare(current, previous) then
      say('Macro or Preset Pool changed during confirmation. Nothing created.'); return
    end
  end
  setvar('ready', 'NO')
  setvar('plugin-slot', plugin_slot);setvar('macro-start', macro_start)
  setvar('preset-start', preset_start);setvar('target-count', count)
  for target, item in ipairs(targets) do
    setvar('target-'..target..'-label', item.label)
    setvar('target-'..target..'-group', item.group)
    setvar('target-'..target..'-page', '99')
    setvar('target-'..target..'-executor', item.executor)
    setvar('target-'..target..'-cues', item.cues)
  end
  say("Dung Plugin 20, Macro 130 Thru 139 va Preset 0.1 Thru 0.24.")
  finish_setup(plugin_slot, macro_start, preset_start, count)
end

local function create_sweep_controls()
  local raw=input('FIRST SWEEP CONTROL MACRO ID','500')
  if raw=='' then say('Cancelled.');return end
  local first=tonumber(raw)
  if not first or first<1 or first~=math.floor(first) then say('Enter a positive whole Macro ID. Nothing changed.');return end
  local last=first+#TIMES*2+#DIRECTIONS-1
  if last>9999 then say('Macro range exceeds 9999. Nothing changed.');return end
  if (first<=139 and last>=130) or (first<=103 and last>=92) then
    say('Macro range overlaps Plugin 20 or ALL color macros. Nothing changed.');return
  end
  for target=1,target_count() do
    local executor=tonumber(getvar('target-'..target..'-executor',''))
    local cues=tonumber(getvar('target-'..target..'-cues','12')) or 12
    if executor and executor>=1 and cues>=1 then
      local color_first=14+(executor-1)*13
      local color_last=color_first+cues-1
      if first<=color_last and last>=color_first then
        say('Macro range overlaps configured color macros '..color_first..'-'..color_last..'. Nothing changed.');return
      end
    end
  end
  local occupied,snapshot={},{}
  for id=first,last do
    snapshot[id]=gma.show.getobj.handle('Macro 1.'..id) or false
    if snapshot[id] then occupied[#occupied+1]=tostring(id) end
  end
  local warning=#occupied>0 and ('\nREPLACE ENTIRE EXISTING MACROS: '..table.concat(occupied,', ')) or '\nAll target macros are empty.'
  if not confirm('CREATE SWEEP CONTROLS','Create Macro 1.'..first..' through 1.'..last..' for Plugin 20?'..warning..'\nBackup the show first.') then
    say('Cancelled. Nothing changed.');return
  end
  for id=first,last do
    local current=gma.show.getobj.handle('Macro 1.'..id) or false
    if (not not current)~=(not not snapshot[id]) then say('Macro Pool changed. Nothing created.');return end
    if current and gma.show.getobj.compare and not gma.show.getobj.compare(current,snapshot[id]) then
      say('Macro Pool changed. Nothing created.');return
    end
  end
  local id=first
  for _,value in ipairs(TIMES) do
    macro_store(id,'Delay '..time_text(value)..'s',{'SetVar $CSWEEP_PACK_KIND = 1','SetVar $CSWEEP_PACK_VALUE = '..value,'Plugin '..DEFAULT_PLUGIN_SLOT})
    id=id+1
  end
  for index,value in ipairs(TIMES) do
    macro_store(id,'Sweep '..time_text(value)..'s',{'SetVar $CSWEEP_PACK_KIND = 2','SetVar $CSWEEP_PACK_VALUE = '..index,'Plugin '..DEFAULT_PLUGIN_SLOT})
    id=id+1
  end
  for index,direction in ipairs(DIRECTIONS) do
    macro_store(id,'Direction '..direction.label,{'SetVar $CSWEEP_PACK_KIND = 3','SetVar $CSWEEP_PACK_VALUE = '..index,'Plugin '..DEFAULT_PLUGIN_SLOT})
    id=id+1
  end
  gma.show.setvar('CSWEEP_CONTROL_FIRST',tostring(first))
  gma.show.setvar('CSWEEP_CONTROL_LAST',tostring(last))
  say('Created Macro 1.'..first..' thru 1.'..last..'. Run Setup before using controls.')
end

local MENU_NAME = 'CSWEEP CONTROL MENU'
local MENU_VERSION = '3'
local MENU_OPTIONS = {
  {label='01 CREATE DELAY AND SWEEP MACROS', action=7},
  {label='02 SETUP GROUPS AND SWEEP', action=1},
  {label='03 PATCH ALL COLOR MACROS', action=4},
  {label='04 REBUILD AFTER FIXTURE CHANGE', action=5},
  {label='05 BEAM COLORS DIRECT - NO DIMMER DIP', action=6},
}

local function exists(path)
  local ok, handle = pcall(gma.show.getobj.handle, path)
  return ok and handle ~= nil and handle ~= false
end

local function menu_owned(address)
  local handle = gma.show.getobj.handle('Executor '..address)
  if not handle then return false end
  local ok, label = pcall(gma.show.getobj.label, handle)
  return ok and tostring(label or '') == MENU_NAME
end

local function open_menu()
  local previous = getvar('menu-executor', '')
  if previous ~= '' then
    if not previous:match('^1%.%d+$') or not menu_owned(previous) then
      say('Saved menu Executor '..previous..' is missing or no longer belongs to this plugin. Nothing changed.')
      return false
    end
    if getvar('menu-version','')==MENU_VERSION then
      gma.cmd('Goto Executor '..previous)
      return true
    end
  end
  local address = ''
  if not exists('Page 1') then say('Page 1 missing. No menu created.');return false end
  for number=201,240 do
    local candidate='1.'..number
    if not exists('Executor '..candidate) then address=candidate;break end
  end
  if address == '' then say('No free menu Executor on Page 1.201-240. Nothing created.');return false end
  local old_notice=previous~='' and ('\nThe previous menu at '..previous..' is retained and will not be deleted.') or ''
  if not confirm('CREATE SWEEP MENU','Create the Color Sweep menu at empty Executor '..address..' on Page 1?'..old_notice..'\nThe Programmer will be cleared and BlindEdit will be switched off after installation. No existing Executor will be overwritten. Backup the show first.') then
    say('Menu creation cancelled.');return false
  end
  if exists('Executor '..address) then say('Menu Executor became occupied. Nothing created.');return false end
  gma.cmd('BlindEdit On')
  gma.cmd('ClearAll')
  local ok, err = pcall(function()
    for cue, item in ipairs(MENU_OPTIONS) do
      gma.cmd('Store Cue '..cue..' Executor '..address..' /nc')
      if not exists('Cue '..cue..' Executor '..address) then
        error('Could not create menu cue '..cue..'.')
      end
      gma.cmd('Label Cue '..cue..' Executor '..address..' "'..item.label..'"')
      gma.cmd('Assign Cue '..cue..' Executor '..address..' /cmd="SetVar $CSWEEP_MENU_ACTION = '..item.action..' ; Plugin '..DEFAULT_PLUGIN_SLOT..'"')
    end
    gma.cmd('Label Executor '..address..' "'..MENU_NAME..'"')
    gma.cmd('Assign Goto At ExecButton1 '..address)
    gma.cmd('Assign Executor '..address..' /Wrap=Off /Restart=First /Chaser=Off /cmddisable=off /nc')
  end)
  gma.cmd('ClearAll')
  gma.cmd('BlindEdit Off')
  if not ok then
    say('Menu creation stopped: '..tostring(err)..' Partial menu may remain at '..address..'. No automatic deletion.')
    return false
  end
  setvar('menu-executor', address)
  setvar('menu-version', MENU_VERSION)
  say('Menu created at Executor '..address..'.')
  gma.cmd('Goto Executor '..address)
  return true
end

local function run_menu_action(action)
  if action == 7 then create_sweep_controls()
  elseif action == 1 then setup()
  elseif action == 4 then
    if confirm('PATCH ALL COLOR MACROS','Replace line 1 in existing Macro 92-103? Backup the show first.') then patch_all_color_macros() end
  elseif action == 5 then
    if confirm('REBUILD SWEEP','Overwrite the configured 24 All Presets, clear the Programmer and update all configured color Cues? Backup the show first.') then rebuild_after_fixture_change() end
  elseif action == 6 then
    patch_beam_color_macros()
  else say('Lua chon khong hop le.') end
end

local function main()
  local pack_kind = tonumber(trim(gma.show.getvar('CSWEEP_PACK_KIND')))
  local pack_value = tonumber(trim(gma.show.getvar('CSWEEP_PACK_VALUE')))
  if pack_kind then
    gma.show.setvar('CSWEEP_PACK_KIND', '')
    gma.show.setvar('CSWEEP_PACK_VALUE', '')
    if getvar('ready', 'NO') ~= 'YES' then say('Chay Plugin 20 Setup truoc khi bam Macro dieu khien.'); return end
    if not pack_value then say('Gia tri Macro khong hop le.'); return end
    if pack_kind == 1 then
      local allowed = false
      for _, value in ipairs(TIMES) do if value == pack_value then allowed = true end end
      if not allowed then say('Delay khong hop le.'); return end
      gma.show.setvar('CSWEEP_BASE_DELAY', tostring(pack_value))
    elseif pack_kind == 2 and pack_value == math.floor(pack_value) and TIMES[pack_value] then
      setvar('time', pack_value)
    elseif pack_kind == 3 and pack_value == math.floor(pack_value) and DIRECTIONS[pack_value] then
      setvar('direction', pack_value)
    else
      say('Macro Sweep khong hop le.'); return
    end
    apply_current()
    return
  end
  local color_target=tonumber(trim(gma.show.getvar('CSWEEP_COLOR_TARGET')))
  local color_cue=tonumber(trim(gma.show.getvar('CSWEEP_COLOR_CUE')))
  if color_target or color_cue then
    gma.show.setvar('CSWEEP_COLOR_TARGET','')
    gma.show.setvar('CSWEEP_COLOR_CUE','')
    if not color_target or not color_cue then say('Thieu Target hoac Cue mau.');return end
    run_color_cue(math.floor(color_target),math.floor(color_cue))
    return
  end
  local run = trim(gma.show.getvar("CSWEEP_RUN"))
  if run == "COLOR" then
    local target_index = tonumber(trim(gma.show.getvar("CSWEEP_TARGET")))
    local cue = tonumber(trim(gma.show.getvar("CSWEEP_CUE")))
    gma.show.setvar("CSWEEP_RUN", "")
    gma.show.setvar("CSWEEP_TARGET", "")
    gma.show.setvar("CSWEEP_CUE", "")
    if not target_index or not cue then
      say("Thieu Target hoac Cue mau.")
      return
    end
    run_color_cue(math.floor(target_index), math.floor(cue))
    return
  end

  if run == "APPLY" then
    local selected_time = trim(gma.show.getvar("CSWEEP_TIME_INDEX"))
    local selected_direction = trim(gma.show.getvar("CSWEEP_DIRECTION_INDEX"))
    if selected_time ~= "" then setvar("time", selected_time) end
    if selected_direction ~= "" then setvar("direction", selected_direction) end
    gma.show.setvar("CSWEEP_RUN", "")
    gma.show.setvar("CSWEEP_TIME_INDEX", "")
    gma.show.setvar("CSWEEP_DIRECTION_INDEX", "")
    apply_current()
    return
  end

  local action = tonumber(trim(gma.show.getvar('CSWEEP_MENU_ACTION')))
  if action then
    gma.show.setvar('CSWEEP_MENU_ACTION','')
    local ok, err = pcall(run_menu_action, action)
    if not ok then say('Menu action failed: '..tostring(err)..'. Partial changes may remain.') end
  end
  open_menu()
end

return main


