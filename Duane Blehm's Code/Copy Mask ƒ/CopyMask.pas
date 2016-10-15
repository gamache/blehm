Program CopyMaskDemo;{copyright ©,1987...Duane Blehm,HomeTown Software}
{This program illustrates using the CopyMask() ROM procedure for animation.
Note: CopyMask and CalcMask are NOT available in the 64k ROMs.
We just set up everything so we could achieve the same 'effect' as we did
with CopyBits and regions in the Animation Demo.  We're sure there are
some better examples of how CopyMask might be used... thought out with
its features in mind.  See Inside Mac vol. 4 or Technical Note #57 for
specs. on these and other 'new' 128k ROM Quickdraw routines.}

USES MacIntf;

{$L CMask.rsrc}{link resources...just our menu stuff}

CONST
   lastMenu = 2; {Number of Menus}
   appleMenu = 1;
   fileMenu = 256;

VAR   {global program stuff}
   FlowerMap,           {will use FlowerMap to do our CalcMask of Flower pict}
   MaskMap:             BitMap;{final mask, used with CopyMask call}
   imagePtr,tPtr:    Ptr;{imagePtr points to temp. BitImage of FlowerMap}
   tRect,
   MaskRect:               Rect;{MaskRect same size as FlyRect, CopyMask call}

   HomeTown:               PicHandle;{handle for our Logo pic}
   HomeRect:               Rect;{destination rect for our Logo}

   {here's all the fly/regions stuff}
   Fly:                 array[1..2] of PicHandle;{for loading 2 fly pictures}
   FlyRect:          Rect;{destination rect for drawing fly}
   OffFly:              array[1..2] of Rect;{source rects in offscreen}
   FlyNdx:              integer;{which offFly to draw}
   Flower:              PicHandle;{load picture from resource}
   FlowerRect:       Rect;{for locating the flower}
   FlyBorder:        Rect;{for fly border}
   FlightRect:       Rect;{For limiting fly flight}
   CursorIsOn:       Boolean;
   MouseRect:        Rect;{slides with mouse to smooth movement}

   OffScreen,           {will hold our 2 fly images}
   OldBits:             BitMap;
   SizeOfOff:           Size;    {for Size-ing the offscreen bitmap}
   OffRowBytes:         Integer;

   myDialog:               DialogPtr;
   myMenus:             Array[1..lastMenu] of MenuHandle;
   refNum,theMenu,
   theItem:             integer;
   Finished:               Boolean;{used to terminate the program}
   ClockCursor:         CursHandle; {handle to watch cursor}
   myWindow:            WindowPtr;
   Screen,DragArea,
   GrowArea:            Rect;
   i,x,y:                  integer;

{----------------------------------------------}
procedure CreatePictures;
var
   i:integer;
Begin
   HomeTown := GetPicture(131);{HomeTown logo}
   HomeRect := HomeTown^^.picFrame;{size dest.Rest for drawing pic}

   {we'll draw logo into upper right corner of window so relocate}
   OffSetRect(HomeRect,myWindow^.portRect.right - 1 -
                        HomeRect.right,1 - HomeRect.top);

   {load flystuff to demonstrate regions}
   Fly[1] := GetPicture(132);
   Fly[2] := GetPicture(133);
   {size the fly rectangles}
   For i := 1 to 2 do OffFly[i] := Fly[i]^^.picFrame;{they're both same size}
   FlyRect := OffFly[1];

   Flower := GetPicture(134);
   FlowerRect := Flower^^.picFrame;{size the FlowerRect}
end;

procedure CreateOffScreenBitMap;  {see CopyBits stuff,also tech.note 41}
var
   bRect: Rect;
Begin
   {find size/rows/bounds of bitimage}
   SetRect(bRect,0,0,50,95);  { big enough for our flys! }
   with bRect do begin
      OffRowBytes := (((right - left -1) div 16) +1) * 2;{has to be even!}
      SizeOfOff := (bottom - top) * OffRowBytes;
      OffSetRect(bRect,-left,-top);  {local coordinates...0,0 = topleft }
   end; { of with }

   with OffScreen do begin;      { create new BitMap record }
      {create new bitimage and make baseAddr point to it}
      baseAddr := QDPtr(NewPtr(SizeOfOff));
      rowbytes := OffRowBytes;{number of bytes/row,can extend beyond bounds}
      bounds := bRect;{limits of bitimage drawing?}
   end; { of with OffScreen }
End;

procedure DrawPicsIntoOffScreen;
var
   i: integer;
Begin
   OldBits := myWindow^.portBits;  {preserve old myWindow BitMap}
   SetPortBits(OffScreen); {our new myWindow BitMap }

   FillRect(OffScreen.bounds,white);    {erase our new BitMap to white}

   {locate the flys in the offscreen bitmap}
   OffSetRect(OffFly[1],- OffFly[1].left,-OffFly[1].top);
   OffSetRect(OffFly[2],- OffFly[2].left,OffFly[1].bottom-OffFly[2].top);

   {draw the flys into offscreen}
   For i := 1 to 2 do begin
         DrawPicture(Fly[i],OffFly[i]);
         ReleaseResource(Handle(Fly[i]));{done with pics so dump em}
      end;

   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure CreateMaskBitMap;
{first in the FlowerMap we draw the flower then we do a CalcMask of it
into an identical bitimage (imagePtr).  Once we have the mask in imagePtr
we make FlowerMap.baseAddr point to it and invert it so the fly is drawn
'outside' the flower edges (the 'flower' becomes white instead black).  The
MaskMap needs to be size of the area the fly will be flying over, and we
have a RoundRect border which includes the flower area.  So we fill the
RoundRect area with black and copyBits the inverted Flower mask from
FlowerMap. (see Paint document for illustration of this)  Now there is
black everywhere in the MaskMap we want the Fly to be drawn on the screen
except the 'coordinates' are not the same.  All we need to do is start
the MaskRect over the MaskMap in sync with the flyRect in our window so
they begin in the same 'relative' position to the flower/border}
Begin
   {find size/rows/bounds of bitimage}
   tRect := Flower^^.picFrame;{FlowerMap size of flower picture}
   with tRect do begin
      OffRowBytes := (((right - left -1) div 16) +1) * 2;{has to be even!}
      SizeOfOff := (bottom - top) * OffRowBytes;
      OffSetRect(tRect,-left,-top);  {local coordinates...0,0 = topleft }
   end; { of with }

   with FlowerMap do begin;      { create new BitMap record }
      {create new bitimage and make baseAddr point to it}
      baseAddr := QDPtr(NewPtr(SizeOfOff));
      rowbytes := OffRowBytes;{number of bytes/row,can extend beyond bounds}
      bounds := tRect;{limits of bitimage drawing?}
   end; {with}

   imagePtr := QDPtr(NewPtr(SizeOfOff));{Bitimage same as FlowerMap}

   OldBits := myWindow^.portBits;  {preserve old myWindow BitMap}
   SetPortBits(FlowerMap); {our new myWindow BitMap }

   DrawPicture(Flower,tRect);{draw flower into the BitMap}

   {create mask for flower picture, 128k ROMs only}
   CalcMask(FlowerMap.baseAddr,imagePtr,FlowerMap.rowbytes,
            FlowerMap.rowbytes,FlowerMap.bounds.bottom-FlowerMap.bounds.top,
            FlowerMap.rowbytes div 2);

   FlowerMap.baseAddr := imagePtr;{make FlowerMap point to mask}
   SetPortBits(FlowerMap);{make our window point to new flowerMap}
   InvertRect(FlowerMap.Bounds);{we want to draw outside the flower }

   {create the offscreen MaskMap.....find size/rows/bounds of bitimage}
   tRect := FlightRect;
   InsetRect(tRect,-64,-64);{enlarge so fly can exceed border}
   with tRect do begin
      OffRowBytes := (((right - left -1) div 16) +1) * 2;{has to be even!}
      SizeOfOff := (bottom - top) * OffRowBytes;
      OffSetRect(tRect,-left,-top);  {local coordinates...0,0 = topleft }
   end; { of with }

   with MaskMap do begin;     { create new BitMap record }
      {create new bitimage and make baseAddr point to it}
      baseAddr := QDPtr(NewPtr(SizeOfOff));
      rowbytes := OffRowBytes;{number of bytes/row,can extend beyond bounds}
      bounds := tRect;{limits of bitimage drawing}
   end; {with}

   SetPortBits(MaskMap);{so we can draw into the MaskMap}
   FillRect(MaskMap.bounds,white);{erase it to white}
   InsetRect(tRect,64,64);{shrink it back to flight size to draw border}
   FillRoundRect(tRect,48,32,black);{black in the flight area}
   {copy the Flower mask into MaskMap}
   tRect := FlowerRect;
   {locate it in center of border}
   OffSetRect(tRect,64+FlowerRect.left-FlightRect.left-tRect.left,
                  64+FlowerRect.top-FlightRect.top-tRect.top);
   CopyBits(FlowerMap,MaskMap,FlowerMap.bounds,tRect,srcCopy,nil);

   {note: we are done with the FlowerMap at this point.}

  SetPortBits(OldBits);    {restore old bitmap}

End;

procedure DrawWindowContents(WhichWindow:WindowPtr);{response to Update event}
var
   trect:Rect;
   i:integer;
Begin
   DrawPicture(HomeTown,HomeRect);{draw our logo}

   {copy offScreen flys into Window..upperleft corner,as in bitmap}
   CopyBits(OffScreen,myWindow^.portBits,OffScreen.bounds,
                  OffScreen.bounds,srcCopy,nil);

   {all the fly stuff}
   DrawPicture(Flower,FlowerRect);
   FrameRoundRect(FlyBorder,48,32);{border around the fly area}
   CopyMask(OffScreen,MaskMap,myWindow^.portBits,OffFly[FlyNdx],
                                                MaskRect,FlyRect);{draw the fly}

End;

Procedure InitialAnimation;{locate everything to begin animation}
Begin
   {locate the flower}
   OffSetRect(FlowerRect,160-FlowerRect.left,90-FlowerRect.top);

   {size the FlyBorder}
   FlyBorder := FlowerRect;
   InsetRect(FlyBorder,-18,0);{expand left/right for border}
   FlyBorder.top := FlyBorder.top - 18;{also top.. leave bottom for stem}

   FlightRect := FlyBorder;{FlightRect will compensate for using fly.topleft}

   CreateMaskBitMap;{create the 'mask' for use with the CopyMask call}

   InsetRect(FlightRect,-16,-16);{so fly can go beyond the flyborder}
   OffSetRect(FlightRect,-16,-16);{because we're using FlyRect.topleft}
   MouseRect := FlightRect;{MouseRect moves with cursor,& maps into FlightRect}

   {expand limits by 1 so we can have a frame border that's not erased}
   InSetRect(FlyBorder,-1,-1);

   MaskRect := FlyRect;
   {locate fly in upperleft of FlightRect}
   OffSetRect(FlyRect,FlightRect.left-FlyRect.left,
                                    FlightRect.top-FlyRect.top);
   {locate MaskRect in MaskMap relative to FlyRect and FlightRect}
   OffSetRect(MaskRect,32-MaskRect.left,32-MaskRect.top);{in synch with fly}
   FlyNdx := 1;{set to first Fly shape}
end;

procedure AnimateStuff;
var tPoint:Point;
   tRect:Rect;
  aTick:Longint;
Begin
   Delay(2,aTick);{CopyMask is seems to be faster than CopyBits with Rgn..?}
   {now animate the fly}
   GetMouse(tPoint);{get current mouse coordinates}

   {hide cursor if its over the fly area}
   If PtInRect(tPoint,FlyBorder) then begin
         If CursorIsOn then begin {hide cursor if its on}
                  HideCursor;
                  CursorIsOn := False;
            end;
       end
   else If not(CursorIsOn) then begin {show cursor if its off}
               ShowCursor;
               CursorIsOn := True;
         end;

   {limit fly image (FlyRect) to FlightRect extremes..}
   {to keep fly from wondering off visible area}
   {mouseRect moves with the cursor and tPoint is mapped into FlightRect}

   If not(PtInRect(tPoint,MouseRect)) then begin
         {a coordinate is outside mouseRect so slide mouseRect to tPoint}
         If tPoint.h < MouseRect.left then begin {slide MouseRect to left}
                  MouseRect.right := MouseRect.right -
                                 (MouseRect.left - tPoint.h);
                  MouseRect.left := tPoint.h;
            end
         else If tPoint.h > MouseRect.right then begin
                  MouseRect.left := MouseRect.left + tPoint.h - MouseRect.right;
                  MouseRect.right := tPoint.h;
            end;
         If tPoint.v < MouseRect.top then begin
                  MouseRect.bottom := MouseRect.bottom -
                                 (MouseRect.top - tPoint.v);
                  MouseRect.top := tPoint.v;
            end
         else If tPoint.v > MouseRect.bottom then begin
                  MouseRect.top := MouseRect.top + tPoint.v - MouseRect.bottom;
                  MouseRect.bottom := tPoint.v;
            end;
      end;{if not(ptinRect)}

   {tPoint is to MouseRect as FlyRect.topleft is to FlightRect}
   MapPt(tPoint,MouseRect,FlightRect);

   {determine horiz/vert. offset if needed, MaskRect moves in sync with FlyRect}
   If tPoint.h > FlyRect.left + 2 then begin
         FlyRect.left := FlyRect.left + 3;{offsetRect to right}
         FlyRect.right := FlyRect.right + 3;
         MaskRect.left := MaskRect.left + 3;{offsetRect to right}
         MaskRect.right := MaskRect.right + 3;
      end
   else if tPoint.h < FlyRect.left - 2 then begin
         FlyRect.left := FlyRect.left - 3;{offsetRect to left}
         FlyRect.right := FlyRect.right - 3;
         MaskRect.left := MaskRect.left - 3;{offsetRect to left}
         MaskRect.right := MaskRect.right - 3;
      end;
   {vertical offset?}
   If tPoint.v > FlyRect.top + 2 then begin
         FlyRect.top := FlyRect.top + 3;
         FlyRect.bottom := FlyRect.bottom + 3;
         MaskRect.top := MaskRect.top + 3;
         MaskRect.bottom := MaskRect.bottom + 3;
      end
   else if tPoint.v < FlyRect.top - 2 then begin
         FlyRect.top := FlyRect.top - 3;
         FlyRect.bottom := FlyRect.bottom - 3;
         MaskRect.top := MaskRect.top - 3;
         MaskRect.bottom := MaskRect.bottom - 3;
      end;

   {draw the fly from OffScreen to myWindow using MaskMap}
   CopyMask(OffScreen,MaskMap,myWindow^.portBits,OffFly[FlyNdx],
                                                MaskRect,FlyRect);

   If FlyNdx = 1 then inc(FlyNdx) {next shape, there are 2}
   else FlyNdx := 1;                      {back to first shape}
end;


PROCEDURE InitThings;
Begin
   InitGraf(@thePort);     {create a grafport for the screen}

   MoreMasters;   {extra pointer blocks at the bottom of the heap}
   MoreMasters;   {this is 5 X 64 master pointers}
   MoreMasters;
   MoreMasters;
   MoreMasters;

   {get the cursors we use and lock them down - no clutter}
   ClockCursor := GetCursor(watchCursor);
   HLock(Handle(ClockCursor));

   {show the watch while we wait for inits & setups to finish}
   SetCursor(ClockCursor^^);

   {init everything in case the app is the Startup App}
   InitFonts;                 {startup the fonts manager}
   InitWindows;               {startup the window manager}
   InitMenus;                 {startup the menu manager}
   TEInit;                    {startup the text edit manager}
   InitDialogs(Nil);          {startup the dialog manager}

   Finished := False;             {set program terminator to false}
   FlushEvents(everyEvent,0);     {clear events from previous program}
   { set up screen size stuff }
   Screen := ScreenBits.Bounds;  { Get screen dimensions from thePort }
   with Screen do   { Screen.Left, etc. }
      Begin
         SetRect(DragArea,Left+4,Top+24,Right-4,Bottom-4);
         SetRect(GrowArea,Left,Top+24,Right,Bottom);
      End;
End;

procedure CreateWindow;
var
   Wrect: Rect;
   TypeWind: Integer;
   Visible: Boolean;
   GoAway: Boolean;
   RefVal: Longint;
Begin
   SetRect(Wrect,8,40,504,336);
   TypeWind := 0;
   Visible := True;
   GoAway := True;

   myWindow := NewWindow(Nil,Wrect,'CopyMask Demo',Visible,
               TypeWind,Nil,GoAway,RefVal);
   SetPort(myWindow);
   ClipRect(myWindow^.portRect);{set clipping area as per Inside Mac}
End;

procedure DoMenuCommand(mResult:LongInt);
var
   name: Str255;
   tPort: GrafPtr;
Begin
   theMenu := HiWord(mResult);
   theItem := LoWord(mResult);
   Case theMenu of
      appleMenu:
         Begin
            GetItem(myMenus[1],theItem,name);
            refNum := OpenDeskAcc(name);
         End;
      fileMenu:
         Case theItem of
         1:{display offScreen bitmap in dialog}
            Begin
               myDialog := GetNewDialog(128,nil,myWindow);{from resource}
               GetPort(tPort);
               ShowWindow(myDialog);{invisible in resource}
               SelectWindow(myDialog);
               SetPort(myDialog);      {so we can draw into our window}

               CopyBits(OffScreen,myDialog^.portBits,OffScreen.bounds,
                              OffScreen.bounds,srcOr,Nil);{the whole thing}
               FrameRect(OffScreen.bounds);{frame it }
               MoveTo(OffScreen.bounds.left + 10,OffScreen.bounds.bottom + 20);
               DrawString('^ copy of OffScreen Bitmap');
               ModalDialog(Nil,theItem);{we'll close no matter what hit}

               HideWindow(myDialog);
               SelectWindow(myWindow);{restore our game window}
               SetPort(tPort);
            end;{1:}
         2:Finished := True;
         end;{case theItem}
   End;
   HiliteMenu(0);
End;

procedure TakeCareMouseDown(myEvent:EventRecord);
var
   Location: integer;
   WhichWindow: WindowPtr;
   MouseLoc: Point;
   WindowLoc: integer;
Begin
   MouseLoc := myEvent.Where;  {Global coordinates}
   WindowLoc := FindWindow(MouseLoc,WhichWindow);  {I-287}
   case WindowLoc of
      inMenuBar:
         DoMenuCommand(MenuSelect(MouseLoc));
      inSysWindow:
         SystemClick(myEvent,WhichWindow);  {I-441}
      inContent:
         If WhichWindow <> FrontWindow then
            SelectWindow (WhichWindow);
      inGoAway:
         If TrackGoAway(WhichWindow,MouseLoc) then
            Finished := True;{end the game}
   end; {case of}
end; { TakeCareMouseDown  }

procedure TakeCareActivates(myEvent:EventRecord);
var
   WhichWindow: WindowPtr;
Begin
   WhichWindow := WindowPtr(myEvent.message);
   SetPort(WhichWindow);
End;

procedure TakeCareUpdates(Event:EventRecord);
var
   UpDateWindow,TempPort: WindowPtr;
Begin
   UpDateWindow := WindowPtr(Event.message);
   GetPort(TempPort);
   SetPort(UpDateWindow);
   BeginUpDate(UpDateWindow);
   EraseRect(UpDateWindow^.portRect);{ or UpdateWindow^.VisRgn^^.rgnBBox }
   DrawWindowContents(UpDateWindow);
   EndUpDate(UpDateWindow);
   SetPort(TempPort);
End;

procedure MainEventLoop;
var
   myEvent: EventRecord;
Begin
   InitCursor;
   CursorIsOn := True;{keep track of hide/show cursor}
   Repeat
      SystemTask;
      If GetNextEvent(EveryEvent,myEvent) then
         Case myEvent.What of
            mouseDown:  TakeCareMouseDown(myEvent);
            KeyDown: Finished:= True;
            ActivateEvt:TakeCareActivates(myEvent);
            UpDateEvt:  TakeCareUpdates(myEvent);
         End

      Else AnimateStuff;

   Until Finished;
End;

procedure SetUpMenus;
var
   i: integer;
Begin
   myMenus[1] := GetMenu(appleMenu);  {get menu info from resources}
   AddResMenu(myMenus[1],'DRVR'); {add in all the DA's}
   myMenus[2] := GetMenu(fileMenu);
   For i := 1 to lastMenu do
      begin
         InsertMenu(myMenus[i],0);
      end;
   DrawMenuBar;
End;

procedure CloseStuff;
Begin
   {be sure to kill any sound I/O before quitting!}
End;

{Main Program begins here}
BEGIN
   InitThings;
   {check for the 64k ROMs, abort if they're present}
   Environs(x,y);
   If x >= 117 then begin {64k roms aren't present,so go ahead}
         SetUpMenus;
         CreateWindow;
         CreatePictures;{load picts from resource file}
         CreateOffScreenBitMap;{for use with copyBits procedure}
         DrawPicsIntoOffScreen;{OffScreen holds all our fly shapes}
         InitialAnimation;{set up stuff for start of animation}
         MainEventLoop;{will animate fly if nothing else is going on}
      end
   else begin
         InitCursor;{show arrow cursor}
         i := NoteAlert(128,nil); {display alert and exit}
      end;{else}
   CloseStuff;
END.
