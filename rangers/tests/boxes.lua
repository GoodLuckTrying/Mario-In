local f=0
local booted=false
local pickups=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=not booted and f%90<4,right=f>=650 and f<1100,b=f>=650 and f<1100 and f%24<10});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function(a,v)
 if f>700 and v>=0x82 and v<=0x85 then pickups=pickups+1 end
end,emu.callbackType.write,0x56)
emu.addMemoryCallback(function()
 if f>=650 then
  local a={};for i=2,15 do a[#a+1]=string.format('%d:%02X/%02X/%02X',i,r(0x4d0+i),r(0x4e0+i),r(0x420+i)) end
  print('BOX '..f..' x '..r(0x500)..':'..r(0x4f0)..' y '..r(0x520)..':'..r(0x510)..' code '..r(0x10)..' '..table.concat(a,' '))
 end
end,emu.callbackType.exec,0xcb19)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then for s=2,5 do assert(r(0x4d0+s)==0,'Native box object slots must be free after level initialization') end end
 if f%60==0 and f>=660 then print(f..' x '..r(0x500)..':'..r(0x4f0)..' carry '..r(0x56)..' facing '..r(0x680b)) end
 if f==1100 then
  assert(pickups>=2,'The actual opening stacked boxes must be picked up and thrown using B')
  local o=assert(io.open(TEST_ROOT..'/build/boxes.png','wb'));o:write(emu.takeScreenshot());o:close()
  print('PASS opening background boxes '..pickups);emu.stop(0)
 end
end,emu.eventType.endFrame)
