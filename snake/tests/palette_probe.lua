local f=0
emu.addEventCallback(function()setPad(0,{start=f>=700 and f<710});setPad(1,{})end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==950 then
  local v={}
  for a=0x3f10,0x3f1f do v[#v+1]=string.format('%02X',emu.read(a,emu.memType.nesPpuDebug))end
  print('PALETTE '..table.concat(v,' '))
  local v={}
  for a=0x39,0x48 do v[#v+1]=string.format('%02X',emu.read(a,emu.memType.nesDebug))end
  print('SHADOW '..table.concat(v,' '))
  local expected={0x0f,0x16,0x37,0x0f,0x0f,0x23,0x20,0x0f,0x0f,0x27,0x37,0x0f,0x0f,0x0a,0x1a}
  for i=1,#expected do
   assert(emu.read(0x3f10+i,emu.memType.nesPpuDebug)==expected[i],'native Pibble/NPC palette '..i)
   assert(emu.read(0x39+i,emu.memType.nesDebug)==expected[i],'native palette shadow '..i)
  end
  assert(GRAPHICS_CHECKS>100,'displayed native sprite patterns must be checked')
  print('PASS exact SMB1 fire colors, approved shared shades, and preserved remaining palette entries')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
