-- Real controller aim, independent players, actual bullets and hardware OAM.
local f=0
local expectedGun=dofile(TEST_ROOT..'/tests/rifle-expected.lua')
local modes={{},{}}
local shots={{},{}}
local checks=0
local crouched=0
local airDown=0
local oldGraphics=nil
local deferred=0
local dma=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local phases={{right=true},{right=true,up=true},{up=true},{left=true,up=true},{left=true},{left=true,down=true},{right=true,down=true},{down=true},{air=true},{air=true,right=true}}
emu.addEventCallback(function()
 for p=0,1 do
  local phase=phases[(math.floor(math.max(0,f-950)/56)+p*4)%#phases+1]
  local age=(f-950)%56
  setPad(p,{start=p==0 and(f==120 or f==200 or f==400),select=p==0 and f==180,
   right=f>=950 and phase.right,left=f>=950 and phase.left,up=f>=950 and phase.up,
   down=f>=950 and(phase.down or phase.air and age>=8),a=f>=950 and phase.air and age<8,
   b=f>=950 and f%12<4})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for i=0,127 do w(N.BG_COLLISION_DATA+i,(i%64)//4==11 and 255 or 0)end
 for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end
 for p=0,1 do
  local b=0x6000+p*128
  w(b+4,POWER or 0);w(b+0x35,0);w(b+0x4c,2);w(b+0x49,240)
  w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0);w(N.SPRITE_X_POS+p,80+p*80)
  if f<945 then w(N.SPRITE_Y_POS+p,164);w(b+5,0);w(b+0x18,0);w(b+0x19,0)end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f>=1100 and f<1120 then oldGraphics=r(N.CPU_GRAPHICS_BUFFER);w(N.CPU_GRAPHICS_BUFFER,1);deferred=deferred+1 end
end,emu.callbackType.exec,0x6500)
emu.addMemoryCallback(function(a,v)
 if f<950 or f>=1650 then return end
 local pc=emu.getState()['cpu.pc']
 if r(0x8000)~=6 or pc<N.set_bullet_velocity or pc>=N.bullet_velocity_ptr_tbl then return end
 local slot=a-N.PLAYER_BULLET_Y_VEL_FRACT
 local p=r(0x11);if p>1 then return end
 local aim=r(0x0b)
 local vx=r(N.PLAYER_BULLET_X_VEL_FAST+slot)*256+r(N.PLAYER_BULLET_X_VEL_FRACT+slot)
 local vy=r(N.PLAYER_BULLET_Y_VEL_FAST+slot)*256+v
 if vx>=32768 then vx=vx-65536 end
 if vy>=32768 then vy=vy-65536 end
 local mode=(aim==0 or aim==9)and 3 or(aim==1 or aim==8)and 1 or(aim==3 or aim==6)and 2 or aim>=10 and 4 or 0
 if mode==1 or mode==3 then assert(vy<0,'Upward rifle aim must shoot upward')end
 if mode==2 or mode==4 then assert(vy>0,'Downward rifle aim must shoot downward')end
 if mode==0 then assert(vy==0 and vx~=0,'Crouching/level aim must retain horizontal native bullets')end
 shots[p+1][mode]=(shots[p+1][mode]or 0)+1
end,emu.callbackType.write,N.PLAYER_BULLET_Y_VEL_FRACT,N.PLAYER_BULLET_Y_VEL_FRACT+15)
emu.addMemoryCallback(function()
 if oldGraphics~=nil then w(N.CPU_GRAPHICS_BUFFER,oldGraphics);oldGraphics=nil end
 if f<950 then return end
 dma={};for i=0,63 do dma[i]=r(0x6400+i)end
 for p=0,1 do
  local raw=r(0x6112+p);local pose=raw&63
  local body=0x6410+p*16;local gun=0x6400+p*8
  if pose~=22 and pose~=25 and(r(body)~=0xf8 or r(body+8)~=0xf8)then
   local aim=r(N.PLAYER_AIM_DIR+p);local air=r(N.PLAYER_JUMP_STATUS+p)~=0
   local ex=expectedGun(raw,aim,air,r(body+3),r(body),r(body+2))
   if ex.y<239 then
    local actual={r(gun),r(gun+1),r(gun+2),r(gun+3),r(gun+4),r(gun+5),r(gun+6),r(gun+7)}
    local want={ex.y,ex.tile,ex.attr,ex.x,ex.y,ex.second,ex.attr,ex.x2}
    for i=1,8 do assert(actual[i]==want[i],'Actual rifle OAM must match native aim '..aim..' pose '..raw..' byte '..i)end
    if aim<10 then assert(((r(body+2)&64)~=0)==(aim>=5),'Mario and the rifle must face the actual gun direction, including Down+direction')end
    modes[p+1][ex.mode]=(modes[p+1][ex.mode]or 0)+1
    if(aim==4 or aim==5)and not air then assert(ex.mode==0);crouched=crouched+1 end
    if(aim==4 or aim==5)and air then assert(ex.mode==4);airDown=airDown+1 end
   end
  end
 end
 checks=checks+1
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function()
 if f>=950 and r(N.LEVEL_ROUTINE_INDEX)==4 then
  local line=emu.getState()['ppu.scanline'];assert(line<0 or line>=240,'Angled rifles must preserve vblank-only uploads')
 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if dma then for i=0,63 do assert(emu.read(i,emu.memType.nesSpriteRam)==dma[i],'Aiming must reach actual hardware OAM')end;dma=nil end
 if f==1080 then
  local out=assert(io.open(TEST_ROOT..'/build/rifle-aim-gameplay-'..(POWER or 0)..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==1650 then
  for p=1,2 do for mode=0,4 do
   assert((modes[p][mode]or 0)>5,'Both players must display every native aim class: '..p..' mode '..mode)
   assert((shots[p][mode]or 0)>0,'Both players must fire actual bullets in every aim class: '..p..' mode '..mode)
  end end
  assert(checks>500 and deferred>10 and crouched>10 and airDown>10,'Exercise deferred graphics, ground crouching and actual downward airborne shots')
  print('PASS power '..(POWER or 0)..': '..checks..' hardware aim frames; both players, every gun angle, real projectiles, crouched '..crouched..', air-down '..airDown)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
