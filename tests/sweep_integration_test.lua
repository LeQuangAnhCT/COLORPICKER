local commands, variables, handles, labels = {}, {}, {}, {}
local response, approved = '500', true
local prompts = {}
local last_confirmation = ''
local confirmation_hook
gma = {
  cmd = function(command)
    commands[#commands+1]=command
    local macro=command:match('^Delete Macro 1%.(%d+) /nc$')
    if macro then handles['Macro 1.'..macro]=nil end
    local created_macro=command:match('^Store Macro 1%.(%d+) /o /nc$')
    if created_macro then handles['Macro 1.'..created_macro]='created' end
    local preset=command:match('^Store Preset 0%.(%d+) ')
    if preset then handles['Preset 0.'..preset]='created' end
    local cue,address=command:match('^Store Cue (%d+) Executor ([%d%.]+) /nc$')
    if cue then handles['Executor '..address]='created';handles['Cue '..cue..' Executor '..address]='created' end
    local label_address,label=command:match('^Label Executor ([%d%.]+) "(.-)"$')
    if label_address then labels['Executor '..label_address]=label end
  end,
  feedback = function() end,
  textinput = function() return table.remove(prompts,1) or response end,
  gui = {confirm = function(_,message)
    last_confirmation=message
    if confirmation_hook then confirmation_hook() end
    return approved
  end},
  show = {
    getvar = function(name) return variables[name] end,
    setvar = function(name,value) variables[name]=tostring(value) end,
    getobj = {
      handle = function(path) if handles[path] then return path end end,
      label = function(handle) return labels[handle] or 'Test Group' end,
    },
  },
  sleep = function() end,
}
local function contains(value)
  for _,command in ipairs(commands) do if command == value then return true end end
  return false
end
local pack = dofile('Sweep_Control_Macro_Pack.lua')
pack()
assert(contains('Store Macro 1.500 /o /nc'))
assert(contains('Store Macro 1.515 /o /nc'))
assert(not contains('Store Macro 1.139 /o /nc'))
assert(contains('Assign Macro 1.500.1 /cmd="SetVar $CSWEEP_PACK_KIND = 1"'))
assert(contains('Assign Macro 1.500.2 /wait="Follow"'))
assert(contains('Assign Macro 1.500.3 /cmd="Plugin 20"'))
assert(contains('Assign Macro 1.515.2 /cmd="SetVar $CSWEEP_PACK_VALUE = 4"'))
assert(variables.CSWEEP_CONTROL_FIRST=='500' and variables.CSWEEP_CONTROL_LAST=='515')
commands={};response='125'
pack()
assert(#commands==0,'overlap with Macro 130-139 must be rejected')
commands={};response='90'
pack()
assert(#commands==0,'overlap with ALL color Macro 92-103 must be rejected')
commands={};response='500';handles['Macro 1.500']='existing';approved=false
pack()
assert(#commands==0 and last_confirmation:find('500',1,true),'cancel must not overwrite existing macros')
commands={};approved=true
pack()
assert(contains('Delete Macro 1.500 /nc') and contains('Store Macro 1.500 /o /nc'),
  'approved overwrite must replace the entire old macro')
commands={};response='600';confirmation_hook=function() handles['Macro 1.600']='new' end
pack()
assert(#commands==0,'a new collision during confirmation must prevent writes')
confirmation_hook=nil

local sweep = dofile('ColorSweep_Plugin20.lua')
handles={}
commands={}
variables.CSWEEP_PACK_KIND='1';variables.CSWEEP_PACK_VALUE='1'
sweep()
assert(#commands==0,'control must not change cues before Plugin 20 setup')
variables['csweep-ready']='YES';variables['csweep-target-count']='1'
variables['csweep-target-1-group']='10';variables['csweep-target-1-page']='99'
variables['csweep-target-1-executor']='1';variables['csweep-target-1-cues']='1'
variables['csweep-preset-start']='1';variables['csweep-time']='1';variables['csweep-direction']='1'
variables.CSWEEP_PACK_KIND='1';variables.CSWEEP_PACK_VALUE='1'
sweep()
assert(variables.CSWEEP_BASE_DELAY=='1')
assert(contains('PresetType 0 At Delay 1 Thru 1'),'base delay must be applied')
commands={};variables.CSWEEP_PACK_KIND='2';variables.CSWEEP_PACK_VALUE='4'
sweep()
assert(variables['csweep-time']=='4')
assert(contains('PresetType 0 At Delay 1 Thru 2'),'time must add to base delay')
commands={};variables.CSWEEP_PACK_KIND='3';variables.CSWEEP_PACK_VALUE='3'
sweep()
assert(contains('PresetType 0 At Delay 2 Thru 1 Thru 2'),'center-out must preserve base delay')

commands={};handles['Group 10']='group';handles['Preset 0.3']='occupied'
variables['csweep-target-1-group']='99'
approved=false;variables.CSWEEP_MENU_ACTION='1';prompts={'1','Beam','10','1','1'}
sweep()
assert(#commands==0,'declining setup must not overwrite presets or macros')
assert(variables['csweep-target-1-group']=='99','declining setup must not change stored configuration')
assert(last_confirmation:find('Preset 0.3',1,true),'occupied preset must be shown')
commands={};approved=true;variables.CSWEEP_MENU_ACTION='1';prompts={'1','Beam','10','1','1'}
sweep()
assert(variables['csweep-ready']=='YES' and variables['csweep-target-1-group']=='10')
assert(contains('Store Macro 1.130 /o /nc') and contains('Store Macro 1.139 /o /nc'))
assert(contains('Store Preset 0.24 /s /o /so=Prog /use=Active /v=false /vt=true /ef=false /nc'))
assert(contains('Assign Macro 1.130.1 /cmd="SetVar $CSWEEP_PACK_KIND = 2"'))
commands={};variables.CSWEEP_MENU_ACTION='1';prompts={'1','Beam','10','10','12'}
sweep()
assert(#commands==0,'setup must reject color macros overlapping Plugin 20 controls')
assert(variables['csweep-target-1-executor']=='1','rejected setup must preserve earlier configuration')
commands={};handles['Macro 1.14']='color';variables.CSWEEP_MENU_ACTION='6'
sweep()
assert(contains('Assign Macro 1.14.1 /cmd="SetVar $CSWEEP_COLOR_TARGET = 1 ; SetVar $CSWEEP_COLOR_CUE = 1 ; Plugin 20"'),
  'Dimmer Dip macro must use numeric global variables')
commands={};handles={['Page 1']='page',['Executor 1.201']='occupied'};labels={['Executor 1.201']='OTHER'}
approved=false;sweep()
assert(#commands==0,'declining menu creation must not change the show')
approved=true;sweep()
assert(variables['csweep-menu-executor']=='1.202','menu must use a free Executor')
assert(contains('Store Cue 1 Executor 1.202 /nc'))
assert(contains('Assign Cue 1 Executor 1.202 /cmd="SetVar $CSWEEP_MENU_ACTION = 7 ; Plugin 20"'))
assert(contains('Assign Cue 2 Executor 1.202 /cmd="SetVar $CSWEEP_MENU_ACTION = 1 ; Plugin 20"'))
assert(contains('Assign Cue 3 Executor 1.202 /cmd="SetVar $CSWEEP_MENU_ACTION = 4 ; Plugin 20"'))
assert(contains('Assign Cue 4 Executor 1.202 /cmd="SetVar $CSWEEP_MENU_ACTION = 5 ; Plugin 20"'))
assert(contains('Assign Cue 5 Executor 1.202 /cmd="SetVar $CSWEEP_MENU_ACTION = 6 ; Plugin 20"'))
assert(not contains('Store Cue 6 Executor 1.202 /nc'),'removed menu options must not be recreated')
assert(contains('Goto Executor 1.202'))
commands={};sweep()
assert(#commands==1 and commands[1]=='Goto Executor 1.202','existing menu must be reopened, not replaced')
commands={};prompts={'600'};variables.CSWEEP_MENU_ACTION='7';sweep()
assert(contains('Store Macro 1.600 /o /nc') and contains('Store Macro 1.615 /o /nc'),'menu action must create control macros')
labels['Executor 1.202']='OTHER';commands={};sweep()
assert(#commands==0,'menu with a changed label must be preserved')
print('sweep integration tests passed')

