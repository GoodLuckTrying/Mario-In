-- Fixture-only native stage loading. Patch the operands of the normal
-- main-loop JMP for one execution, then restore them at the target. Avoid
-- changing CPU state in the middle of an instruction at a frame boundary.
local request=nil
local patched=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
function requestNativeStage(stage)
 request=stage
end
emu.addMemoryCallback(function()
 if not request or r(0xB6)~=2 then return end
 local stage=request;request=nil
 w(0xA0,stage);w(0x130,0);w(0x37,0);w(0x38,0);w(0xAB,0)
 if stage==8 then w(0xAB,64);w(0x170,4);w(0x171,39) end
 emu.write(2*0x4000+0xA8,0x6D,emu.memType.nesPrgRom)
 emu.write(2*0x4000+0xA9,0xC0,emu.memType.nesPrgRom)
 patched=true
end,emu.callbackType.exec,0x80A7)
emu.addMemoryCallback(function()
 if not patched then return end
 emu.write(2*0x4000+0xA8,0x95,emu.memType.nesPrgRom)
 emu.write(2*0x4000+0xA9,0x80,emu.memType.nesPrgRom)
 patched=false
end,emu.callbackType.exec,0xC06D)
