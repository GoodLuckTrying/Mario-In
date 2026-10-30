REFERENCE_BOOT=true
dofile(TEST_ROOT..'/tests/common.lua')
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 local file=assert(io.open(TEST_ROOT..'/build/native-background-reference.bin','wb'))
 for a=0xc00,0xfff do file:write(string.char(emu.read(a,emu.memType.nesPpuDebug)))end
 for a=0x1000,0x177f do file:write(string.char(emu.read(a,emu.memType.nesPpuDebug)))end
 file:close();finish('original ROM boot supplies canonical HUD font and ring background CHR')
-- A073 follows the original game's own sprite-zero marker initialization
-- at $0D20. Capture the native gameplay graphics, after that legitimate edit.
end,emu.callbackType.exec,0xA073)
