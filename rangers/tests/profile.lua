-- Inclusive emulated CPU-cycle profile of the fixed performance replay.
local frame=0;local pending={};local installed={};local sums={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function onReturn(address)
 local state=emu.getState();local list=pending[address]
 if not list then return end
 for i=#list,1,-1 do
  local item=list[i]
  if state['cpu.sp']==item.sp then
   local v=sums[item.name];v.calls=v.calls+1;v.cycles=v.cycles+state['cpu.cycleCount']-item.cycle
   table.remove(list,i)
  end
 end
end
for _,name in ipairs({'Move','LoadState','SaveState','Tile','Compose','MoveX','MoveY','Actions','CollisionGate','Stomp','Fireballs','Render','Palettes','PaletteUpload'})do
 local address=H[name]
 if address then
  sums[name]={calls=0,cycles=0}
  emu.addMemoryCallback(function()
   if frame<700 or frame>=1100 then return end
   local s=emu.getState();local sp=s['cpu.sp'];local ret=r(0x100+sp+1)+256*r(0x100+sp+2)+1
   if not installed[ret]then
    installed[ret]=true
    emu.addMemoryCallback(function()onReturn(ret)end,emu.callbackType.exec,ret)
   end
   pending[ret]=pending[ret]or{}
   pending[ret][#pending[ret]+1]={name=name,sp=(sp+2)&255,cycle=s['cpu.cycleCount']}
  end,emu.callbackType.exec,address)
 end
end
emu.addEventCallback(function()
 frame=frame+1
 if frame==1100 then
  local names={};for name in pairs(sums)do names[#names+1]=name end
  table.sort(names,function(a,b)return sums[a].cycles>sums[b].cycles end)
  for _,name in ipairs(names)do local v=sums[name];print('PROFILE '..name..' calls '..v.calls..' cycles '..v.cycles..' per call '..math.floor(v.cycles/math.max(1,v.calls)))end
 end
end,emu.eventType.endFrame)
dofile(TEST_ROOT..'/tests/performance.lua')
