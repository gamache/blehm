Program aRegions;{Sun Aug 23, 1987 09:19:36}
{version 0.87,copyright ©,1987...Duane Blehm,HomeTown Software}

USES MacIntf;

{$T APPL RDBN set the TYPE and CREATOR}
{$B+ set the application's bundle bit }
{$L aRegions.rsrc}{link resource file stuff}

CONST
   lastMenu = 4; {Number of Menus}
   appleMenu = 1;
   fileMenu = 256;
   editMenu = 257;
   optionsMenu = 258;

TYPE
   {type the dialogs so we can access by name and add to list}
   DialogList = (Save,Help,SizeTheRgn,About,HowTo,Source);

VAR
   tRgn:                RgnHandle; {temporary region,used to Invert DemoRgn}
   tStr:                Str255;
   myPattern:           Pattern; {will hold the background pattern}
   DemoRgn:          RgnHandle; {region to be used in demo animation}
   DemoUnderWay:        Boolean; {flag if demo is underway}
   i:                   integer;
   Demo,InvertDemo:  ControlHandle; {Rgn Demo and Invert It! buttons}
   OffScreen:           BitMap; {contains our offscreen MacPic image}
   MacPic:              PicHandle; {for loading PICT resource}
   WorkRefNum:       integer; {work resource file RefNum}
   alertResult:         integer; {result of putting up Alert dialogs}
   DisplayStatus:    integer; {what's on display,0 = nothing,1 = pic,2 = rgn}
   DialNdx:          DialogList; {will step through our dialogs array}
   myDialog:            Array[Save..Source] of DialogPtr;{our 'dialogList'}
   myDialogRec:         Array[Save..Source] of DialogRecord;

   WorkRect:            Rect; {'work'ing/drawing area of myWindow,left side}
   CreateRgn,SaveRgn:   ControlHandle; {Create Rgn,Save Rgn buttons}
   myPic:               PicHandle; {Handle to Pic pasted in from Clipboard}
   PicRect:          Rect; {Rect for offsetting/Drawing myPic}
   DemoBox:          Rect; {Bounds for movement of demo animation}
   myRgn:               RgnHandle; {Region created by alogrithm}
   RgnFrame,            {Rect limits for FindRegion call...}
   tRect:               Rect;
   length,offSet,
   theErr:              Longint;

   myMenus:          Array[1..lastMenu] of MenuHandle;
   refNum,theMenu,
   theItem:          integer;{menustuff}
   Finished:            Boolean;{used to terminate the program}
   ClockCursor:         CursHandle; {handle to watch cursor}
   myWindow:            WindowPtr;
   wRecord:          WindowRecord;
   Screen,DragArea,
   GrowArea:            Rect;

{----------------------------------------------}
procedure AnimateDemo;
{animate the mac image clipped to DemoRgn}
var
   tPoint:Point;
   dh,dv:integer;
Begin
   GetMouse(tPoint);{get current mouse coordinates}

   {limit mac image (PicRect) to DemoBox extremes..}
   {to keep PicRect from wondering off our visual area}

   If not(PtInRect(tPoint,DemoBox)) then begin {force tPoint into DemoBox}
      If tPoint.h > DemoBox.right then tPoint.h := DemoBox.right
         else if tPoint.h < DemoBox.left then tPoint.h := DemoBox.left;
      If tPoint.v > DemoBox.bottom then tPoint.v := DemoBox.bottom
         else if tPoint.v < DemoBox.top then tPoint.v := DemoBox.top;
      end;

   {determine horizontal offset if needed}
   If tPoint.h > PicRect.left + 2 then begin
         PicRect.left := PicRect.left + 3;{offsetRect to right}
         PicRect.right := PicRect.right + 3;
      end
   else if tPoint.h < PicRect.left - 2 then begin
         PicRect.left := PicRect.left - 3;{offsetRect to left}
         PicRect.right := PicRect.right - 3;
      end;
   {vertical offset?}
   If tPoint.v > PicRect.top + 1 then begin
         PicRect.top := PicRect.top + 2; {only move 2 because of pattern}
         PicRect.bottom := PicRect.bottom + 2;
      end
   else if tPoint.v < PicRect.top - 1 then begin
         PicRect.top := PicRect.top - 2; {only move 2 because of pattern}
         PicRect.bottom := PicRect.bottom - 2;
      end;

   {ok... now draw it using the DemoRgn as a mask}
   CopyBits(OffScreen,myWindow^.portBits,OffScreen.bounds,
                                                PicRect,srcCopy,DemoRgn);
end;

procedure CreateOffScreenBitMap; {see CopyBits stuff,also tech.note 41}
var
   tRect: Rect;
   OffRowBytes,SizeOfOff:integer;
   OldBits:Bitmap;
Begin
   MacPic := GetPicture(128);{load the Mac picture from resource file}
   tRect := MacPic^^.picframe;{size tRect for creating offscreen}

   {calculate size/dimensions of OffScreen stuff}
   with tRect do begin
      OffRowBytes := (((right - left -1) div 16) +1) * 2;{has to be even!}
      SizeOfOff := (bottom - top) * OffRowBytes;
      OffSetRect(tRect,-left,-top);{move rect to 0,0 topleft}
   end; { of with }

   OffScreen.baseAddr := QDPtr(NewPtr(SizeOfOff));{Create BitImage with Ptr}
   OffScreen.rowbytes := OffRowBytes;{bytes / row in BitImage}
   OffScreen.bounds := tRect;

   {draw the Mac Picture into OffScreen}
   OldBits := myWindow^.portBits;   {preserve old BitMap}
   SetPortBits(OffScreen);             { our new BitMap }
   FillRect(OffScreen.bounds,white);      {erase our new BitMap to white}
   DrawPicture(MacPic,OffScreen.bounds); {draw all the pictures}
   ReleaseResource(handle(MacPic)); {done so dump picture from memory}

   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure InitialDemo;{set up stuff for Demo Regions animation}
var
   dh,dv,myErr:integer;
begin
   myErr := noErr;{myErr will flag a resource loading error}
   If DisplayStatus = 2 then begin {use the current rgn in the demo}
         DemoRgn := NewRgn;{Create a fresh DemoRgn, disposed of the last}
         CopyRgn(myRgn,DemoRgn);{Copy of current myRgn into DemoRgn}
      end
   else begin {no current myRgn so we'll load our own in from resources}
         DemoRgn := RgnHandle(GetResource('RGN ',20843));
         myErr := ResError;{check for loading error}
         DetachResource(Handle(DemoRgn));{take control from resource Manager}
      end;
   If myErr = noErr then begin {continue if no errors where encountered}
      DemoUnderWay := True;{flag Demo animation in MainEventLoop}
      {disable menus, other controls}
      HiliteControl(CreateRgn,255);{disable}
      HiliteControl(SaveRgn,255);{disable}
      ShowControl(InvertDemo);
      DisableItem(myMenus[4],2);{size the Rgn}
      For i := 1 to LastMenu do DisableItem(myMenus[i],0);{disable menus}
      DrawMenuBar;
      SetCTitle(Demo,'End Demo');{so user can end the demo}
      EraseRect(WorkRect);{erase the work area of window}
      {find offsets to relocate DemoRgn in center of work area}
      with DemoRgn^^.rgnBBox do begin
         dh := ((WorkRect.right-(right-left)) div 2) - left;
         dv := ((WorkRect.bottom-(bottom-top)) div 2) - top;
      end;
      OffSetRgn(DemoRgn,dh,dv);{center the rgnBBox}
      FillRgn(DemoRgn,myPattern);{pattern of horizontal lines}
      FrameRgn(DemoRgn);{outline the Rgn}
      InsetRgn(DemoRgn,1,1);{so the animation won't erase Frame lines}
      DemoBox := DemoRgn^^.rgnBBox;{DemoBox will limit movement of PicRect}
      InsetRect(DemoBox,-120,-80);{expand beyond the Rgn a little}
      PicRect := OffScreen.bounds;{Size PicRect for CopyBits}

      {we'll use Mouse location and PicRect.topleft to offset PicRect
      so subtract width and height of PicRect from DemoBox limits}
      DemoBox.right := DemoBox.right - (PicRect.right - PicRect.left);
      DemoBox.bottom := DemoBox.bottom - (PicRect.bottom - PicRect.top);

      If not(odd(DemoBox.top)) then inc(DemoBox.top);{force odd for pattern}

      {start the PicRect in upper left of DemoBox}
      OffSetRect(PicRect,DemoBox.left-PicRect.left,DemoBox.top-PicRect.top);
   end
   else begin
      alertResult := NoteAlert(134,nil);{sorry, bad resource}
      ResetAlrtStage;
   end;
end;

procedure DisplayDialog(WhichDialog:DialogList);
var
   tRect,fRect:   Rect;
   itemHit,i,j,tIDNum,RepeatID,count: integer;
   tPort: GrafPtr;
   tHandle,nameHand,tbuf:Handle;
   tStr,nameStr:Str255;
   aLong:Longint;
   tFlag:boolean;
   theType:ResType;
Begin
   GetPort(tPort);{save the current port}
   ShowWindow(myDialog[WhichDialog]);
   SelectWindow(myDialog[WhichDialog]);
   SetPort(myDialog[WhichDialog]);  {we may draw into our dialog window}

   Case WhichDialog of

   HowTo:begin {text for how to use a 'RGN ' resource}
      TextFont(geneva);
      Textsize(10);
      tbuf := GetResource('TBUF',128);{text created with our TransText utility}
      HLock(tbuf);{lock it we'll be using ptr's}
      TextBox(tbuf^,GetHandleSize(tBuf),myDialog[HowTo]^.portRect,teJustLeft);
      HUnLock(tBuf);{done}
      ModalDialog(Nil,itemHit);
      end;

   Source:begin {text for Source code offer}
      TextFont(geneva);
      Textsize(10);
      tbuf := GetResource('TBUF',129);
      HLock(tbuf);
      TextBox(tbuf^,GetHandleSize(tBuf),myDialog[Source]^.portRect,teJustLeft);
      HUnLock(tBuf);{done}
      ModalDialog(Nil,itemHit);
      end;

   About:ModalDialog(nil,itemHit); {put up our about Regions dialog}

   SizeTheRgn:{user input data for doing an InsetRgn call}
      Repeat
         SelIText(myDialog[SizetheRgn],5,0,32767);{select horiz.size text}
         ModalDialog(nil,itemHit);
         If itemHit = 1 then Begin {size the rgn}
               GetDItem(myDialog[SizetheRgn],5,i,tHandle,tRect);{Handle textitem}
               GetIText(tHandle,tStr);{get the horiz. size text}
               StringToNum(tStr,aLong);{convert to Number,error check?}
               i := aLong;{horiz.size}
               GetDItem(myDialog[SizetheRgn],6,j,tHandle,tRect);{vertical size}
               GetIText(tHandle,tStr);
               StringToNum(tStr,aLong);
               j := aLong;
               InsetRgn(myRgn,i,j);
               DisplayStatus := 2;{so InvalRect 'update' will draw the region}
            end;
      Until((itemHit = 1) or (itemhit = 7));{size or cancel}

   Help:ModalDialog(nil,itemHit);{help dialog box}

   Save: Begin {save myRgn into our work resource file}
         nameStr := 'myRegion';{set default Res. name}
         Repeat
            {get a 'unique' resID number > 128}
            Repeat
               tIDNum := UniqueID('RGN ');
            Until(tIDNum > 127);
            {install resID in item 4, name in item 3}
            NumToString(tIDNum,tStr);
            GetDItem(myDialog[Save],4,i,tHandle,tRect);
            SetIText(tHandle,tStr);{set res Id to unique ID}
            SelIText(myDialog[Save],4,0,32767);{select the res Id text}
            GetDItem(myDialog[Save],3,i,nameHand,tRect);
            SetIText(nameHand,NameStr);
            ModalDialog(Nil,itemHit);  {close it no matter what was hit}
            Case itemHit of
            1:{add it} begin
                  {get,check name and id, watch out for duplicates}
                  GetIText(nameHand,nameStr);{nameString}
                  GetIText(tHandle,tStr);
                  StringtoNum(tStr,aLong);
                  tIdNum := aLong;

                  {check for resource using tIDNum as ID#}
                  count := CountResources('RGN ');{how many rgns}
                  tFlag := True;{initial flag for duplicate Id numbers}
                  If Count > 0 then {if there any RGN'S}
                     For i := 1 to count do begin {step thru 'RGN ' resources}
                           tHandle := GetIndResource('RGN ',i);
                           GetResInfo(tHandle,j,theType,tStr);
                           If j = tIdNum then tFlag := false;{id already exists!}
                        end;

                  If tFlag then begin     {unique id, so save it}
                        UseResFile(WorkRefNum);
                        AddResource(Handle(myRgn),'RGN ',tIdNum,nameStr);
                        UpdateResFile(WorkRefNum);
                     end
                  Else begin {id alreay used, alert user, Replace it?}
                        alertResult := CautionAlert(128,nil);
                        ResetAlrtStage;
                        If alertResult = 1 then begin {replace old with new}
                              {tIDNum is the repeated ID no.!}
                              tHandle := GetResource('RGN ',tIdNum);{handle to old}
                              RmveResource(tHandle);{remove the old}
                              UseResFile(WorkRefNum);{our Work file}
                              AddResource(Handle(myRgn),'RGN ',tIdNum,nameStr);
                              UpDateResFile(WorkRefNum);{force write of new}
                           end
                        else itemHit := 0;{Cancel,reset itemhit so won't exit Save:}
                     end;{else}
               end;{1:}

            end;{case itemhit}
         Until((itemHit = 1) or (itemHit = 2));
      end;{Save:}
   end;{Case WhichDialog}

   HideWindow(myDialog[WhichDialog]);  {put away dialog window}
   SelectWindow(myWindow);{restore our game window}
   SetPort(tPort);{restore port}
   InvalRect(WorkRect);{force redraw of 'whole' work area.. new Rgn?}
end;

procedure FindRegion(tRect:Rect;var theRgn:RgnHandle);
{be sure that tRect is in visible window on screen before executing this
procedure to avoid system crash}
var
   x,y:integer;
   ExitNoBlack: Boolean;
   Vector,LineVector,ExitStatus:integer;
   Original:Point;
   SizeCount:integer;
Begin
   SetEmptyRgn(theRgn);{in case we have to abort, will return empty}
   {scanning by 'pixels' with GetPixel() ... 'pixel' is right and left
   of the 'Coordinate' so move inside 1 coordinate}
   dec(tRect.right);
   dec(tRect.bottom);
   x := tRect.left;{we'll begin in topleft, looking for topleftmost black pixel}
   y := tRect.top;
   {find upper left black pixel}
   ExitNoBlack := false;
   While ((not GetPixel(x,y)) and (not ExitNoBlack)) do
      Begin
         If x < tRect.right then inc(x) {move right on line}
         else begin {move down to next line}
            x := tRect.left;{reset x to left side of line}
            If y < tRect.bottom then inc(y)
            else ExitNoBlack := true;     {exit!,didn't find any black pixels}
            end;{else}
      end;{while}

   If not(ExitNoBlack) then begin {have a Black pixel..x,y so start region}
      OpenRgn;
      SetPt(Original,x,y);    {keep track of starting point}
      MoveTo(x,y);

      LineVector := 1;{track direction of line, won't LineTo() until it changes}
      Vector := 1;      {first vector is down (1)}
      inc(y);{move coordinates to next}
      ExitStatus := 0;{1 = 'Original' found, rgn complete, 2 = rgn too large}
      SizeCount := 0;{count LineTo's for size of region,avoid overflow}

      {from Original begin 'counterclockwise' circuit around Black pixel border}
      Repeat
         Case Vector of {case 'last vector move' of.. get next vector}
         1: Begin {last vector move was down}
               {if pixel left and below is black then move left}
               If GetPixel(x-1,y) then Vector := 4

               {if not, then check pixel right and below... move down}
               else If GetPixel(x,y) then Vector := 1
                     {if not, then must be pixel right and above... move right}
                     else Vector := 2;
            end;
         2: Begin {last was right}
               If GetPixel(x,y) then Vector := 1
               else If GetPixel(x,y-1) then Vector := 2
                     else Vector := 3;
            end;
         3: Begin {last was move up}
               If GetPixel(x,y-1) then Vector := 2
               else If GetPixel(x-1,y-1) then Vector := 3
                     else Vector := 4;
            end;
         4: Begin {last was move left}
               If GetPixel(x-1,y-1) then Vector := 3
               else If GetPixel(x-1,y) then Vector := 4
                     else Vector := 1;
            end;{of case 4:}
         End; {of case vector}

         If Vector <> LineVector then begin{new direction,end of current 'line'}
               SystemTask;{keep system happy?}
               LineTo(x,y);{include line into region}

               {sizeCount limits number of LineTo()'s, to avoid Stack crashes}
               If SizeCount < 4000 then inc(SizeCount) {we'll get another line}
               else begin {too much!, getting too big!.. abort the region}
                     ExitStatus := 2;{force exit of loop}
                     LineTo(Original.h,Original.v);{we'll show the Region}
                  end;

               LineVector := Vector;{start a new line}
            end;

         Case Vector of {we checked for new 'line',etc. so move coordinates}
         1:inc(y);{vector moves down}
         2:inc(x);{vector moves right}
         3:dec(y);{moves up}
         4:dec(x);{moves left}
         end;{case vector}

         If x = Original.h then {is the new Coordinate our 'Original'}
               If y = Original.v then begin
                     ExitStatus := 1;{finished if it is!,will force exit}
                     LineTo(x,y);{last line}
                  end;

      Until (ExitStatus <> 0);{until we get back to start or too large}

      CloseRgn(theRgn);{we're done so close the rgn}
      InitCursor;{in case of alerts}
      If ExitStatus = 2 then begin {display the abort rgn alert}
            alertResult := NoteAlert(136,nil);{rgn aborted too big}
            ResetAlrtStage;
         end;
      end {if not(Done)}
   else begin {display no black pix alert}
         InitCursor;{show arrow cursor for alert}
         alertResult := NoteAlert(135,nil);{no black pixels}
         ResetAlrtStage;
      end;
End;

procedure DrawWindowContents(WhichWindow:WindowPtr);
{Remember to SetPort first, response to update event}
var
   trect:Rect;
   i:integer;
   tRgn:RgnHandle;
   tStr:Str255;
Begin
   ClipRect(WorkRect);{limit drawing to WorkRect}
   Case DisplayStatus of
   1:Begin {picture on display}
         DrawPicture(myPic,PicRect);{draw clipboard picture}
      end;
   2:Begin {region on display}
         OffSetRgn(myRgn,5-myRgn^^.rgnBBox.left,5-myRgn^^.rgnBBox.top);
         FillRgn(myRgn,ltGray);
         FrameRgn(myRgn);{will appear same coords as pict}
      end;
   end;{case displayStatus}
   ClipRect(myWindow^.portRect);{set clip to window borders.. controls}
   MoveTo(WorkRect.right,WorkRect.top);{draw right work border line}
   LineTo(WorkRect.right,WorkRect.bottom);
   DrawControls(WhichWindow);
End;

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
   tRect: Rect;
Begin
   SetRect(tRect,2,24,508,338);{size the window}

   myWindow := NewWindow(@wRecord,tRect,'',True,2,Nil,True,0);

   SetRect(tRect,0,0,520,340);{size of clip rgn}
   For DialNdx := Save to Source do begin {read all the dialogs into array}
         myDialog[DialNdx] :=
               GetNewDialog(ord(DialNdx)+128,@myDialogRec[DialNdx],myWindow);
         SetPort(myDialog[DialNdx]);
         ClipRect(tRect);{set clip to smaller size..}
      end;

   SetPort(myWindow);
   ClipRect(tRect);

   SetRect(tRect,416,35,502,59);{size/location of 1st control button}
   CreateRgn := NewControl(myWindow,tRect,'Create Rgn',True,0,0,0,0,0);
   OffSetRect(tRect,0,36);
   SaveRgn := NewControl(myWindow,tRect,'Save Rgn',True,0,0,0,0,0);
   OffSetRect(tRect,0,36);
   Demo := NewControl(myWindow,tRect,'Rgn Demo',True,0,0,0,0,0);
   OffSetRect(tRect,0,36);
   InvertDemo := NewControl(myWindow,tRect,'Invert It!',False,0,0,0,0,0);
End;

procedure DoMenuCommand(mResult:LongInt);
var
   name: Str255;
   tPort: GrafPtr;
Begin
   theMenu := HiWord(mResult);
   theItem := LoWord(mResult);
   Case theMenu of
      appleMenu: Begin
            If theItem = 1 then DisplayDialog(About)
            Else begin
                  GetPort(tPort);
                  GetItem(myMenus[1],theItem,name);{must be a desk acc.}
                  refNum := OpenDeskAcc(name);
                  SetPort(tPort);
               end;
         End;
      fileMenu: Finished := True;
      editMenu:
         {if systemEdit returns false then process click at our end}
         If not(SystemEdit(theItem - 1)) then
            Case theItem of
            5:begin {paste}
               {call GetScrap and draw picture into window}
               length := GetScrap(Handle(myPic),'PICT',offset);
               If length < 0 then begin {no PICT type scrap available!}
                     alertResult := NoteAlert(129,nil);{sorry no picture}
                     ResetAlrtStage;
                  end
               else begin {we've got a picture waiting, 'paste' it}
                     PicRect := myPic^^.picframe;
                     OffSetRect(PicRect,5 - PicRect.left,5 - PicRect.top);
                     {check to see it picture is too large for work area}
                     If (PicRect.right > (WorkRect.right-6)) or
                           (PicRect.bottom > (WorkRect.bottom-6)) then Begin
                           {alert user... pic too large!}
                           alertResult := NoteAlert(130,nil);
                           ResetAlrtStage;
                           DisplayStatus := 0;{display nothing}
                           InvalRect(WorkRect);{force update redraw of work}
                        end
                     else begin {draw the scrap picture!}
                        EraseRect(WorkRect);
                        ClipRect(WorkRect);
                        DrawPicture(myPic,PicRect);
                        ClipRect(myWindow^.portRect);
                        RgnFrame := PicRect;
                        {enlarge by one pixel,to ensure white pixel border!}
                        InsetRect(RgnFrame,-1,-1);
                        DisplayStatus := 1;{flag picture on display}
                        HiliteControl(CreateRgn,0);{enable create a rgn}
                        HiliteControl(SaveRgn,255);{disable}
                        DisableItem(myMenus[4],2);{size}
                     end;{else}
                  end;{else}
               end;{5:}
               6:begin {clear to original start up status}
                     DisplayStatus := 0;
                     InvalRect(myWindow^.portRect);
                     HiliteControl(CreateRgn,255);
                     HiliteControl(SaveRgn,255);{disable}
                     DisableItem(myMenus[4],2);{size}
                  end;{6:}
               end;{case theitem}

      optionsMenu:
         Case theItem of
         1:DisplayDialog(Help);
         2:DisplayDialog(SizeTheRgn);
         3:DisplayDialog(HowTo);
         4:DisplayDialog(Source);
         end;{case theItem}
   End;
   HiliteMenu(0);{take hilite off menubar}
End;

procedure TakeCareControls(whichControl:ControlHandle;localMouse:point);
var
   ControlHit,i: integer;
   refnum:integer;
Begin
   ControlHit := TrackControl(whichControl,localMouse,nil); { Find out which}
   If ControlHit > 0 then  {i-417}
      Begin
         If whichControl = CreateRgn then Begin
               {handle a hit in the Create region button}
               SetCursor(ClockCursor^^);{while we work on the region}
               myRgn := NewRgn;
               FindRegion(RgnFrame,myRgn);
               DisplayStatus := 2;
               InvalRect(workRect);
               HiliteControl(CreateRgn,255);{disable}
               HiliteControl(SaveRgn,0);
               EnableItem(myMenus[4],2);{size rgn}
            End;
         If whichControl = SaveRgn then Begin
            DisplayDialog(Save);{will handle all the save stuff}
            end;
         If whichControl = Demo then begin {could be begin or end of demo!}
            If DemoUnderWay then begin {then end it}
                  DemoUnderWay := False;{stop the animation}
                  {enable menus, other controls}
                  SetCTitle(Demo,'Rgn Demo');
                  HideControl(InvertDemo);
                  InvalRect(WorkRect);
                  For i := 1 to LastMenu do EnableItem(myMenus[i],0);
                  DrawMenuBar;
                  DisposHandle(Handle(DemoRgn));{dump DemoRgn from memory}
                  If DisplayStatus = 2 then begin {still have a valid myRgn}
                        HiliteControl(SaveRgn,0);
                        EnableItem(myMenus[4],2);{size rgn}
                     end
                  else DisplayStatus := 0;{won't preserve picture?}
               end {if demoUnderway begin}
            else InitialDemo; {start the demo}
            end;{if whichcontrol}
         If whichControl = InvertDemo then Begin {invert the region}
               FillRgn(DemoRgn,white);{fill with white, will erase pattern,etc.}
               FrameRgn(DemoRgn);{frame is just 'inside' the rgn}
               RectRgn(tRgn,WorkRect);{tRgn of WorkRect}
               DiffRgn(tRgn,DemoRgn,DemoRgn);{DemoRgn out of tRgn,new in DemoRgn}
               FillRgn(DemoRgn,myPattern);{Fill new DemoRgn with horz.lines}
               HideControl(InvertDemo);{we can't invert it again.. so hide button}
            end;
   End; {of If ControlHit}
End; { of procedure}

procedure TakeCareMouseDown(myEvent:EventRecord);
var
   Location: integer;
   WhichWindow: WindowPtr;
   MouseLoc: Point;
   WindowLoc: integer;
   ControlHit: integer;
   WhichControl:ControlHandle;
Begin
   MouseLoc := myEvent.Where;  {Global coordinates}
   WindowLoc := FindWindow(MouseLoc,WhichWindow);  {I-287}
   case WindowLoc of
      inMenuBar:
         DoMenuCommand(MenuSelect(MouseLoc));
      inSysWindow:
         SystemClick(myEvent,WhichWindow);  {I-441,scrapbook,etc.}
      inContent:
         If WhichWindow <> FrontWindow then
            SelectWindow(WhichWindow) {bring window to front}
         else Begin {check for hit in control buttons}
               GlobaltoLocal(MouseLoc);
               ControlHit := FindControl(MouseLoc,whichWindow,whichControl);
               If ControlHit > 0 then TakeCareControls(whichControl,Mouseloc);
            end;
   end; {case of}
end; { TakeCareMouseDown  }

procedure TakeCareActivates(myEvent:EventRecord);
var
   WhichWindow: WindowPtr;
Begin
   WhichWindow := WindowPtr(myEvent.message);
   If odd(myEvent.modifiers) then begin {becoming active}
         SetPort(WhichWindow);
         {disable undo,cut,copy}
         DisableItem(myMenus[3],1);
         DisableItem(myMenus[3],3);
         DisableItem(myMenus[3],4);
      end
   else begin {deactivated must be desk accessory}
         {enable all the Edit stuff}
         For i := 1 to 6 do EnableItem(myMenus[3],i);{for DA's}
      end;
End;

procedure TakeCareUpdates(Event:EventRecord);
var
   UpDateWindow,TempPort: WindowPtr;
Begin
   UpDateWindow := WindowPtr(Event.message);
   GetPort(TempPort);
   SetPort(UpDateWindow);
   BeginUpDate(UpDateWindow);
   EraseRect(UpDateWindow^.portRect);
   DrawWindowContents(UpDateWindow);
   EndUpDate(UpDateWindow);
   SetPort(TempPort);
End;

procedure TakeCareKeyDown(Event:EventRecord);
Var
    KeyCode,i: integer;
    CharCode: char;
Begin
   { KeyCode := LoWord(BitAnd(Event.message,keyCodeMask)) div 256; not used }
   CharCode := chr(LoWord(BitAnd(Event.message,CharCodeMask)));

   If BitAnd(Event.modifiers,CmdKey) = CmdKey then begin
      {key board command - probably a menu command}
      DoMenuCommand(MenuKey(CharCode));
      end;
End;

procedure MainEventLoop;
var
   myEvent: EventRecord;
   EventAvail: Boolean;
Begin
   InitCursor;
   Repeat
      SystemTask;
      If GetNextEvent(EveryEvent,myEvent) then
         Case myEvent.What of
            mouseDown:     TakeCareMouseDown(myEvent);
            KeyDown:    TakeCareKeyDown(myEvent);
            ActivateEvt:   TakeCareActivates(myEvent);
            UpDateEvt:     TakeCareUpdates(myEvent);
         End
      else If DemoUnderWay then AnimateDemo;{animate one step of demo}
   Until Finished;
End;

procedure SetUpMenus;
var
   i: integer;
Begin
   myMenus[1] := GetMenu(appleMenu);  {get menu info from resources}
   AddResMenu(myMenus[1],'DRVR'); {add in all the DA's}
   myMenus[2] := GetMenu(fileMenu);
   myMenus[3] := GetMenu(editMenu);
   myMenus[4] := GetMenu(optionsMenu);
   DisableItem(myMenus[4],2);{size region}
   For i := 1 to lastMenu do
      begin
         InsertMenu(myMenus[i],0);
      end;
   DrawMenuBar;
End;

procedure CloseStuff;
Begin
   {always kill sound i/o before quit}
   CloseResFile(WorkRefNum);{close work resource file}
End;

{Main Program begins here}
BEGIN
   InitThings;
   MaxApplZone;{grow application zone to max... Scrapbook uses appl.heap}
   theErr := ZeroScrap;{initialize the Scrap, erases any existing scrap, i-458}
   SetUpMenus;
   CreateWindow;
   CreateOffScreenBitMap;
   myPic := picHandle(NewHandle(0));{create valid handle for GetScrap call}
   myRgn := NewRgn;{create the rgns}
   tRgn := NewRgn;
   WorkRect := myWindow^.portRect;{size the work area of window}
   WorkRect.right := 410;
   DisplayStatus := 0;{nothing is on display}
   HiliteControl(CreateRgn,255);{disable}
   HiliteControl(SaveRgn,255);{disable}
   CreateResFile('RgnWork.rsrc');{no action if it already exists}
   {will be created in same folder as Regions application?}
   WorkRefNum := OpenResFile('RgnWork.rsrc');{open for action.. save}
   DemoUnderWay := false;{no demo to start}
   GetIndPattern(myPattern,sysPatListID,25);{horiz.line pattern in systemfile}
   MainEventLoop;
   CloseStuff;
END.
