-- grandMA2 3.9.x: controls for ColorSweep_Plugin20.lua.
-- These macros change show variables and call Plugin 20 on separate lines.
local PLUGIN_SLOT = 20
local TIMES = {0, 0.25, 0.5, 1, 2, 4}
local DIRECTIONS = {'L-R', 'R-L', 'OUT', 'IN'}
local RESERVED_FIRST, RESERVED_LAST = 130, 139

local function log(message)
  gma.feedback('[SweepMacros] '..tostring(message))
end

local function input(title, default)
  local ok, value = pcall(gma.textinput, title, default)
  if not ok or value == nil then return nil end
  return tostring(value):match('^%s*(.-)%s*$')
end

local function exists(path)
  local ok, handle = pcall(gma.show.getobj.handle, path)
  return ok and handle ~= nil and handle ~= false
end

local function confirm(title, message)
  if not (gma.gui and type(gma.gui.confirm) == 'function') then
    log('Confirm dialog unavailable; cancelled.')
    return false
  end
  local ok, answer = pcall(gma.gui.confirm, title, message)
  return ok and answer == true
end

local function number_text(value)
  return tostring(value)
end

local function create_macro(id, label, kind, value)
  local base = 'Macro 1.'..id
  if exists(base) then
    gma.cmd('Delete '..base..' /nc')
    if exists(base) then error('Cannot replace '..base..'; earlier changes may remain.') end
  end
  gma.cmd('Store '..base..' /o /nc')
  if not exists(base) then error('Cannot create '..base..'; earlier changes may remain.') end
  local lines = {
    'SetVar $CSWEEP_PACK_KIND = '..kind,
    'SetVar $CSWEEP_PACK_VALUE = '..value,
    'Plugin '..PLUGIN_SLOT,
  }
  for n, line in ipairs(lines) do
    gma.cmd('Store '..base..'.'..n..' /o /nc')
    gma.cmd('Assign '..base..'.'..n..' /cmd="'..line..'"')
    gma.cmd('Assign '..base..'.'..n..' /wait="Follow"')
  end
  gma.cmd('Label '..base..' "'..label..'"')
end

local function main()
  local raw = input('FIRST SWEEP CONTROL MACRO ID', '500')
  if not raw then log('Cancelled.'); return end
  local first = tonumber(raw)
  if not first or first < 1 or first ~= math.floor(first) then
    log('Enter a positive whole Macro ID. Nothing changed.'); return
  end
  local last = first + #TIMES * 2 + #DIRECTIONS - 1
  if last > 9999 then log('Macro range exceeds 9999. Nothing changed.'); return end
  if first <= RESERVED_LAST and last >= RESERVED_FIRST then
    log('Macro range overlaps Plugin 20 controls 130-139. Nothing changed.'); return
  end
  if first <= 103 and last >= 92 then
    log('Macro range overlaps ALL color macros 92-103. Nothing changed.'); return
  end
  local target_count=tonumber(gma.show.getvar('csweep-target-count')) or 0
  for target=1,target_count do
    local executor=tonumber(gma.show.getvar('csweep-target-'..target..'-executor'))
    local cues=tonumber(gma.show.getvar('csweep-target-'..target..'-cues')) or 12
    if executor and executor>=1 and cues>=1 then
      local color_first=14+(executor-1)*13
      local color_last=color_first+cues-1
      if first<=color_last and last>=color_first then
        log('Macro range overlaps configured color macros '..color_first..'-'..color_last..'. Nothing changed.');return
      end
    end
  end
  local occupied, snapshot = {}, {}
  for id=first,last do
    snapshot[id]=gma.show.getobj.handle('Macro 1.'..id) or false
    if snapshot[id] then occupied[#occupied+1]=tostring(id) end
  end
  local warning = #occupied > 0 and ('\nREPLACE ENTIRE EXISTING MACROS: '..table.concat(occupied, ', '))
    or '\nAll target macros are empty.'
  if not confirm('CREATE SWEEP CONTROLS', 'Create Macro 1.'..first..' through 1.'..last
    ..' for Plugin 20?'..warning..'\nOnly four horizontal directions are supported. Backup the show first.') then
    log('Cancelled. Nothing changed.'); return
  end
  for id=first,last do
    local current=gma.show.getobj.handle('Macro 1.'..id) or false
    if (not not current) ~= (not not snapshot[id]) then log('Macro Pool changed. Nothing created.');return end
    if current and gma.show.getobj.compare and not gma.show.getobj.compare(current,snapshot[id]) then
      log('Macro Pool changed. Nothing created.');return
    end
  end
  local id = first
  for _, value in ipairs(TIMES) do
    create_macro(id, 'Delay '..number_text(value)..'s', 1, value);id=id+1
  end
  for index, value in ipairs(TIMES) do
    create_macro(id, 'Sweep '..number_text(value)..'s', 2, index);id=id+1
  end
  for index, label in ipairs(DIRECTIONS) do
    create_macro(id, 'Direction '..label, 3, index);id=id+1
  end
  gma.show.setvar('CSWEEP_CONTROL_FIRST', tostring(first))
  gma.show.setvar('CSWEEP_CONTROL_LAST', tostring(last))
  log('Created Macro 1.'..first..' thru 1.'..last..'. Run Plugin 20 setup next.')
end

return main

