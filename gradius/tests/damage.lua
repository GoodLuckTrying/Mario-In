local f=0
local fired=false
local hits=0
local inv=INV or 0
local kind=KIND or 'enemy'
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function() setPad(0,{start=f>=200 and f<210});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if fired or f<500 then return end
 fired=true
 w(0x7005,inv);w(0x46,0);w(0x360,80);w(0x320,96)
 for i=12,31 do w(0x120+i,0);w(0x100+i,0);w(0x300+i,0) end
 if kind=='enemy' then w(0x10c,1);w(0x12c,0x11);w(0x30c,0x85);w(0x36c,80);w(0x32c,96);w(0x460,0)
 elseif kind=='bullet' then w(0x136,0x59);w(0x176,0);w(0x376,76);w(0x336,92)
 else for i=0x500,0x6ff do w(i,255) end end
end,emu.callbackType.exec,0x9a70)
emu.addMemoryCallback(function() if fired then hits=hits+1 end end,emu.callbackType.exec,H.DeathGate)
emu.addMemoryCallback(function()
 if not fired then return end
 assert(hits>0,'The real '..kind..' collision must reach the death gate')
 assert(r(0x100)==(inv==1 and 1 or 2),'Invincibility must block native '..kind..' damage')
 print('PASS native '..kind..' damage inv '..inv);emu.stop(0)
end,emu.callbackType.exec,0x9a73)
emu.addEventCallback(function() f=f+1;if f>550 then assert(false,'Fixture timed out') end end,emu.eventType.endFrame)
