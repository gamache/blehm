Program DragPieceDemo;{Thu Dec 17, 1987, © HomeTown Software,1987
all rights reserved, this code not for distribution}
{this program demonstrates use of our 'generic' DragPiece() procedure for
animation of a 'piece' over a background.  We're still trying to make the
procedure truly independent.  Currently it has some 'options' embedded
within it for initializing the PicMap and PatchMap and also for how
the piece is effected on completion... see DragPiece(). The procedure
is called from TakeCareMouseDown() in window contents. }

{also you might want to check out the MakeBitMap() procedure, this is a big
improvement over our old CreateOffScreenBitmap() stuff!}

USES MacIntf;{TML Directives}

{$L aDragPiece.rsrc}{link the resource file}

CONST
   lastMenu = 2; {Number of Menus}
   appleMenu = 1;
   fileMenu = 256;

VAR   {global program stuff}
   myMenus:             Array[1..lastMenu] of MenuHandle;
   refNum,theMenu,theItem:    integer;
   Finished:               Boolean;{used to terminate the program}
   ClockCursor:            CursHandle; {handle to watch cursor}
   myWindow:      WindowPtr;
   Screen,DragArea,GrowArea:  Rect;

   tRect:Rect;
   tPt:Point;
   DragRgn:RgnHandle;
   LogoLoc:Point;
{----------------------------------------------}

procedure DrawWindowContents(WhichWindow:WindowPtr);
var
   trect:Rect;
   tStr:Str255;
   myPic:PicHandle;
Begin
   FillRect(whichWindow^.portRect,ltGray);
   tStr := 'Click to create a spot and then DRAG it!';
   SetRect(tRect,0,80,StringWidth(tStr) + 20,105);
   EraseRect(tRect);
   moveTo(10,100);
   DrawString(tStr);
   myPic := GetPicture(128);{logo}
   tRect := myPic^^.picFrame;
   {watchout! the window^.portRect is offset by a SetOrigin() call!}
   OffSetRect(tRect,LogoLoc.h-tRect.right,LogoLoc.v-tRect.bottom);
   DrawPicture(myPic,tRect);
End;

procedure DragPiece(aWindow:WindowPtr;var theMouse:Point;
                  DragRect:Rect;PieceRgn:RgnHandle);
{aWindow is window the piece is to be dragged in, theMouse is location of
mouseDown, DragRect limits the area the piece can be dragged within the
window, PieceRgn is destination Region in aWindow for the piece.  PieceRgn
defines the size of the piece by its .rgnBBox and shape by the shape of
the region... the Piece drawn into the PicMap is masked into the ComboMap
by a copy of the PieceRgn. If no Mask is desired just pass a new Rgn set
to the Rect in the window with a RectRgn() call.  This procedure does NO
error checking for memory available, etc., beware!}
var
   tRgn:RgnHandle;{temp copy of PieceRgn for animation}
   PatchMap,ComboMap,PicMap,OldBits:Bitmap;
   sRect,sUnionRect,LastsRect,
   cRect,cUnionRect,LastcRect:Rect;
   MouseLoc,LastMouseLoc,tPt:Point;
   ExitToAnimate:boolean;
   MaxMove:Point;

procedure MakeBitMap(var theMap:Bitmap);{create a bitmap record}
{assumes that 'theMap.bounds' is predefined rect for size and
does NO error checking for available memory or MemErr..}
Begin
   {following same as OffsetRect(theMap.bounds,-left,-top)}
   theMap.bounds.right := theMap.bounds.right-theMap.bounds.left;
   theMap.bounds.left := 0;
   theMap.bounds.bottom := theMap.bounds.bottom-theMap.bounds.top;
   theMap.bounds.top := 0;

   {now with 0,0 origin.. '.right' is width, and '.bottom' is height}
   theMap.rowbytes := (((theMap.bounds.right - 1) DIV 16) + 1) * 2;
   {size of bitimage is bottom times rowBytes, potential MemError here}
   theMap.baseAddr := NewPtr(theMap.bounds.bottom * theMap.rowbytes);
End;

Begin {procedure dragPiece}
   SetPt(MaxMove,20,20);{piece will move max. of 20 pixels per loop}
   {create temp. bitmaps, size Combo for MaxMove}
   PicMap.bounds := PieceRgn^^.rgnBBox;{size to contain the region}
   MakeBitMap(PicMap);{create the bitmap record.. must define .bounds first}
   PatchMap.bounds := PicMap.bounds;{same size}
   MakeBitMap(PatchMap);

   ComboMap.bounds := PatchMap.bounds;
   {increase size to accomodate extra for drawing background/union }
   ComboMap.bounds.right := ComboMap.bounds.right + MaxMove.h;
   ComboMap.bounds.bottom := ComboMap.bounds.bottom + MaxMove.v;
   MakeBitMap(ComboMap);

   tRgn := NewRgn;
   CopyRgn(PieceRgn,tRgn);{make a temp. copy for use in drawing}

   {_________ PicMap must contain image to be 'dragged' ______}
   {we're just going to 'fill' the PieceRgn for this example, this bitmap
   could be passed as a parameter.}
   OldBits := aWindow^.portBits;
   SetPortBits(PicMap);{so we can quickdraw 'piece' into the PicMap}
   tRect := aWindow^.portRect;
   InsetRect(tRect,-50,-50);{in case mouse is near edge of window,clipping}
   ClipRect(tRect);
   SetOrigin(tRgn^^.rgnBBox.left,tRgn^^.rgnBBox.top);
   EraseRect(tRgn^^.rgnBBox);{erase to white first}
   FillRgn(tRgn,gray);
   FrameRgn(tRgn);
   SetOrigin(0,0);
   SetPortBits(OldBits);
   {__________________________}

   {____ initialize PatchMap, will be background under piece _____}
   {restore, erase or draw initial BackGround under piece to PatchMap}
   SetPortBits(PatchMap);{so we can quickdraw into the PatchMap}
   {make the PatchMap topleft = to PieceRgn topleft for drawing, so
   that the correct stuff is drawn into PatchMap for Piece location
   in aWindow!}
   SetOrigin(PieceRgn^^.rgnBBox.left,PieceRgn^^.rgnBBox.top);
   EraseRect(PieceRgn^^.rgnBBox);{erase whole thing to white first}
   {note: SetOrigin effects the aWindow^.portRect!!}
   DrawWindowContents(aWindow);{draw window just like update event...}
   SetOrigin(0,0);{restore normal origin}
   SetPortBits(OldBits);
   {___________________________}

   LastsRect := tRgn^^.rgnBBox;{last location in aWindow!}
   sRect := LastsRect;{initialize sRect for size}
   cRect := sRect;
   LastMouseLoc := theMouse;{this is where user clicked}
   MouseLoc := LastMouseLoc;
   MouseLoc.h := MouseLoc.h + 1;{this will force redraw thru first loop}
   Repeat { the entire process Until a MouseUp}
   {determine If the mouse has moved and how much}
      ExitToAnimate := false;{will flag mouse movement, need to draw stuff}
      Repeat {wait for mouse move or mouse up}
         {keep the piece on screen}
         If not (PtInRect(MouseLoc,DragRect)) then Begin {move it back in}
               If MouseLoc.h > DragRect.right then
                  MouseLoc.h := DragRect.right
               Else If MouseLoc.h < DragRect.left then
                  MouseLoc.h := DragRect.left;
               If MouseLoc.v > DragRect.bottom then
                  MouseLoc.v := DragRect.bottom
               Else If MouseLoc.v < DragRect.top then
                  MouseLoc.v := DragRect.top;
            End;
         tPt.h := MouseLoc.h - LastMouseLoc.h;{tPt is offset requested}
         tPt.v := MouseLoc.v - LastMouseLoc.v;
         If (tPt.h <> 0) OR (tPt.v <> 0) then Begin {must have moved so animate}
               {tPt move must be less than MaxMove}
               If tPt.h > MaxMove.h then tPt.h := MaxMove.h
               Else If tPt.h < -MaxMove.h then tPt.h := -MaxMove.h;

               If tPt.v > MaxMove.v then tPt.v := MaxMove.v
               Else If tPt.v < -MaxMove.v then tPt.v := -MaxMove.v;

               {slide sRect to new location by tPt offset}
               sRect.left := sRect.left + tPt.h;
               sRect.right := sRect.right + tPt.h;
               sRect.top := sRect.top + tPt.v;
               sRect.bottom := sRect.bottom + tPt.v;

               {LastMouse is moved to the 'adjusted' location}
               LastMouseLoc.h := tPt.h + LastMouseLoc.h;
               LastMouseLoc.v := tPt.v + LastMouseLoc.v;
               ExitToAnimate := True;{TML users can do a 'Leave' here!}
            End;{If (abs..}
         GetMouse(MouseLoc);
      Until (not(StillDown) or ExitToAnimate);

      {combine/union the Last and new sRects, in the aWindow/screen}
      UnionRect(LastsRect,sRect,sUnionRect);
      LastcRect := LastsRect;{copy the sRects to cRects in ComboMap}
      cRect := sRect;
      cUnionRect := sUnionRect;

      {offset/slide all the cRects (combo) rects so cUnion is topleft}
      LastcRect.right := LastcRect.right-cUnionRect.left;
      LastcRect.left := LastcRect.left-cUnionRect.left;
      LastcRect.bottom := LastcRect.bottom-cUnionRect.top;
      LastcRect.top := LastcRect.top-cUnionRect.top;
      cRect.right := cRect.right-cUnionRect.left;
      cRect.left := cRect.left-cUnionRect.left;
      cRect.bottom := cRect.bottom-cUnionRect.top;
      cRect.top := cRect.top-cUnionRect.top;
      cUnionRect.right := cUnionRect.right-cUnionRect.left;
      cUnionRect.left := cUnionRect.left-cUnionRect.left;
      cUnionRect.bottom := cUnionRect.bottom-cUnionRect.top;
      cUnionRect.top := cUnionRect.top-cUnionRect.top;

      {copy current screen Union to ComboMap}
      CopyBits(aWindow^.portBits,ComboMap,sUnionRect,
                                          cUnionRect,srcCopy,NIL);

      {copy patch over last in combo.. will restore previous background}
      CopyBits(PatchMap,ComboMap,PatchMap.bounds,LastcRect,srcCopy,NIL);

      CopyBits(ComboMap,PatchMap,cRect,PatchMap.bounds,srcCopy,NIL);

      {copy the piece into new location in Combo}
      {move the tRgn to cRect to mask drawing into the Combo map}
      OffSetRgn(tRgn,cRect.left - tRgn^^.rgnBBox.left,
                                    cRect.top - tRgn^^.rgnBBox.top);
      Copybits(PicMap,ComboMap,PicMap.bounds,cRect,srcCopy,tRgn);

      {copy Combo union to screen}
      CopyBits(ComboMap,aWindow^.portBits,cUnionRect,
                                                sUnionRect,srcCopy,NIL);

      LastsRect := sRect;{remember where the last piece is drawn}
   Until (not(StillDown));{Until the mouse button is released,i-259}

   {________ optional to erase the piece or leave it, etc. _____}
   {we'll restore the patch of background over the piece... erasing it}
   CopyBits(PatchMap,aWindow^.portBits,PatchMap.bounds,sRect,srcCopy,nil);
   {____________________}

   theMouse := LastMouseLoc;{return last mouse location to caller}
   DisposPtr(PatchMap.baseAddr);{dispose of temp stuff in heap}
   DisposPtr(ComboMap.baseAddr);
   DisposPtr(PicMap.baseAddr);
   DisposeRgn(tRgn);
End;{DragPiece procedure}

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
   with Screen do Begin
         SetRect(DragArea,Left+4,Top+24,Right-4,Bottom-4);
         SetRect(GrowArea,Left,Top+24,Right,Bottom);
      End;
End;

procedure CreateWindow;
Begin
   SetRect(tRect,2,40,508,40 + 290);
   myWindow := NewWindow(Nil,tRect,'DragPiece Demo',True,4,Nil,True,0);
   SetPort(myWindow);
   ClipRect(myWindow^.portRect);
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
      fileMenu: Finished := True;
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
            SelectWindow (WhichWindow)
         else Begin
               GlobalToLocal(MouseLoc);
               SetRect(tRect,MouseLoc.h-20,MouseLoc.v-26,
                                 MouseLoc.h+20,MouseLoc.v+26);
               DragRgn := NewRgn;
               OpenRgn;
               FrameOval(tRect);
               CloseRgn(DragRgn);

               tRect := WhichWindow^.portRect;
               DragPiece(WhichWindow,MouseLoc,tRect,DragRgn);
            end;
      inGoAway:
         Finished := True;
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
   EventAvail: Boolean;
Begin
   InitCursor;
   Repeat
      SystemTask;
      EventAvail := GetNextEvent(EveryEvent,myEvent);
      If EventAvail then
         Case myEvent.What of
            mouseDown:  TakeCareMouseDown(myEvent);
            KeyDown:    Finished:= True;
            ActivateEvt:TakeCareActivates(myEvent);
            UpDateEvt:  TakeCareUpdates(myEvent);
         End;
   Until Finished;
End;

procedure SetUpMenus;
var
   i: integer;
Begin
   myMenus[1] := GetMenu(appleMenu);  {get menu info from resources}
   myMenus[2] := GetMenu(fileMenu);
   For i := 1 to lastMenu do InsertMenu(myMenus[i],0);
   DrawMenuBar;
End;

{Main Program begins here}
BEGIN
   InitThings;
   MaxApplZone;
   SetUpMenus;
   CreateWindow;

   {set destination for bottom right of our logo picture}
   SetPt(LogoLoc,myWindow^.portRect.right-20,myWindow^.portRect.bottom-20);

   MainEventLoop;{until finished = true}
END.
