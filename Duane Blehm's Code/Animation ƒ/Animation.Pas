Program Anim;
{this is a simple animation program.. in CreatePictures we load several
pictures.  These pictures can be created in any Paint or Drawing type
program.. then copied to Scrapbook DA.  Using ResEdit, the resource editor,
these Pictures can be copied from the Scrapbook into 'PICT' type resources.
Note that in our Anim.R source file we have an INCLUDE Anim.rsrc... when
RMaker compiles the Anim.R file it 'includes' any resources in the file
Anim.rsrc.  That's how our Paint pictures get into the SimpleAnimation
resources.

Once we have them loaded into our various picHandles we then
CreateOffScreenBitMap so we have a place to DrawPicture() them.  The
OffScreen bitmap is a section of memory just like the memory being
displayed on the screen... we just can't see it! at least not until we
CopyBits() some of it over to the visible screen Bitmap.  We 'Draw' into
the OffScreen by setting our window^.portbits to our OffScreen bitmap..
watch out for 'clipping' if your OffScreen is bigger than your window.
Now for the fun!  We have everything we need for the CopyBits() ROM call.
We have two Rectangles... one (sRect) that frames the shape to be copied
from OffScreen, the other (dRect) frames the location in our window where
we want the shape to be drawn.  If dRect is not same size as sRect then
CopyBits will scale the shape to fit.  This program uses the srcCopy mode
to 'erase' any previous stuff in the dRect... by using a 3 pixel white
border on the left side of our wagon we can offset it by 3 pixels per
animation loop and still 'erase' the previous wagon just by drawing over it.
Internal Animation (wheels turning, horse running,etc.) is achieved by
alternately drawing 3 different shapes in sequence as the dRect moves across
the screen... this is easily done by having an array of offscreen sRect's
and an index to step thru the array...}

{note: to move a given rectangle 'myRect' from its present location
(Current) to another location (Destination) the following can be used...

OffsetRect(myRect,Destination.h - Current.h,Destination.v - Current.v);

or...

OffsetRect(myRect,DestRect.left - myRect.left,DestRect.top - myRect.top);}

USES MacIntf;

{$L Anim.rsrc}{link resources...just our menu stuff}

CONST
   lastMenu = 2; {Number of Menus}
   appleMenu = 1;
   fileMenu = 256;

   WagonOne = 128;{Three wagon shapes loaded from resource file}
   WagonTwo = 129;
   WagonThree = 130;
   {Resource Picts pasted from Scrapbook into Resource file using ResEdit}

VAR   {global program stuff}
   myDialog:      DialogPtr;
   myMenus:    Array[1..lastMenu] of MenuHandle;
   refNum,theMenu,
   theItem:    integer;
   Finished:      Boolean;{used to terminate the program}
   ClockCursor:   CursHandle; {handle to watch cursor}
   myWindow:      WindowPtr;
   Screen,DragArea,
   GrowArea:      Rect;

   HomeTown:      PicHandle;{handle for our Logo pic}
   HomeRect:      Rect;{destination rect for our Logo}
   Wagon:         Array[1..3] of PicHandle;{we got three wagon pics}
   WagonRect:     Rect;{size of one wagon, onScreen destination for Copybits}
   OffWagonRect:  Array[1..3] of Rect;{wagon shape rects in offScreen}
   WagonNdx:      integer;{which of 3 wagon shapes is to be drawn}

   {here's all the fly/regions stuff}
   Fly:           array[1..2] of PicHandle;{for loading 2 fly pictures}
   FlyRect:    Rect;{destination rect for drawing fly}
   OffFly:        array[1..2] of Rect;{source rects in offscreen}
   FlyNdx:        integer;{which offFly to draw}
   Flower:        PicHandle;{load picture from resource}
   FlowerRect: Rect;{for locating the flower}
   FlowerRgn:     RgnHandle;{For 'clipping' fly and flower}
   FlyLimits:     Rect;{for fly border}
   FlightRect: Rect;{For limiting fly flight}
   CursorIsOn: Boolean;
   MouseRect:  Rect;{size of FlightRect, slides with mouse to smooth movement}

   OffScreen,OldBits:      BitMap;     {for drawing into offscreen}
   SizeOfOff:           Size;    {Size offscreen bitmap}
   OffRowBytes:         Integer;

{----------------------------------------------}
procedure CreatePictures; {get 3 Wagon PICT's from resource file}
var
   i:integer;
Begin
   HomeTown := GetPicture(131);{HomeTown logo}
   HomeRect := HomeTown^^.picFrame;{size dest.Rest for drawing pic}

   {we'll draw logo into upper right corner of window so relocate}
   OffSetRect(HomeRect,myWindow^.portRect.right - 20 -
                        HomeRect.right,20 - HomeRect.top);

   Wagon[1] := GetPicture(WagonOne); {load Wagon shapes from resources}
   Wagon[2] := GetPicture(WagonTwo);
   Wagon[3] := GetPicture(WagonThree);
   WagonRect := Wagon[1]^^.picFrame; { i-159, size our WagonRect }
   {Size Rects for OffScreen shapes...will locate them later}
   For i := 1 to 3 do OffWagonRect[i] := WagonRect;

   {load flystuff to demonstrate regions}
   Fly[1] := GetPicture(132);
   Fly[2] := GetPicture(133);
   {size the fly rectangles}
   For i := 1 to 2 do OffFly[i] := Fly[i]^^.picFrame;{they're both same size}
   FlyRect := OffFly[1];

   Flower := GetPicture(134);
   FlowerRect := Flower^^.picFrame;

   {load the region resource and coerce it to RgnHandle}
   FlowerRgn := RgnHandle(GetResource('RGN ',128));{flower region... outline}
   {note this region created with our 'Regions' utility}
end;

procedure CreateOffScreenBitMap;  {see CopyBits stuff,also tech.note 41}
const
   OffLeft = 0;
   OffTop = 0;
   OffRight = 115;
   OffBottom = 95;  {size bitmap to contain three wagon Picts}
var
   bRect: Rect;
Begin
   {find size/rows/bounds of bitimage}
   SetRect(bRect,Offleft,OffTop,OffRight,OffBottom);  { drawing area }
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

  {note: If offscreen bitmap is bigger than myWindow bitmap watchout for
   clipping caused by ClipRgn and VisRgn fields of grafport record, you
   can set cliprgn with ClipRect procedure and use CopyRgn procedure
   to store old visrgn in temporary rgn... etc.}

   FillRect(myWindow^.PortRect,white);    {erase our new BitMap to white}

   {locate wagon shape Rectangles in OffScreen Bitmap}
   OffSetRect(OffWagonRect[1],-OffWagonRect[1].left,
                                             -OffWagonRect[1].top);{topleft corner..0,0}
   OffSetRect(OffWagonRect[2],-OffWagonRect[2].left,
                           OffWagonRect[1].bottom - OffWagonRect[2].top);{below 1}
   OffSetRect(OffWagonRect[3],-OffWagonRect[3].left,
                           OffWagonRect[2].bottom - OffWagonRect[3].top);{below 2}

   {draw the wagons into the offscreen bitmap}
   For i := 1 to 3 do DrawPicture(Wagon[i],OffWagonRect[i]);

   {locate the flys in the offscreen bitmap}
   OffSetRect(OffFly[1],OffWagonRect[1].right - OffFly[1].left,
                                             -OffFly[1].top); {right of wagons, at top}
   OffSetRect(OffFly[2],OffWagonRect[1].right - OffFly[2].left,
            OffFly[1].bottom-OffFly[2].top); {right of wagons, below fly[1]}

   {draw the flys into offscreen}
   For i := 1 to 2 do DrawPicture(Fly[i],OffFly[i]);

   {could do a 'ReleaseResource' here if you're done with the Pictures}

   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure DrawWindowContents(WhichWindow:WindowPtr);{response to Update event}
var
   trect:Rect;
   i:integer;
Begin
   DrawPicture(HomeTown,HomeRect);{draw our logo}

   {draw groundline under wagon}
   MoveTo(myWindow^.portRect.left,WagonRect.bottom);
   LineTo(myWindow^.portRect.right,WagonRect.bottom);

   {copy offScreen Wagons & flys into Window..upperleft corner,as in bitmap}
   CopyBits(OffScreen,myWindow^.portBits,OffScreen.bounds,
                  OffScreen.bounds,srcCopy,nil);

   {draw current wagon Shape being animated into WagonRect}
   CopyBits(OffScreen,myWindow^.portBits,OffWagonRect[WagonNdx],
                  WagonRect,srcCopy,nil);

   {all the fly stuff}
   DrawPicture(Flower,FlowerRect);
   CopyBits(OffScreen,myWindow^.portBits,OffFly[FlyNdx],
                  FlyRect,srcCopy,FlowerRgn);
   FrameRoundRect(FlyLimits,48,32);{border around the fly area}
End;

Procedure InitialAnimation;{locate everything to begin animation}
var
   tRgn:RgnHandle;
Begin
   {locate first WagonRect,left side of window on groundline (250)}
   OffSetRect(WagonRect,-WagonRect.left,250-WagonRect.bottom);
   WagonNdx := 1;{set to first Wagon shape}

   {locate the flower}
   OffSetRect(FlowerRect,160-FlowerRect.left,90-FlowerRect.top);

   {locate the FlowerRgn in sync with Flower}
   OffSetRgn(FlowerRgn,FlowerRect.left-FlowerRgn^^.rgnBBox.left,
            FlowerRect.top-FlowerRgn^^.rgnBBox.top);

   {size the FlyLimits}
   FlyLimits := FlowerRect;
   InsetRect(FlyLimits,-18,0);{expand left/right for border}
   FlyLimits.top := FlyLimits.top - 18;{also top.. leave bottom for stem}

   {create the region to exclude drawing in the flower}
   tRgn := NewRgn;
   OpenRgn;
   FrameRoundRect(FlyLimits,48,32);
   CloseRgn(tRgn);{region of limits rectangle}

   DiffRgn(tRgn,FlowerRgn,FlowerRgn);{take out flower,put result in FlowerRgn}

   {expand limits by 1 so we can have a frame border}
   InSetRect(FlyLimits,-1,-1);

   FlightRect := FlyLimits;{FlightRect will compensate for using fly.topleft}
   InSetRect(FlightRect,-20,-20);{expand it so fly will be outside border}
   OffSetRect(FlightRect,-20,-20);{compensate for using flyRect.topleft}
   MouseRect := FlightRect;{MouseRect moves with cursor,& map into FlightRect}

   {locate fly in upperleft of FlightRect}
   OffSetRect(FlyRect,FlightRect.left-FlyRect.left,
                                    FlightRect.top-FlyRect.top);
   FlyNdx := 1;{set to first Fly shape}
end;

procedure AnimateWagon;
var tPoint:Point;
   tRect:Rect;
Begin
   {locate next WagonRect for wagon shape}
   If WagonRect.left > myWindow^.portRect.right then
      OffSetRect(WagonRect,-WagonRect.right,0) {back to left side}
   else OffSetRect(WagonRect,1,0); {move one pixel to right}

   {draw Current WagonNdx shape into WagonRect}
   CopyBits(OffScreen,myWindow^.portBits,OffWagonRect[WagonNdx],
                  WagonRect,srcCopy,nil);

   {next wagon shape to be drawn}
   If WagonNdx < 3 then inc(WagonNdx) {next shape}
   else WagonNdx := 1; {back to first shape}

   {now animate the fly}
   GetMouse(tPoint);{get current mouse coordinates}

   {hide cursor if its over the fly area}
   If PtInRect(tPoint,FlyLimits) then begin
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

   {tPoint is to Mouse as FlyRect.topleft is to FlightRect}
   MapPt(tPoint,MouseRect,FlightRect);

   {determine horizontal offset if needed}
   If tPoint.h > FlyRect.left + 2 then begin
         FlyRect.left := FlyRect.left + 3;{offsetRect to right}
         FlyRect.right := FlyRect.right + 3;
      end
   else if tPoint.h < FlyRect.left - 2 then begin
         FlyRect.left := FlyRect.left - 3;{offsetRect to left}
         FlyRect.right := FlyRect.right - 3;
      end;
   {vertical offset?}
   If tPoint.v > FlyRect.top + 2 then begin
         FlyRect.top := FlyRect.top + 3;
         FlyRect.bottom := FlyRect.bottom + 3;
      end
   else if tPoint.v < FlyRect.top - 2 then begin
         FlyRect.top := FlyRect.top - 3;
         FlyRect.bottom := FlyRect.bottom - 3;
      end;

   CopyBits(OffScreen,myWindow^.portBits,OffFly[FlyNdx],
                                                FlyRect,srcCopy,FlowerRgn);

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
   SetRect(Wrect,10,40,500,300);
   TypeWind := 0;
   Visible := True;
   GoAway := True;

   myWindow := NewWindow(Nil,Wrect,'Simple Animation',Visible,
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

      Else AnimateWagon;{animate one loop of our wagon shape}

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
   SetUpMenus;
   CreateWindow;
   CreatePictures;{load picts from resource file}
   CreateOffScreenBitMap;{for use with copyBits procedure}
   DrawPicsIntoOffScreen;{OffScreen holds all our wagon/fly shapes}
   InitialAnimation;{set up stuff for start of animation}
   MainEventLoop;{will animate wagon/fly if nothing else is going on}
   CloseStuff;
END.
