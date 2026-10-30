if ORIGINAL then H=N end
dofile(TEST_ROOT..'/tests/common.lua')
function input(t)return{right=t<45,a=t%12==1,b=t%40==20}end
function tick(t)
 if f%120==0 then print('MODE '..f..' '..r(H.GameMode)..' '..r(H.GameSubmode)..' update '..r(H.IsUpdatingMode)..' slot '..r(H.CurSaveSlot))end
 if t>=0 and t%20==0 then print('PLAY '..t..' xy '..r(H.ObjX)..','..r(H.ObjY)..' hp '..r(H.HeartValues)..' fire '..r(0x7fc0)..','..r(0x7fc1))end
 if t==180 then print('ROOM '..r(H.RoomId)..' start '..r(H.LevelInfo_StartRoomId)..' quest '..r(H.QuestNumbers));screenshot(ORIGINAL and 'original-opening' or 'opening');finish('registered a new native save and reached the playable overworld')end
end
