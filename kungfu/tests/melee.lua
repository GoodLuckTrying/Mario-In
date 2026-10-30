-- Actual A/B presses drive the native standing, crouching and aerial attacks.
local f=0
local stage=STAGE or 0
local case=-1
local begin=800
local reset=true
local active=false
local guard=false
local checked=0
local done=false
local small={26,27,17,18,19,21}
local big={3,5,6,7,8,9}
local file=assert(io.open(TEST_ROOT..'/dist/Mario in Kung Fu.nes','rb'))
local rom=file:read('*a');file:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function info()
 local power=case//12
 local mode=case%6
 local left=case%12>=6
 return power,mode,left
end
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addEventCallback(function()
 local controls={start=f>=180 and f<190}
 if case>=0 then
  local power,mode,left=info();local dt=f-begin
  controls.down=mode//2==1
  controls.up=mode//2==2
  controls.a=mode%2==0 and dt>=2 and dt<20
  controls.b=mode%2==1 and dt>=2 and dt<20
 end
 setPad(0,controls);setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 for i=0,5 do w(0x80+i,0)end
 w(0x373,0);w(0x374,0);w(0x7c01,0)
 if case>=0 and reset then
  reset=false
  local power,mode,left=info();local air=mode//2==2
  w(0x7c00,power);w(0x69,(left and 0 or 1)+(air and 4 or 0));w(0x68,air and 5 or 1)
  w(0x21,air and 2 or 0);w(0x23,0);w(0x496,0);w(0x36b,0)
  w(0x7c08,air and 1 or 0);w(0x7c04,air and 100 or 135);w(0xb6,air and 100 or 135)
  w(0x7c05,0);w(0x7c06,0);w(0x7c07,0);w(0x7c03,air and 8 or 0)
  w(0x7d06,left and 2 or 1);w(0x7d07,left and 2 or 1);w(0x7c3d,0)
  w(0x7d13,0x70);w(0x7d14,0x70)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if case<0 or reset then return end
 local power,mode,left=info()
 if r(0x7c38)==1 then
  local expected=(power==0 and small or big)[mode+1]
  assert(r(0x7c0f)==expected,'native attack must display its size, punch/kick and stance pose: case '..case..' bank '..r(0x7c0f))
  active=true
 elseif r(0x69)&0x30~=0 or (mode>=4 and r(0x69)&4~=0) then guard=true end
end,emu.callbackType.exec,H.Draw)
emu.addMemoryCallback(function()
 if case<0 or reset or r(0x7c38)~=1 then return end
 local power,mode,left=info();local bank=r(0x7c0f)
 for _,tile in ipairs({6,7,8,9,12,13,15,0xd6,0x0a,0x0b,0xd7,0xd8})do
  for n=0,15 do
   assert(emu.read(tile*16+n,emu.memType.nesPpuDebug)==rom:byte(0x8010+bank*8192+tile*16+n+1),'displayed CHR bank must match selected melee frame')
  end
 end
 local ext=false
 for a=0x240,0x24c,4 do
  if r(a)<240 then
   ext=true
   assert((r(a+2)&64)==(left and 64 or 0),'extended limb must mirror with Mario')
   assert(r(a+3)==r(0x94)+(left and -16 or 8),'extended limb must face the same way as its hitbox')
  end
 end
 assert(ext,'active punch/kick must extend a visible limb')
 checked=checked+1
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if f==800 then case=0 end
 if case>=0 and f-begin>=60 then
  assert(active and guard,'controller attack must animate windup and extension, case '..case)
  case=case+1;begin=f;reset=true;active=false;guard=false
  if case==36 then
   assert(checked>100,'displayed attack frames must be checked throughout')
   print('PASS floor '..stage..' all 36 controller-driven melee form/stance/facing cases with displayed CHR and mirrored limbs')
   done=true;emu.stop(0)
  end
 end
 assert(f<3200,'melee cases must complete')
end,emu.eventType.endFrame)
