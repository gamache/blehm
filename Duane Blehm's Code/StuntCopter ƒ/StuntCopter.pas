Program StuntCopter;{Copyright © 1986,1987 by Duane Blehm, All Rights Reserved}

{ Version 1.5 ,drag-able window, speed selection dialog for faster Macs}

{note: we increased the speed of StuntCopter 20% by NOT expanding window
beyond edge of screen... must have something to do with Clipping}
{Our window is using our custom WDEF..Window definition resource, it only
has ability to drag,draw and calcRegions..no close,etc. just poke
(16 * Resource ID) into window template ProcID}

{Format note: 'tabs' for this text should be set to '3'}
{StuntCopter animation is based on the CopyBits procedure.  The various shapes
are loaded from three PICT resources and drawn into an OffScreen bitmap.
See Apple Tech Note #41 - 'Drawing into an OffScreen Bitmap'.  Access
to these shapes is thru various Rectangles that describe their
position in the OffScreen bitmap.  The destination OnScreen for the shape is an
identically sized rectangle that has been positioned (OffSetRect procedure)
to receive the drawing.

Note: to move a given rectangle 'myRect' from its present location
(Current) to another location (Destination) the following is used throughout
this program...

   OffsetRect(myRect,Destination.h - Current.h,Destination.v - Current.v);
or
   OffsetRect(myRect,DestRect.left - myRect.left,DestRect.top - myRect.top);

Copter control is based around the MapPt procedure... by 'Mapping' the mouse
coordinates into a Rectangle (DeltaRect) sized according to the extreme
Copter moves in any direction. Shapes must have white borders equal to
these extreme coordinates because the next shape erases the previous by drawing
over it.:

   -3  x  x  x  x  x  x  x  x  x
   -2  x  x  x  x  x  x  x  x  x
   -1  x  x  x  x  x  x  x  x  x
    0  x  x  x  x  x  x  x  x  x       <<DeltaRect for finding copter offset
    1  x  x  x  x  x  x  x  x  x
    2  x  x  x  x  x  x  x  x  x
    3  x  x  x  x  x  x  x  x  x
    4  x  x  x  x  x  x  x  x  x
      -4 -3 -2 -1  0  1  2  3  4

The call to MapPt() returns a Point within the DeltaRect... which represents the
request from the player for the offSet to the next copter position.  In order
to smooth changes the Copter offset (Dh,Dv) will only change 1 unit per
animation loop.  The Copter tends toward the direction requested by the player
up to the Maximum Dh,Dv.}
{ comments like 'i-72' refer to page numbers in INSIDE MACINTOSH, i for
volume one, ii for two, etc.}
{About the clouds.... the clouds make extensive use of Regions.  Along with
three PICT resources, three regions have been added to the StuntCopter
resources of type 'RGN '.  These three regions are basically a 'lasso' of the
three clouds and were created in a separate program and then copied to the
resources via ResEdit.  The regions are used as a mask when the Clouds are
drawn to the screen and also as a mask when the copter is drawn so that there
is no flashing as one shape is drawn over the other.  The Cloud is drawn only
'inside' the cloud region and the copter is drawn everywhere 'outside' the
cloud region.  Only one cloud is floated at a time due to demands on processor
time.. the program gets bogged down if huge areas are being copied thru each
loop.. to enable just one cloud we've had to split duties.  Only the copter,
man and wagon are drawn each loop.  The Cross/yoke, Height and Clouds are
drawn every third loop.}

USES MacIntf; {used for TML version 2.0,instead of the 'includes' directive}

{$T APPL COPT set the TYPE and CREATOR}
{$B+ set the application's bundle bit }

{$L aSCopt.rsrc}  { Link resource file }

CONST
   WindResId = 128;  {Window Resource}
   CopterId = 128;      {PICT resources}
   ManId = 129;
   ScoreBoxId = 130;
   Cloud1 = 356;
   Cloud2 = 357;
   Cloud3 = 358;
   CRgn1 = 356;         {Cloud Regions as resources}
   CRgn2 = 357;
   CRgn3 = 358;
   StringID = 256;      {String List res.Id}
   HelpId = 129;        {Help Dialog resource Id}
   AboutId =130;        {About Stunt Dialog Resource id}
   lastMenu = 4;        {Number of Menus}
   lastString = 2;
   appleMenu = 1;
   fileMenu = 256;      {Menu Resource Id's}
   optionMenu = 257;
   messageMenu = 258;
   pressBegin = 129; {Control Resources}
   pressResume = 130;
   pressEnd = 131;
   pressLevel = 132;
   BackSpace = 8; { backspace charcode }
   Disable = 255; {disable button controls,i-322}
   Enable = 0;
   maxint = 32767;

TYPE
   RectGroup = Array[1..6] of Rect;   { for Score and HiScore }

VAR
   SpeedTrapOn:         Boolean;{we'll flag if user wants to slow down}
   SpeedFactor:         Longint;{duration of Delay for slowdowns}
   myMenus:             Array[1..lastMenu] of MenuHandle;
   refNum,theMenu,
   theItem:             integer;
   myStrings:           Array[1..lastString] of Str255;
   SoundOn:             Boolean;    {flag for sound off or on, a menu option}
   Finished:               Boolean;    {terminate the program}
   ClockCursor:         CursHandle; {handle to watch cursor}
   myWindow:            WindowPtr;  {our game window}
   HelpDialog:          DialogPtr;  {help dialog window}
   AboutDialog:         DialogPtr;  {about stunt... dialog window}
   SourceDialog,
   SpeedDialog,
   BitmapDialog:        DialogPtr;
   wRecord:             WindowRecord;
   dRecord:             DialogRecord;
   AboutdRecord:        DialogRecord;
   SrcRec,
   SpdRec,
   BitRec:                 DialogRecord;{source,speed & Bitmap dialogs}
   Screen,DragArea:  Rect;
   LastMouseUp:         LongInt;    {track mouseup info,test for double-click}
   WhereMouseUp:        point;
   Copter,Man,
   ScoreBox:               picHandle;  {Handles to 3 pictures, contain all shapes}
   OffScreen,OldBits:BitMap;     {for drawing into offscreen}
   SizeOfOff:           Size;       {Size offscreen bitmap}
   OffRowBytes:         Integer;
   CoptRect,ManRect,
   WagonRect,
   ScoreBoxRect,
   NumRect,ManInWagon,
   DriverRect,
   HorseRect:           Rect;       {onscreen destination rects for shapes}
   FlipRect,FlipFrame:  Array[1..2] of Rect;  { destination for flips}
   CoptNdx,ManNdx,
   WagonNdx:               Integer;    {Shape Index's,which shape to draw}
   WagonMoving:         Boolean;    {Is wagon moving or stopped?}
   Dh,Dv:                  Integer;    {Offset for Copter rectangle/shape}
   CopterBottomLimit:Integer;    {Can't fly below this point}
   CrossRect,
   OffCross,
   YokeLimits,
   YokeErase:           Rect;       {Rects for drawing Yoke into scorebox}
   YokeHt,YokeWdth,
   MouseHt,MouseWdth,
   OffsetHt,OffsetWdth,
   CrossHt,CrossWdth,
   DeltaHt,DeltaWdth,
   ManWdth,ManHt:    integer; {for finding next Rect for Cross/Yoke}
   maskRgn:             RgnHandle;  {mask out for yoke in scorebox}
   BorderRect,                      {limits of copter.topleft on screen}
   MouseRect,                       {limit mouse movement to this rect}
   DeltaRect:           Rect;       {map rect for copter control;dh,dv}

   {'source' rectangles,in offscreen bitmap}
   OffCopter:           Array[1..3] of Rect;
   OffMan:                 Array[1..14] of Rect;
   OffWagon:               Array[1..3] of Rect;
   OffScoreBox:         Rect;
   OffNum:                 Array[0..9] of Rect;
   OffFlip:             Array[1..15] of Rect;
   OffManInWagon:    Rect;
   OffDriver,OffHorse:  Rect;
   OffHeight:           Rect;
   HeightOfDrop,Score,
   Height,HiScore:      Longint;  {the sky's the limit...}
   MenLeft,GoodJumps,
   WagonSpeed,
   Gravity:             Integer;
   HeightStr:           Str255;     {drawn into scorebox}
   HeightPt:               Point;      {'moveto' location for HeightStr}
   ManStatus:     Integer; {0=drop 1=flip 2=splat 4=hang 8=hitdriver 9=hithorse}
   HtStatRect,
   WagStatRect,
   GravStatRect:        Rect; {rects in scorebox for height,wagonspeed,gravity}
   ScoreMan:               Array[1..5] of Rect;{man indicator in scorebox}
   ThumbUp:             Array[1..5] of Rect;    { boxes for thumbs up }
   ThumbDown:           Array[1..5] of Rect;
   ThumbState:          Array[1..5] of integer; {0=none 1=up 2=down}
   ScoreNum:               RectGroup;     { boxes to record score digits}
   HiScoreNum:          RectGroup;
   BeginButton,
   ResumeButton,
   EndButton,
   LevelButton:         ControlHandle; { handles to controlbuttons }
   LevelOnDisplay:      Boolean;       {is level button being shown?}
   LevelUnion:          RgnHandle; {used to mask levelbutton from copter drawarea}
   GameUnderWay:        Boolean;       {is game under way?}
   FlightRect:          Rect;          {window area less the scorebox stuff}
   WagonStatus:         Array[1..3] of Str255;  {wagonspeed to scorebox}
   GravityStatus:    Array[1..4] of Str255;  {gravity to scorebox}
   FlightRgn:           Array[1..4] of RgnHandle;{mask buttons from FlightRect}
   BeginRgn,EndRgn:  RgnHandle;
   Mask:                   integer;       {which mask is in use?}
   LevelTimer,                         {time how long to show levelbutton}
   aTick,speedTick:                 Longint;       {TickCount varible, sound delay}
   CurrentLevel,
   FlipCount:           integer;       {index flip and splat shapes}
   FlipTime:               Array[1..4] of integer; {duration for flip sounds}
   {cloudstuff}
   CloudPic:               Array[1..3] of PicHandle;{Cloud pictures}
   CloudRgn:               Array[1..3] of RgnHandle;{Cloud Regions}
   OffCloud:               Array[1..3] of Rect;{Cloud Rect's in offScreen}
   Cloud:                  Array[1..3] of Rect;{Destination Rects}
   CopterRgn:           RgnHandle;{will use to mask Copter CopyBits}
   tempRgn:             RgnHandle;
   CloudNdx:               integer;
   CloudOnDisplay:      Boolean; {for DrawUpdate to flag if cloud need be drawn}

   {Sound varibles}
   CoptBuff,SplatBuff:  Longint;       {Sound buffers}
   myPtr:                  Ptr;
   myHandle:            Handle;
   CoptSound,
   SplatSound:          FFSynthPtr;    {FreeForm synthesizer sound}
   FlipSynth:           FTSynthPtr;    {flip is a FourTone sound}
   FlipSound:           Array[1..4] of FTSndRecPtr;   {four FourTone Sounds}
   SoundParmBlk:        ParmBlkPtr;    {used for PBWrite instead of StartSound}
   WhichSound:          integer;       {which sound is being played?}
   err:                    OSerr;
   Squarewave:          wavePtr;

{**********************************************}

procedure LevelToButtonTitle(aLevel:integer);
{put level number into LevelButton title, 2 digits only}
var
   i:Longint;
   ButtonTitle: Str255;
   NumStr:Str255;
   Digit: Char;
Begin
   ButtonTitle := 'LEVEL ';
   Digit := chr(20);    {this is the 'apple'}
   i := aLevel;         {need a Longint for NumToString?}
   NumToString(i,NumStr);
   ButtonTitle := concat(ButtonTitle,Digit,NumStr);{put it all together}
   SetCTitle(LevelButton,ButtonTitle);
End;

procedure DrawWagonStatus;
   {gravity and wagonspeed into scorebox,each new level}
var
   h: integer;
Begin
   h := (WagStatRect.left + WagStatRect.right -
                              StringWidth(WagonStatus[WagonSpeed])) div 2;
   MoveTo(h,WagStatRect.bottom - 2); {locate string in center of rect}
   EraseRect(WagStatRect);
   DrawString(WagonStatus[WagonSpeed]);
   h := (GravStatRect.left + GravStatRect.right -
                              StringWidth(GravityStatus[Gravity])) div 2;
   MoveTo(h,GravStatRect.bottom - 2);
   EraseRect(GravStatRect);
   DrawString(GravityStatus[Gravity]);
End;

procedure DrawScoreIntoBox(aScore:Longint;WhereRect:RectGroup);
{given a score or hiscore write it into the scorebox, using number
shapes from offscreen bitmap}
var
   Digit:  Array[1..6] of integer; {index to offscreen number shapes}
   i: integer;
Begin
   Digit[6] := 0;    {one's digit always zero}
   Digit[5] := aScore mod 10;
   Digit[4] := (aScore div 10) mod 10;
   Digit[3] := (aScore div 100) mod 10;
   Digit[2] := (aScore div 1000) mod 10;
   Digit[1] := (aScore div 10000) mod 10;

   For i := 1 to 6 do      {OffNum are offScreen numeral shapes 0 to 9}
      CopyBits(OffScreen,myWindow^.PortBits,OffNum[Digit[i]],
                  WhereRect[i],srcCopy,Nil);
End; { of procedure}

procedure CreateRegions;
var i: integer;
Begin
   For i := 1 to 4 do FlightRgn[i] := NewRgn;
   CopterRgn := NewRgn;
   tempRgn := NewRgn;
   BeginRgn := NewRgn;
   EndRgn := NewRgn;
   LevelUnion := NewRgn;
End;

procedure InitialSoundRates;{reset pitch of four flipsounds, start of each game}
var i: integer;
Begin
   For i := 1 to 4 do begin
      FlipSound[i]^.sound1Rate := 29316;
      If i > 1 then FlipSound[i]^.sound2Rate := 78264
         else FlipSound[i]^.sound2Rate :=  0;
      If i > 2 then FlipSound[i]^.sound3Rate := 98607
         else FlipSound[i]^.sound3Rate :=  0;
      If i > 3 then FlipSound[i]^.sound4Rate := 117264
         else FlipSound[i]^.sound4Rate :=  0;
   end; { for i}
End;

procedure CreateStrings;
var
   i:integer;
begin                         {i-468, get all the strings from resource file}
   For i := 1 to lastString do GetIndString(myStrings[i],StringId,i);
end;

procedure DrawAString(theString:Str255;h,v:integer);
begin
   moveto(h,v);
   DrawString(theString);
end;

procedure DrawAllmyStrings;
var
   tRect:Rect;
begin
   TextFace([bold,underline]);
   DrawAString(myStrings[1],(504-StringWidth(myStrings[1]))div 2,60);{centered}
   TextFace([]);
   DrawAString(myStrings[2],(504-StringWidth(myStrings[2]))div 2,80);
   {lets draw a cloud}
   tRect := Cloud[3];  {this is a cloud rect, lets draw one of our clouds}
   OffSetRect(tRect,256-tRect.left,30-tRect.top);{locate it on the screen}
   {now draw it with 'srcOr' mode so we won't disturb our text}
   CopyBits(OffScreen,myWindow^.portBits,OffCloud[3],tRect,srcOr,Nil);
end;

procedure CreateSound;
{we're writing direct to the sound driver with PBWrite... this procedure sets
up all the various buffers, Parm blocks, and such for the three different
types of sounds used in this game, the copter engine is a freeform sound,
the fanfare played for a good jump is 4 fourtone sounds, and the splat is
a freeform sound.  You can determine if a sound is finished by checking
the ioresult field of the Parmblock, if it is less than 1 then the sound
is done.  In the mainloop we check it and start another sound if the last
one is done.... sometimes the Driver has changed ioresult but is not done
with the ParmBlock so writing another sound can be messed up.. buzzing,
this can be avoided by waiting for Tickcount to increment once,or by doing
a PBKillIO.  We use the PBKill when we want to switch sounds before they
are complete... this avoids the problem of our program trying to write to
the Driver buffers at the same time the driver is trying to access them.
To avoid system errors always be sure to Kill sound I/O before exiting the
program!!.. and remember freeform sound slows the program by about 20%}

Var
   i,j: integer;
Begin
   CoptBuff := 7406; { Create the Copter sound stuff,6 bytes for mode & count}
   myHandle := NewHandle(CoptBuff);
   HLock(myHandle);
   myPtr := myHandle^;
   CoptSound := FFSynthPtr(myPtr);
   CoptSound^.mode := ffMode; {freeform mode}
   CoptSound^.count := FixRatio(1,6); {fixed point notation}
   CoptBuff := CoptBuff - 7; {this is size of WaveForm array'0-7399'}
   For j := 0 to CoptBuff do CoptSound^.WaveBytes[j] := 127; {set all to 127}
   j := 0;
   While j<= CoptBuff do Begin
      i := abs(Random) div 512;  {random number 0 to 64}
      CoptSound^.WaveBytes[j] := i; {fill up the buffer with copter sound}
      if (j mod 370 = 100) then
         begin
            j:= j+200;
            CoptSound^.WaveBytes[j] := 255;
            j:= j+ 70;
         end
      else inc(j);
   end; { of while}

   SplatBuff := 1486;   { Create the Splat sound stuff }
   myHandle := NewHandle(SplatBuff);
   HLock(myHandle);
   myPtr := myHandle^;
   SplatSound := FFSynthPtr(myPtr);
   SplatSound^.mode := ffMode;
   SplatSound^.count := FixRatio(1,2); {fixed point notation}
   SplatBuff := SplatBuff - 7;   {this is size of WaveForm array '0-1479'}
   j := 0;
   i := 0;
   While j<= SplatBuff do Begin
      SplatSound^.WaveBytes[j] := i; {fill up the buffer}
      If i < 255 then inc(i) else i := 0; {Sawtooth wave form}
      inc(j);
   end; { of while}

   new(Squarewave);  {my wavePtr...describe a squarewave form for flip sound}
   for i := 0 to 127 do
      begin
         Squarewave^[i] := 255;
         Squarewave^[i+128] := 0;
      end;

   new(FlipSynth);   {my FTSynthPtr, FourTone Synthesizer}
   FlipSynth^.mode := ftMode;

   FlipTime[1] := 10;  FlipTime[2] := 5;  {durations for flipsounds}
   FlipTime[3] := 5;  FlipTime[4] := 20;

   {note: the duration field must be reset after each flipsound as the driver
   decrements its value}

   For i := 1 to 4 do begin  {Build the four FourToneSndRecords}
      new(FlipSound[i]);
      FlipSound[i]^.duration := FlipTime[i]; {initial for each sound}
      FlipSound[i]^.sound1Phase := 64;
      FlipSound[i]^.sound2Phase := 192;
      FlipSound[i]^.sound3Phase := 128; {out of phase just for fun}
      FlipSound[i]^.sound4Phase := 0;
      FlipSound[i]^.sound1Wave := Squarewave;
      FlipSound[i]^.sound2Wave := Squarewave;
      FlipSound[i]^.sound3Wave := Squarewave;
      FlipSound[i]^.sound4Wave := Squarewave;
      end; { of for i }
   {remember must InitialSoundRates each game,at BeginButton press}
   WhichSound := 0;

   new(SoundParmBlk); {TML standard procedure,10-1}
   with SoundParmBlk^ do begin {see tech note 19, PBWrite vs. StartSound}
      iocompletion := nil;
      iorefnum := -4;
      iobuffer := ptr(CoptSound);{coerce the Sound pointer to plain ptr}
      ioreqcount := CoptBuff;
      ioresult := 0;  {will Start coptersound when game begins,MainEventLoop}
   end; {of with}
end;

procedure CreateWindow;{windows,dialogs, and controls}
var
   h,v,width: integer;
   tRect:Rect;
Begin
   myWindow := GetNewWindow(WindResId,@wRecord,Pointer(-1));
   SetPort(myWindow);
   ClipRect(myWindow^.PortRect); {i-166, set cliprgn to small rgn}
   TextFont(0);{System font, should be Chicago unless its been altered}
   HelpDialog := GetNewDialog(HelpId,@dRecord,myWindow);
   AboutDialog := GetNewDialog(AboutId,@AboutdRecord,myWindow);
   {our new dialogs}
   SourceDialog := GetNewDialog(137,@SrcRec,myWindow);
   SpeedDialog := GetNewDialog(138,@SpdRec,myWindow);
   GetDItem(SpeedDialog,2,h,myHandle,tRect);
   SetCtlValue(ControlHandle(myHandle),1);{click the Normal Box}
   SpeedTrapOn := False;
   BitMapDialog := GetNewDialog(139,@BitRec,myWindow);

   BeginButton := GetNewControl(pressBegin,myWindow);
   ResumeButton := GetNewControl(pressResume,myWindow);
   EndButton := GetNewControl(pressEnd,myWindow);
   LevelButton := GetNewControl(pressLevel,myWindow);

   LevelOnDisplay := false;            { flag when level is displayed}
{locate the control buttons in the center of myWindow.. Begin and Resume
are in same location as are End and Level}
   width := myWindow^.portRect.right-myWindow^.portRect.left;
   h := myWindow^.portRect.left + ((width-80) div 2); {center control}
   v := 165;
   SizeControl(BeginButton,80,26);MoveControl(BeginButton,h,v);
   SizeControl(ResumeButton,80,26);MoveControl(ResumeButton,h,v);
   SetRectRgn(BeginRgn,h,v,h+80,v+26);  { BeginButton rect. region }
   v := 200;
   SizeControl(EndButton,80,26);MoveControl(EndButton,h,v);
   SizeControl(LevelButton,80,26);MoveControl(LevelButton,h,v);
   SetRectRgn(EndRgn,h,v,h+80,v+26);
   CopyRgn(EndRgn,LevelUnion);
   OffsetRgn(LevelUnion,-1,0); {used to mask level on scrolling CopterRgn}
End;

procedure CreatePictures; {get 3 PICT's from resource file}
var
   i: integer;
Begin
   Copter := GetPicture(CopterId); {contains 3 Copters,3 Wagons,14 Flips}
   CoptRect := Copter^^.picFrame;   { i-159 }
   Man := GetPicture(ManId); {contains 12 Men,2 thumbs,10 numbers,Cross,etc.}
   ManRect := Man^^.picFrame;
   ScoreBox := GetPicture(ScoreBoxId); {Score,status,yoke control,etc.}
   ScoreBoxRect := ScoreBox^^.picFrame;
{cloudstuff}
   For i := 1 to 3 do begin
      CloudPic[i] := GetPicture(i+355);      {the three cloud pictures}
      Cloud[i] := CloudPic[i]^^.picFrame;{set the cloud Rects size}
      OffCloud[i] := Cloud[i];
      CloudRgn[i] := RgnHandle(GetResource('RGN ',i+355));{regions for clouds}
      {enlarge region so we can mask just inside it as we move to the left}
      InsetRgn(CloudRgn[i],-1,0);
      end; {for i}
end;

procedure CreateOffScreenBitMap;  {see CopyBits stuff,also tech.note 41}
const
   OffLeft = 0;
   OffTop = 0;
   OffRight = 426;
   OffBottom = 261;  {size bitmap to contain all six PICTs}
var
   bRect: Rect;
Begin
   SetRect(bRect,Offleft,OffTop,OffRight,OffBottom);  { drawing area }
   with bRect do begin
      OffRowBytes := (((right - left -1) div 16) +1) * 2;{has to be even!}
      SizeOfOff := (bottom - top) * OffRowBytes;
      OffSetRect(bRect,-left,-top);  { local coordinates }
   end; { of with }

   with OffScreen do begin;               { create new BitMap record }
      baseAddr := QDPtr(NewPtr(SizeOfOff));{big enough for all 6 picts}
      rowbytes := OffRowBytes;
      bounds := bRect;
   end; { of with OffScreen }
End;

procedure DrawPicsIntoOffScreen;
Begin
   OldBits := myWindow^.portBits;  {preserve old BitMap}
   SetPortBits(OffScreen);          { our new BitMap }
  {if offscreen bitmap is bigger than myWindow bitmap watchout for
   clipping caused by ClipRgn and VisRgn fields of grafport record, you
   can set cliprgn with ClipRect procedure and use CopyRgn procedure
   to store old visrgn in temporary rgn... etc.}

   FillRect(myWindow^.PortRect,white);    {erase our new BitMap to white}

   OffSetRect(ScoreBoxRect,-ScoreBoxRect.left,-ScoreBoxRect.top);
   DrawPicture(ScoreBox,ScoreBoxRect);   { ScoreBox stuff }
   OffSetRect(CoptRect,-CoptRect.left,
                           ScoreBoxRect.bottom-CoptRect.top);{below ScoreBox}
   DrawPicture(Copter,CoptRect);
   OffSetRect(ManRect,CoptRect.right-ManRect.left,
                           ScoreBoxRect.bottom-ManRect.top);
   DrawPicture(Man,ManRect); { right of Copter,below ScoreBox }

   ReleaseResource(handle(ScoreBox)); {done with Pictures so dump them}
   ReleaseResource(handle(Man));
   ReleaseResource(handle(Copter));

   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure DrawCloudsIntoOffScreen;     {draw the 3 clouds into offscreen}
var i:integer;
Begin
   OldBits := myWindow^.portBits;  {preserve old BitMap}
   SetPortBits(OffScreen);          { our new BitMap }

   OffSetRect(OffCloud[3],-OffCloud[3].left,
               OffFlip[14].bottom-OffCloud[3].top);{left side,below flips}
   DrawPicture(CloudPic[3],OffCloud[3]);

   OffSetRect(OffCloud[1],OffCross.right-OffCloud[1].left,
               OffHorse.bottom-OffCloud[1].top);{right of cross,below deadhorse}
   DrawPicture(CloudPic[1],OffCloud[1]);

   OffSetRect(OffCloud[2],OffCloud[3].right-OffCloud[2].left,
         OffCloud[1].bottom-OffCloud[2].top);{right of cloud3,below cloud1}
   DrawPicture(CloudPic[2],OffCloud[2]);

   ReleaseResource(handle(CloudPic[1]));
   ReleaseResource(handle(CloudPic[2]));
   ReleaseResource(handle(CloudPic[3]));

   {let's shrink our cloud borders...leave one pixel border on right side,
   this will limit cloud movement to left only!}
   {so now CloudRgn[]^^.RgnBBox.topleft will be same as Cloud[].topleft}
   for i := 1 to 3 do begin
      InsetRect(OffCloud[i],1,1);inc(OffCloud[i].right);
      InsetRect(Cloud[i],1,1);inc(Cloud[i].right);
      end;{for i}

   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure CreateOffScreenRects;
{ where are all those shapes? locate all the shapes in the OffScreen bitmap
by defining the rectangles that contain them. }
var
   i: integer;
   tRect: Rect;
Begin
   OffScoreBox := ScoreBoxRect; {Scorebox is easy... already upper left}

   {find the 3 copters}
   tRect := CoptRect;   {here CoptRect is the whole Copter PICT.frame}
   tRect.right := trect.left + 74;  { width of one copter }
   trect.bottom := tRect.top + 26;  { height of copter }
   for i := 1 to 3 do begin
      OffCopter[i] := tRect;
      OffSetRect(tRect,74,0);  { 3 copters in a row }
   end;
   CoptRect := OffCopter[1];  {now CoptRect is set to size of first copter}

   {find the 3 wagons}
   tRect.left := CoptRect.left;  {left edge of OffScreen}
   tRect.top := CoptRect.bottom; {3 wagons are just below copters}
   tRect.right := trect.left + 73;  { width of one wagon }
   trect.bottom := tRect.top + 22;  { height of wagon }
   for i := 1 to 3 do begin
      OffWagon[i] := tRect;
      OffSetRect(tRect,73,0);  { 3 wagons in a row }
   end;
   WagonRect := OffWagon[1];  {Size onscreen rect}

   {find the 14 flip shapes}
   tRect.left := WagonRect.left;  { topleft corner for reference }
   tRect.top := WagonRect.bottom; {2 rows of 7 Flips just below wagons}
   tRect.right := trect.left + 32;  { width of one manflip }
   trect.bottom := tRect.top + 41;  { height of manflip }
   for i := 1 to 7 do begin
      OffFlip[i] := tRect;  { 7 in top row }
      OffSetRect(tRect,0,41);
      OffFlip[i+7] := tRect;  { 7 in bottom row }
      OffSetRect(tRect,32,-41);
   end;
   OffFlip[15] := OffFlip[1];  { complete animation back to 'stand up' }
   For i := 1 to 2 do FlipRect[i] := tRect;  {Size onscreen Rects}

   {find men hanging,dropping,splat and thumb up/down shapes}
   tRect := ManRect; {upper left corner of Man Picture}
   tRect.right := trect.left + 14;  { width of one man }
   trect.bottom := tRect.top + 16;  { height of man }
   for i := 1 to 7 do begin
      OffMan[i] := tRect; {7 in toprow,1=manhanging,2-6=dropping,7=thumbup}
      OffSetRect(tRect,0,16);
      OffMan[i+7] := tRect; {7 in bottom row,1-6=splat,7th=thumbdown}
      OffSetRect(tRect,14,-16);
   end;
   ManRect := OffMan[1];
   ManHt := ManRect.bottom - ManRect.top;
   ManWdth := ManRect.right - ManRect.left;

   {find the 10 numeral shapes used for score}
   tRect.left := ManRect.left;
   tRect.top := OffMan[8].bottom; {2 rows of 5 numerals below men}
   tRect.right := trect.left + 20;  {width of one number}
   trect.bottom := tRect.top + 15;  { height of number }
   for i := 0 to 4 do begin
      OffNum[i] := tRect;  { 5 numerals '0-4'in top row }
      OffSetRect(tRect,0,15);
      OffNum[i+5] := tRect;  { 5 numerals '5-9' in bottom row }
      OffSetRect(tRect,20,-15);
   end;
   NumRect := tRect;

   tRect.left := ManRect.left;{cross/yoke in scorebox shows mouse movements}
   tRect.top := OffNum[5].bottom; {cross/yoke is below numerals}
   tRect.right := trect.left + 81;
   trect.bottom := tRect.top + 81;  { height of cross/yoke }
   OffCross := tRect;
   CrossRect := tRect;

   tRect.top := OffCross.top; {ManInWagon is drawn for safe landing}
   tRect.left := OffCross.right;
   tRect.Bottom := tRect.top + 10;
   tRect.right := tRect.left + 28;
   OffManInWagon := tRect;
   ManInWagon := tRect;

   tRect.top := OffManInWagon.bottom;  {Driver is drawn if driver is hit}
   tRect.bottom := tRect.top + 22;
   tRect.left := OffCross.right;
   tRect.right := tRect.left + 40;
   OffDriver := tRect;
   DriverRect := OffDriver;

   tRect.top := OffDriver.bottom;   {Horse is drawn if horse is hit}
   tRect.bottom := tRect.top + 22;
   tRect.left := OffCross.right;
   tRect.right := tRect.left + 29;
   OffHorse := tRect;
   HorseRect := OffHorse;
End;

procedure DisplayHelpDialog;
var
   itemHit: integer;
Begin  {Display help dialog window}
   ShowWindow(HelpDialog);
   SelectWindow(HelpDialog);
   ModalDialog(Nil,itemHit);  {We'll close it not matter what was hit}
  HideWindow(HelpDialog);
   SelectWindow(myWindow);
end;

procedure DisplayAboutDialog;{ display the About Stunt... dialog window}
var
   tRect,fRect:  Rect;
   itemHit,i: integer;
   tPort: GrafPtr;
Begin  {Display about dialog window}
   GetPort(tPort);
  ShowWindow(AboutDialog);
   SelectWindow(AboutDialog);
   SetPort(AboutDialog);      {so we can draw into our window}

   tRect := FlipRect[1];
   with tRect do begin
      right := 2*(right-left)+left; {enlarge 4 times}
      bottom := 2*(bottom-top)+top;
      end;
   OffSetRect(tRect,AboutDialog^.portRect.right-40-tRect.right,
                        AboutDialog^.portRect.top+54-tRect.top);
   fRect := tRect;
   InsetRect(fRect,-2,-2);
   FrameRect(fRect);
   InsetRect(fRect,-1,-1);    {draw a frame for the enlarged flip}
   FrameRect(fRect);
   InsetRect(fRect,-2,-2);
   FrameRoundRect(fRect,8,8);
  FillRect(tRect,gray);

   fRect := Cloud[3];  {this is a cloud rect, lets draw one of our clouds}
   OffSetRect(fRect,120-fRect.left,-12-fRect.top);
   CopyBits(OffScreen,AboutDialog^.portBits,OffCloud[3],
                              fRect,srcOr,Nil);

   Repeat
   ModalDialog(Nil,itemHit);     {find which button hit,OK or BACKFLIP}

   If itemHit = 4 then
      begin    { do a backflip }
         For i := 1 to 15 do begin
            CopyBits(OffScreen,AboutDialog^.portBits,OffFlip[i],
                              tRect,srcCopy,Nil);
            aTick := TickCount + 10;
            repeat until (TickCount > aTick);   {pause...}
            end;
         FillRect(tRect,gray);   {erase the last flipshape}
      end; { of if itemHit}
   Until ((itemHit = 3) or (itemHit = 1));  {the done button or 'enter' key}
   HideWindow(AboutDialog);
   SelectWindow(myWindow);{restore our game window}
   SetPort(tPort);
end;

procedure DisplaySourceDialog;
var
   itemHit: integer;
   tPort: GrafPtr;
Begin
   GetPort(tPort);
   ShowWindow(SourceDialog);
   SelectWindow(SourceDialog);
   SetPort(SourceDialog);
   ModalDialog(Nil,itemHit);  {close it no matter what was hit}
   HideWindow(SourceDialog);
   SelectWindow(myWindow);{restore our game window}
   SetPort(tPort);{restore port}
end;

procedure DisplayBitMapDialog;
var
   itemHit: integer;
   tPort: GrafPtr;
Begin
   GetPort(tPort);
   ShowWindow(BitMapDialog);
   SelectWindow(BitMapDialog);
   SetPort(BitMapDialog);
   CopyBits(OffScreen,BitMapDialog^.portBits,OffScreen.bounds,
                              OffScreen.bounds,srcCopy,nil);
   ModalDialog(Nil,itemHit);  {close it no matter what was hit}
   HideWindow(BitMapDialog);
   SelectWindow(myWindow);{restore our game window}
   SetPort(tPort);{restore port}
end;

procedure SetControlValue(which:integer);
var
   i,h:integer;
   tRect:Rect;
Begin
   For i := 2 to 4 do begin
         GetDItem(SpeedDialog,i,h,myHandle,tRect);
         If i = which then SetCtlValue(ControlHandle(myHandle),1)
         else SetCtlValue(ControlHandle(myHandle),0);
      end;
End;
procedure DisplaySpeedDialog;
var
   itemHit,i: integer;
   tPort: GrafPtr;
Begin
   GetPort(tPort);
   ShowWindow(SpeedDialog);
   SelectWindow(SpeedDialog);
   SetPort(SpeedDialog);      {so we can draw into our dialog window}

   Repeat
      ModalDialog(Nil,itemHit);  {close it no matter what was hit}
      Case itemHit of
      2:Begin
            SetControlValue(2);
            SpeedTrapOn := False;
         end;{2:}
      3:Begin
            SetControlValue(3);
            SpeedFactor := 1;
            SpeedTrapOn := True;
         end;
      4:Begin
            SetControlValue(4);
            SpeedFactor := 2;
            SpeedTrapOn := True;
         end;
      end;{case itemhit}
   Until(itemHit = 1);

   HideWindow(SpeedDialog);
   SelectWindow(myWindow);{restore our game window}
   SetPort(tPort);{restore port}
end;

{note: we've since figured out a way to simplify putting up and adding
all the dialogs... we declare a ordinal TYPE called DialogList with
the names of our dialogs in sequence the way they're stored in resource
and declare arrays of DialogPtr's and Records! so that all dialogs can
be called from one procedure that uses a 'Case WhichDialog of' to display
the desired dialog...reference the 'name' from the DialogList}

procedure DoMenuCommand(mResult:LongInt);
var
   name: Str255;
   tPort: GrafPtr;
   h: integer;
Begin
   theMenu := HiWord(mResult);
   theItem := LoWord(mResult);
   Case theMenu of
      appleMenu:
         Begin
            GetPort(tPort);
            If theItem = 1 then DisplayAboutDialog
            Else begin
                  GetItem(myMenus[1],theItem,name);{must be a desk acc.}
                  refNum := OpenDeskAcc(name);
               end;
            SetPort(tPort);
         End;
      fileMenu: Finished := True;   {quit this program}
      optionMenu:
         Case theItem of
         1:Begin         {toggle sound on or off}
               If SoundOn then SoundOn := false else SoundOn := true;
               CheckItem(myMenus[3],theItem,SoundOn);
            end;
         2: Begin    {reset hiscore}
               HiScore := 0;
               DrawScoreIntoBox(HiScore,HiScoreNum);
            end;
         3: DisplayHelpDialog;
         4: DisplaySpeedDialog;
         5: DisplaySourceDialog;
         6: DisplayBitmapDialog;{show our pics and shapes}
         end; { case theItem}
   End;
   HiliteMenu(0);
End;

procedure StartNewCloud;
{get one of 3 clouds, locate at right of screen,do all the rgn stuff}
var
   tRect: Rect;
   cloudheight:integer;
Begin
   If CloudNdx < 3 then inc(CloudNdx) else CloudNdx := 1;{get the next cloud}
   CloudHeight := abs(Random) div 256;{random between 0 and 128}
   OffSetRect(Cloud[CloudNdx],512-Cloud[CloudNdx].left,
                     CloudHeight-Cloud[CloudNdx].top);
   OffSetRgn(CloudRgn[CloudNdx],512-CloudRgn[CloudNdx]^^.rgnBBox.left,
                                          CloudHeight-CloudRgn[CloudNdx]^^.rgnBBox.top);
   {define region copter can be drawn in...will move with cloud}
   tRect := FlightRect;
   tRect.right := Cloud[CloudNdx].right + 514; {a screen width beyond cloud}
   RectRgn(tempRgn,tRect);
   DiffRgn(tempRgn,CloudRgn[CloudNdx],CopterRgn);{cloud out of the Copter area}
end;

procedure InitialCopterStuff;
var
   Dest: point;
   i:integer;
Begin
   OffsetRect(CoptRect,212-CoptRect.left,110-CoptRect.top); {dest. - source}
   CoptNdx := 1;
   OffsetRect(WagonRect,-WagonRect.left,
                        ScoreBoxRect.top-4-WagonRect.bottom);

   WagonNdx := 1;    {set index to first wagon shape}
   WagonMoving := True;
   ManNdx := 1;      {this is the man hanging}
   Dh := 0;Dv := 0;  { no initial copter movement }

   Score := 0;
   MenLeft := 5;  { # of men/level }
   ManStatus := 4;  { a man is hanging from the copter }
   GoodJumps := 0;   { # of successfull jumps }
   WagonSpeed := 1;  { Slowest, wagon will move 1 pixel per loop }
   Gravity := 4;    { fastest, man drops 4 pixels per loop }
   CurrentLevel := 1;   { keeps count of levels...}

   For i := 1 to 5 do begin   { erase the thumbs...}
      EraseRect(ThumbUp[i]);
      EraseRect(ThumbDown[i]);
      ThumbState[i] := 0; {none are drawn, keep track for 'update' drawing}
      end;

   {cloudstuff}
   CloudNdx := 3; {Which cloud is being drawn?}
   StartNewCloud;{set up a cloud on right side and get all the regions ready}
End;

procedure TakeCareControls(whichControl:ControlHandle;localMouse:point);
var
   ControlHit,i: integer;
Begin
   ControlHit := TrackControl(whichControl,localMouse,nil);  { Find out which}
   If ControlHit > 0 then  {i-417}
      Begin
         If whichControl = BeginButton then {BEGIN a game}
            Begin
               InsertMenu(myMenus[4],0);
               For i := 1 to 3 do DisableItem(myMenus[i],0);
               DrawMenuBar;               {display exit message}
               HideControl(BeginButton);
               InitialCopterStuff;        {Reset game varibles to beginning}
               DrawScoreIntoBox(Score,ScoreNum);{overwrite previous score,zero}
               DrawWagonStatus;           { into Scorebox }
               InitialSoundRates;         {reset pitch of flipsounds}
               InvertRect(ScoreMan[1]);   {hilite first man in scorebox}
               GameUnderWay := True;      { animation loop branch is active}
               CloudOnDisplay := True;  {flag for Update, will draw in cloud}
               EraseRect(FlightRect);     { Clear the Screen....}
               HideCursor;                {game mode,no normal mouse functions}
               FlushEvents(mDownMask,0);  {clear mousedowns}
               Mask := 4;                 { mask shapes to flightRect }
               WagonMoving := True;
            end; {of begin}
         If whichControl = ResumeButton then {RESUME}
            Begin
               InsertMenu(myMenus[4],0);  {display exit message}
               For i := 1 to 3 do DisableItem(myMenus[i],0);
               DrawMenuBar;

               HideControl(ResumeButton);
               HideControl(EndButton);

               {now hilite the proper man in the scorebox, was unhilited
               when the user paused the game.}
               If MenLeft > 0 then InvertRect(ScoreMan[6-MenLeft]);

               GameUnderWay := True;   {we're back into game mode}
               HideCursor;
               Mask := 4;{entire flight area}
               CopyRgn(tempRgn,CopterRgn); {restore prior region saved in PauseThisGame}
               FlushEvents(mDownMask,0); {clear all mouseDowns}
            End;
         If whichControl = EndButton then {END current game...}
            Begin
               If LevelOnDisplay then begin {Hide levelbutton if it's drawn}
                  LevelOnDisplay := False;
                  HideControl(LevelButton);
                  UnionRgn(CopterRgn,LevelUnion,CopterRgn);{restore button area to CopterRgn}
                  end;
               HideControl(ResumeButton);{hide the resume and end}
               HideControl(EndButton);
               InvalRect(FlightRect); {make 'Update' redraw the begin screen}
               For i := 1 to 2 do FillRect(FlipFrame[i],dkGray);{flip showing?}
               WhichSound := 0;
               ShowControl(BeginButton);
               Mask := 1;{mask out begin button}
               CloudOnDisplay := False;
               CopyRgn(FlightRgn[Mask],CopterRgn);{must use CopyRgn instead of ':='}
            End;
   End; {of If ControlHit}
End; { of procedure}

procedure PauseThisGame; {called if a backspace or doubleclick during game}
var
   i: integer;
Begin
   GameUnderWay := False; { halt animation }
   FillRect(YokeErase,Gray);      { Cover the yoke }
   If MenLeft > 0 then InvertRect(ScoreMan[6-MenLeft]);{unhilite man in scorebox}
   ShowCursor;
   ShowControl(ResumeButton);
   ShowControl(EndButton);
   DeleteMenu(MessageMenu);  {remove exit message,i-354}
   For i := 1 to 3 do EnableItem(myMenus[i],0);{show other menu options}
   DrawMenuBar;
   Mask := 3;  { flags a pause is underway....mask out buttons}
   CopyRgn(CopterRgn,tempRgn); {keep old region in case we resume this game}
   DiffRgn(FlightRgn[Mask],CloudRgn[CloudNdx],CopterRgn);{Mask Cloud from region}
   err := PBKillIO(SoundParmBlk,false); {kill any current sound}
End;

procedure TakeCareMouseDown(myEvent:EventRecord);
var
   Location: integer;
   WhichWindow: WindowPtr;
   WhichControl: ControlHandle;
   MouseLoc: Point;
   WindowLoc: integer;
   ControlHit,i: integer;
   tLong: LongInt;
Begin
   If GameUnderWay then begin {game is underway..Mousedown can only drop man}

         If ManStatus = 4 then begin{man is hanging so begin the drop}
               ManNdx := 2;  { draw first man dropping at current manRect}
               CopyBits(OffScreen,myWindow^.portBits,OffMan[ManNdx],
                                                   ManRect,srcCopy,CopterRgn);
               ManStatus := 0; {this flags that a man is now dropping}
               HeightOfDrop := WagonRect.bottom - CoptRect.bottom; {for score}
            end; { of if ManStatus}
        end

   Else begin    { then Mouse is normal...handle normal functions }
      MouseLoc := myEvent.Where;  {Global coordinates}
      WindowLoc := FindWindow(MouseLoc,WhichWindow);  {I-287}
      case WindowLoc of
         inMenuBar:
            DoMenuCommand(MenuSelect(MouseLoc));
         inSysWindow:
            SystemClick(myEvent,WhichWindow);  {i-441}
         inDrag:
            DragWindow(WhichWindow,MouseLoc,DragArea);
         inContent:{by not selecting the window, DA's can be open during game}
            Begin
               GlobaltoLocal(MouseLoc);
               ControlHit := FindControl(MouseLoc,whichWindow,whichControl);
               If ControlHit > 0 then TakeCareControls(whichControl,Mouseloc);
            end;
         end; {case of}
      end; { of Else}
end; { TakeCareMouseDown  }

PROCEDURE TakeCareKeyDown(Event:EventRecord);
Var
    KeyCode,i: integer;
    CharCode: char;
Begin
   { KeyCode := LoWord(BitAnd(Event.message,keyCodeMask)) div 256; not used }
   CharCode := chr(LoWord(BitAnd(Event.message,CharCodeMask)));

   If BitAnd(Event.modifiers,CmdKey) = CmdKey then begin
      {key board command - probably a menu command}
      DoMenuCommand(MenuKey(CharCode));
      end
   Else If (CharCode = chr(BackSpace)) and GameUnderWay then PauseThisGame;
End;

procedure TakeCareActivates(myEvent:EventRecord);
var
   WhichWindow: WindowPtr;
Begin
   WhichWindow := WindowPtr(myEvent.message);
   SetPort(WhichWindow);
   {other windows can't be selected or worked while in game mode}
End;

procedure OneTimeGameStuff;   {set up the gamestuff only needed on startup}
var
   Dest: Point;
   i,width,dh,dv:integer;
   tRect:Rect;
Begin
   CloudOnDisplay := False;{no clouds are to be drawn by update}
   { center ScoreBoxRect in Window bottom }
   with ScoreBoxRect do begin
      OffSetRect(ScoreBoxRect,-left,myWindow^.portRect.bottom - bottom);
      i := (myWindow^.portRect.right - right) div 2;
   end; {with}
   OffSetRect(ScoreBoxRect,i,-2);
   OffsetRect(WagonRect,-WagonRect.left,
                        ScoreBoxRect.top-4-WagonRect.bottom);{wagon to baseline}
   OffSetRect(CoptRect,0,WagonRect.top-10-CoptRect.bottom);{lowest copter}
   CopterBottomLimit := CoptRect.bottom; {lower limit for copterflight}
   SetRect(BorderRect,-76,-4,509,CoptRect.top-1);

   {we'll let Update draw the scorebox over a gray background}

   {now define the flight area and various masking regions}
   FlightRect := myWindow^.portRect;
   FlightRect.bottom := ScoreBoxRect.top-4; {define flight area}
   RectRgn(FlightRgn[4],FlightRect);
   DiffRgn(FlightRgn[4],BeginRgn,FlightRgn[1]);  { Flight less begin button }
   DiffRgn(FlightRgn[4],EndRgn,FlightRgn[2]);   { Flight less End button}
   DiffRgn(FlightRgn[1],EndRgn,FlightRgn[3]);  {Flight less both buttons}
   DisposeRgn(BeginRgn);

   {now locate two fliprect's on either side of scoreBox }
   with myWindow^.portRect do begin
      width := ScoreBoxRect.left - left;{width of area}
      dh := (width - (FlipRect[1].right - FlipRect[1].left)) div 2;
      width := bottom - ScoreBoxRect.top + 4;{height of area}
      dv := (width - (FlipRect[1].bottom - FlipRect[1].top)) div 2;
                                 {Left flip location, destination-source}
      OffSetRect(FlipRect[1],left + dh - FlipRect[1].left,bottom -
            dv - FlipRect[1].bottom);
                                 {Right flip location, destination-source}
      OffSetRect(FlipRect[2],ScoreBoxRect.right + dh - FlipRect[2].left,
            bottom - dv - FlipRect[2].bottom);
   end; { of with}

   For i := 1 to 2 do begin    { Frames for flips....}
      tRect := FlipRect[i];
      InsetRect(tRect,-4,-4);    {give the guy some room to flip}
      tRect.bottom := tRect.bottom - 3;{but keep his feet on the ground}
      FlipFrame[i] := tRect;
   end; { of for i}

   {establish Crosshair control limits}
   YokeLimits := ScoreBoxRect;
   YokeLimits.right := YokeLimits.left + 51;
   YokeErase := YokeLimits;
   InsetRect(YokeLimits,7,7);{limits of movement of center of cross}
   InsetRect(YokeErase,4,4); {used to create MaskRgn,mask copyBits for cross}

   {using MaskRgn forces CopyBits to draw only the visible part of the cross
   into the ScoreBox, making it appear to slide inside the box}
   MaskRgn := NewRgn;
   OpenRgn;
      FrameRect(YokeErase);
   CloseRgn(MaskRgn);         {create maskrgn for copybits crosshair}

   {now locate Cross centerline relative to Yoke window.topleft, each loop the
   destination rectangle for the drawing the Cross is offset from this
   position... the offset is determined by mapping the mouse position into
   the MouseRect in the AnimateOneLoop procedure}
   with CrossRect do begin
      Dest.h := YokeLimits.left - ((right - left) div 2);
      Dest.v := YokeLimits.top - ((bottom - top) div 2);
      OffSetRect(CrossRect,Dest.h - left,Dest.v - top);
   end; {with CrossRect}

   SetRect(MouseRect,210,134,302,206); { this is for mapping control }
   SetRect(DeltaRect,-4,-3,4,4);     { this is for finding copter offset }

   {find all the Constants used to locate Cross in ScoreBox, we'll be
   replacing MapPt and OffSetRect calls}
   YokeHt := YokeLimits.bottom-YokeLimits.top;
   YokeWdth := YokeLimits.right-YokeLimits.left;
   MouseHt := MouseRect.bottom-MouseRect.top;
   MouseWdth := MouseRect.right-MouseRect.left;
   OffsetHt := YokeLimits.top-CrossRect.top;
   OffsetWdth := YokeLimits.left-CrossRect.left;
   CrossHt := CrossRect.bottom - CrossRect.top;
   CrossWdth := CrossRect.right - CrossRect.left;
   DeltaHt := DeltaRect.bottom - DeltaRect.top;
   DeltaWdth := DeltaRect.right - DeltaRect.left;

   { onscreen rectangles based in ScoreBox }
   tRect:= OffMan[1];  {size of man..locate ScoreMan in ScoreBox}
   OffSetRect(tRect,ScoreBoxRect.left + 54 - tRect.left,
                        ScoreBoxRect.top - tRect.top);
   for i := 1 to 5 do begin
      ScoreMan[i] := tRect;   { boxes to track which man is in action}
      OffSetRect(tRect,0,17);  { move one row down }
      ThumbUp[i] := tRect;    { boxes for thumbs up }
      OffSetRect(tRect,0,17);
      ThumbDown[i] := tRect;  { Boxes for thumbs down }
      OffSetRect(tRect,15,-34); { back to top and over one}
      ThumbState[i] := 0;  {No Thumbs are drawn yet}
   end; { of for }

   tRect:= OffNum[1];  {size of Numbers..locate in ScoreBox}
   OffSetRect(tRect,ScoreBoxRect.left + 135 - tRect.left,
                        ScoreBoxRect.top + 10 - tRect.top);
   for i := 1 to 6 do begin
      ScoreNum[i] := tRect;   { boxes to record score digits}
      OffSetRect(tRect,0,25);  { move one row down }
      HiScoreNum[i] := tRect;    { boxes for hiscore digits }
      OffSetRect(tRect,21,-25);
   end; { of for }

   {find point for writing current height into the scorebox}
   {HtStatRect is destination rect in scorebox, Offheight is source rect
      in OffScreen, HeightPt is moveto location in offScreen}
   HeightStr := '444';  {max width for 3 numerals?,for centering in box}
   HtStatRect.top := ScoreBoxRect.top + 2;
   HtStatRect.left := ScoreBoxRect.right - 48;
   HtStatRect.bottom := ScoreBoxRect.top + 14;
   HtStatRect.right := HtStatRect.left + StringWidth(HeightStr);
   OffHeight := HtStatRect;   {offScreen rect to contain drawstring}
   OffSetRect(OffHeight,OffHorse.right-OffHeight.left,
                              OffHorse.bottom-OffHeight.bottom);  {right of dead horse}
   HeightPt.h := OffHeight.left;
   HeightPt.v := OffHeight.bottom; {'moveto' location for height in offscreen}

  OldBits := myWindow^.portBits;{always preserve the old map!!}
   SetPortBits(OffScreen);
   FillRect(OffHeight,white);    {erase to white}
   SetPortBits(OldBits);      {restore old bitmap}

   tRect := HtStatRect;
   InSetRect(tRect,-14,-1);
   OffSetRect(tRect,0,17);       {size and locate Rects for Wagon/gravity}
   WagStatRect := tRect;
   OffSetRect(tRect,0,17);
   GravStatRect := tRect;

   WagonStatus[1] := 'WALK';
   WagonStatus[2] := 'TROT';
   WagonStatus[3] := 'GALLOP';
   GravityStatus[4] := 'HEAVY';     {strings for Wagon speed and gravity}
   GravityStatus[3] := 'NORMAL';
   GravityStatus[2] := 'OH BOY';
   GravityStatus[1] := 'FLYING';
End; { of OneTimeGameStuff }

procedure AnimateWagonCopter(ClipTo:RgnHandle;DrawWagon:Boolean);
         {animate copter/wagon while game is not underway}
Begin
   If CoptNdx < 3 then inc(CoptNdx) else CoptNdx := 1;
   OffsetRect(CoptRect,212-CoptRect.left,110-CoptRect.top);
   CopyBits(OffScreen,myWindow^.portBits,OffCopter[CoptNdx],
                     CoptRect,srcCopy,ClipTo);
   If DrawWagon then begin
      If WagonNdx < 3 then inc(WagonNdx) else WagonNdx := 1;
      If (WagonRect.left > 510 ) then OffSetRect(WagonRect,-WagonRect.right,0)
      else OffsetRect(WagonRect,WagonSpeed,0);
      CopyBits(OffScreen,myWindow^.portBits,OffWagon[WagonNdx],
                                 WagonRect,srcCopy,nil);
    end; {if DrawWagon}
   {draw current height into scorebox}
   Height := WagonRect.bottom - CoptRect.bottom;
   NumToString(Height,HeightStr);
   OldBits := myWindow^.portBits;
   SetPortBits(OffScreen);          {we want to draw into offScreen}
   EraseRect(OffHeight);            {erase to white}
   MoveTo(HeightPt.h,HeightPt.v);{move the pen to bottom left of OffHeight}
   DrawString(HeightStr);        { draw current height into offscreen}
   SetPortBits(OldBits);      {restore old bitmap}
   CopyBits(OffScreen,myWindow^.portBits,OffHeight,
                                 HtStatRect,srcCopy,nil);   {now stamp it onto the screen}
End;

procedure ResetManHanging; {test for end of game, reset if more men available}
var
   i: integer;
Begin  { the following executed success or fail }
   ManStatus := 4;{man is hanging}
   InvertRect(ScoreMan[6-MenLeft]); { make last scorebox man normal}
   dec(MenLeft);
   If MenLeft > 0 then InvertRect(ScoreMan[6-MenLeft]); {next man}
   OffSetRect(ManRect,CoptRect.left+36-ManRect.left,
            CoptRect.top+23-ManRect.top);  {move ManRect back up to Copter}
   If MenLeft = 0 then { *** end of this level...}
      begin
         If GoodJumps < 5 then begin   { ****  end of this game }
            GameUnderWay := False;
            If Score > HiScore then begin   {New HiScore?}
                  HiScore := Score;
                  DrawScoreIntoBox(HiScore,HiScoreNum);
               end;
            ShowCursor;
            err := PBKillIO(SoundParmBlk,false); {kill sound}
            whichSound := 0;
            EraseRect(CoptRect); {erase last copter}
            EraseRect(Cloud[CloudNdx]);   {erase last cloud}
            CloudOnDisplay := False;   {no cloud for Update}
            FillRect(YokeErase,Gray);   { fill in yoke }
            DeleteMenu(MessageMenu);  { remove exit message,i-354}
            For i := 1 to 3 do EnableItem(myMenus[i],0);
            DrawMenuBar;
            ShowControl(BeginButton);
            Mask := 1;
            DrawAllmyStrings;
            end { of If GoodJumps }
         Else begin   { move on to next level stuff}
            Mask := 2;  { mask out level button }
            inc(CurrentLevel);  { next level }
            LevelToButtonTitle(CurrentLevel);{level to buttontitle}
            ShowControl(LevelButton);
            LevelOnDisplay := True;
            DiffRgn(CopterRgn,EndRgn,CopterRgn);{mask levelbutton from CopterRgn}
            LevelTimer := TickCount + 120; {time levelbutton onscreen 2 secs.}
            If (WagonSpeed = 3) and (Gravity > 1) then
                                 Gravity := Gravity - 1;   {MaxGravity = 4}
            If WagonSpeed < 3 then WagonSpeed := WagonSpeed + 1;
            DrawWagonStatus;    {update scorebox for wagon/gravity}
            MenLeft := 5;  { # of men/level }
            InvertRect(ScoreMan[1]);
            GoodJumps := 0;   { # of successfull jumps }
            For i := 1 to 5 do begin   {erase the last set of thumbs...}
                  EraseRect(ThumbUp[i]);
                  EraseRect(ThumbDown[i]);
                  ThumbState[i] := 0;
               end; { of for i}
            If CurrentLevel < 6 then begin    { higher pitch flipsound }
               For i := 1 to 4 do begin
                  with FlipSound[i]^ do begin
                     sound1Rate := 2 * sound1Rate;{raise pitch one octave}
                     sound2Rate := 2 * sound2Rate;
                     sound3Rate := 2 * sound3Rate;
                     sound4Rate := 2 * sound4Rate;
                  end; { of with}
               end; { of for i}
            end; { if CurrentLevel}
         end; { of Else}
      end; { of If MenLeft}
   FlushEvents(mDownMask,0); {so an old mousedown will not drop new man!}
End;

procedure AnimateOneLoop;
var
   i,j:integer;
   Where,which: integer;
   MouseLoc,tpoint: Point;
   tRect: Rect;
Begin
   GetMouse(MouseLoc);  { MouseLoc in Coords of currentGrafPort }

   {if out of bounds then limit MouseLoc to MouseRect extremes }
   If MouseLoc.h > MouseRect.right then MouseLoc.h := MouseRect.right
   else If MouseLoc.h < MouseRect.left then MouseLoc.h := MouseRect.left;

   If MouseLoc.v > MouseRect.bottom then MouseLoc.v := MouseRect.bottom
   else If MouseLoc.v < MouseRect.top then MouseLoc.v := MouseRect.top;

   Case CoptNdx of
   {split time between clouds,height and cross...draw each every 3rd loop}

   1:begin {height into scorebox, use offscreen to avoid flicker}
         NumToString(WagonRect.bottom - CoptRect.bottom,HeightStr);
         OldBits := myWindow^.portBits;
         SetPortBits(OffScreen);          {we want to draw into offScreen}
         EraseRect(OffHeight);            {erase to white}
         MoveTo(HeightPt.h,HeightPt.v);{move the pen to bottom left of OffHeight}
         DrawString(HeightStr);        { draw current height into offscreen}
         SetPortBits(OldBits);      {restore old bitmap}
         CopyBits(OffScreen,myWindow^.portBits,OffHeight,
                                 HtStatRect,srcCopy,nil);   {now stamp it onto the screen}
         inc(CoptNdx);
      end;{of Case 1:}

   2:begin  {cloudstuff}
         If (Cloud[CloudNdx].right < 0) then StartNewCloud;{is it offscreen left?}
         dec(Cloud[CloudNdx].left);
         dec(Cloud[CloudNdx].right); {move cloudrect left,faster than OffsetRect}
         OffSetRgn(CloudRgn[CloudNdx],-1,0);{move the masking region too}

         {draw the cloud masked by the cloudrgn}
         CopyBits(OffScreen,myWindow^.portBits,OffCloud[CloudNdx],
                                 Cloud[CloudNdx],srcCopy,CloudRgn[CloudNdx]);

         {move the CopterRgn to mask the new cloud position}
         OffsetRgn(CopterRgn,-1,0);
         inc(CoptNdx);              {next Copter shape}

         {level stuff is here because we are masking the button onto CopterRgn}
         If LevelOnDisplay then begin  { is level button being shown?}
            If TickCount>LevelTimer then begin {put away levelbutton if time is up}
                  Mask := 4;  { normal window}
                  UnionRgn(CopterRgn,LevelUnion,CopterRgn); {put back last level mask}
                  HideControl(LevelButton);
                  LevelOnDisplay := False;
               end {if Tickcount}
            else begin {make sure level is masked properly as copterRgn scrolls}
                  UnionRgn(CopterRgn,LevelUnion,CopterRgn); {put back last mask}
                  DiffRgn(CopterRgn,EndRgn,CopterRgn); {mask out present}
               end; { of else}
            End; { if LevelOnDisplay}
      end; {of case 2:}

   3:begin
         {Draw CrossHair into ScoreBox,use tpoint to preserve MouseLoc}
         {lets do our own MapPt and Offset calculations here instead of ROM calls}
         tRect.left := CrossRect.left + YokeWdth * (MouseLoc.h - 210) div 92;
         tRect.right := tRect.left + CrossWdth;
         tRect.top := CrossRect.top + YokeHt * (MouseLoc.v- 134) div 72;
         tRect.bottom := tRect.top + CrossHt;
         CopyBits(OffScreen,myWindow^.PortBits,OffCross,
                                             tRect,srcCopy,MaskRgn);
         CoptNdx := 1;
      end; {of case 3:}
   end;  {of case CoptNdx}


   {find distance to move the copter for this loop}
   {MapPt will convert our MouseLoc into a point in the DeltaRect which
   represents what the user is requesting for the copter move in pixels per
   loop, since objects cannot instantly accelerate, we will accelerate one
   pixel of offset per loop.  Therefore if the copter is currently flying
   backwords at 4 pixels per loop it will take 8 loops to reach a forward
   speed of 4 pixels per loop assuming that the user has the mouse on full
   forward position.  Full forward position being a Point on the rightmost
   of MouseRect which will return a horizontal value of 4 when mapped into
   the DeltaRect.}
   MapPt(MouseLoc,MouseRect,DeltaRect);

   If MouseLoc.h>Dh then inc(Dh) {MouseLoc.h won't be over 4 or under -4}
   else if MouseLoc.h < Dh then dec(Dh);
   If MouseLoc.v > Dv then inc(Dv)
   else if MouseLoc.v < Dv then dec(Dv);{Dh,Dv are offset to move copter}

   CoptRect.left := CoptRect.left + Dh;   {faster than an OffsetRect}
   CoptRect.right := CoptRect.right + Dh;
   CoptRect.top := CoptRect.top + Dv;
   CoptRect.bottom := CoptRect.bottom + Dv;

    {now check location,BorderRect sets limits for Copter at edges of window}
   If not(PtInRect(CoptRect.topleft,BorderRect)) then begin{outside,find which}
         If CoptRect.left > 510 then OffSetRect(CoptRect,-CoptRect.right,0);{wraparound}
         If CoptRect.left < -76 then OffSetRect(CoptRect,510-CoptRect.left,0);{wrap}
         If CoptRect.top < -4 then OffSetRect(CoptRect,0,-4-CoptRect.top);
         If CoptRect.bottom > CopterBottomLimit then
                     OffSetRect(CoptRect,0,CopterBottomLimit-CoptRect.Bottom);
      end;{of if not PtInRect}

   If WagonNdx < 3 then inc(WagonNdx) else WagonNdx := 1;{which wagon shape}
   If (WagonRect.left > 512) then OffSetRect(WagonRect,-582,0)
   else begin
         WagonRect.left := WagonRect.left + WagonSpeed;        {locate next wagon}
         WagonRect.right := WagonRect.right + WagonSpeed;
      end;{of else}

   Case ManStatus of
   0:begin   { man is dropping......}
         If ManRect.bottom > WagonRect.top then  {Check for a hit!}
            begin
               CopyBits(OffScreen,myWindow^.portBits,OffCopter[CoptNdx],
                                          CoptRect,srcCopy,CopterRgn);  {draw copter}
               EraseRect(ManRect);   { erase man and redraw wagon}
               CopyBits(OffScreen,myWindow^.portBits,
                        OffWagon[WagonNdx],WagonRect,srcCopy,nil);

               Where := ManRect.left - WagonRect.left;{where relative to wagon}
               If (Where < -6) or (Where > 70) then Which := 0 {no hit}
               else if Where < 34 then Which := 1                 {success }
                     else If where < 45 then Which := 2 {hit driver}
                           Else Which := 3;     {hit horse!}
               Case Which of
               1: begin    {landed in hay so initialize Success}
                     CopyBits(OffScreen,myWindow^.portBits,OffMan[7],
                              ThumbUp[6-MenLeft],srcCopy,Nil); {draw Thumbs UP!}
                     ThumbState[6-MenLeft] := 1;
                  Score := Score + CurrentLevel * HeightOfDrop;
                     DrawScoreIntoBox(Score,ScoreNum);
                     If Score > HiScore then begin   {New HiScore?}
                           HiScore := Score;
                           DrawScoreIntoBox(HiScore,HiScoreNum);
                           end;
                     for i := 1 to 2 do begin
                        EraseRect(FlipFrame[i]);{erase area for the flips}
                        FrameRect(FlipFrame[i]); {frame for Flips}
                        end;
                     inc(GoodJumps);
                     ManStatus := 1;  {flag its a success!}
                     FlipCount := 3;   {index for the flips}
                     If SoundOn then begin {start the first of four flipsounds}
                        err := PBKillIO(SoundParmBlk,false);{kill sound}
                        WhichSound := 1;
                        {store flipsound stuff into SoundParmBlk}
                        SoundParmBlk^.iobuffer := ptr(FlipSynth);
                        SoundParmBlk^.ioreqcount := SizeOf(FlipSynth^);
                        FlipSynth^.sndRec := FlipSound[whichSound];
                        {reset duration always..as it is altered by Driver}
                        For j:=1 to 4 do FlipSound[j]^.duration:= FlipTime[j];
                        err := PBWrite(SoundParmBlk,true); {do the Flip sound}
                        end;{If soundOn}
                  end; {of case 1:}
               0,2,3: begin   { missed the hay.... initialize Splat}
                     CopyBits(OffScreen,myWindow^.portBits,OffMan[14],
                              ThumbDown[6-MenLeft],srcCopy,Nil); {Thumbs down}
                     ThumbState[6-MenLeft] := 2;{remember thumbstate for update}
                     FlipCount := 16; {index for drawing flip/splat shapes}
                     If SoundOn then Begin
                        err := PBKillIO(SoundParmBlk,false);
                        WhichSound := 0;  {restart copter sound after splat}
                        SoundParmBlk^.iobuffer := ptr(SplatSound);
                        SoundParmBlk^.ioreqcount := SplatBuff;
                        err := PBWrite(SoundParmBlk,true); {do the splatsound}
                        end;{if SoundOn}
                        OffSetRect(ManRect,0,WagonRect.bottom-13-ManRect.bottom);
                     case which of  {determine which kind of failure}
                     0: begin {missed the whole thing!}
                        ManStatus := 2;  {its a failure}
                        OffSetRect(ManRect,0,WagonRect.bottom-ManRect.bottom);
                        end;
                     2: ManStatus := 8;  {hit the driver}
                     3: ManStatus := 9;  {hit the horse}
                     end; { of case which}
                  end; { case 0,2,3: }
               end; { of Case which  }
            end {Of If manRect}
         Else {man is dropping but not down to wagon yet..keep going}
            begin
               If ManNdx < 6 then inc(ManNdx) else ManNdx := 2;{next man}
               {how about some effects on man dropping thru cloud!!}
               If PtInRgn(ManRect.topleft,CloudRgn[CloudNdx]) then
                              OffSetRect(ManRect,Random div 10924,1) {drop is 1 pixel}
               Else begin  {man not behind cloud so normal drop}
                     ManRect.top:= ManRect.top + Gravity;      {locate next man}
                     ManRect.bottom:= ManRect.bottom + Gravity;
                  end;{of else}
               CopyBits(OffScreen,myWindow^.portBits,OffCopter[CoptNdx],
                                 CoptRect,srcCopy,CopterRgn);
               CopyBits(OffScreen,myWindow^.portBits,OffMan[ManNdx],
                                          ManRect,srcCopy,CopterRgn);
               CopyBits(OffScreen,myWindow^.portBits,OffWagon[WagonNdx],
                                 WagonRect,srcCopy,nil);
            end; { of last else(mandropping)}
      end; { of case 0: mandropping}

   1: {Success is underway... flips and man in wagon}
      Begin
         CopyBits(OffScreen,myWindow^.portBits,OffCopter[CoptNdx],
                     CoptRect,srcCopy,CopterRgn);{draw the copter}
         If FlipCount < 46 then  {for 1 to 15 shapes every third loop}
            begin
               If (FlipCount mod 3) = 0  then begin {Draw every 3rd time thru}
                  i := FlipCount div 3;
                  CopyBits(OffScreen,myWindow^.portBits,OffFlip[i],
                              FlipRect[1],srcCopy,Nil);   {Draw left flip}
                  CopyBits(OffScreen,myWindow^.portBits,
                        OffFlip[i],FlipRect[2],srcCopy,Nil);
                  end;{ if not odd(Flipcount)}
               OffsetRect(ManInWagon,WagonRect.left-ManInWagon.left,
                           WagonRect.top-ManInWagon.top);
               CopyBits(OffScreen,myWindow^.portBits,OffWagon[WagonNdx],
                              WagonRect,srcCopy,Nil);  {draw wagon}
               CopyBits(OffScreen,myWindow^.portBits,OffManInWagon,
                           ManInWagon,srcCopy,Nil);      {draw Man in Wagon}
               inc(FlipCount);
            end
         Else  {the flip is complete...get ready for the next man}
            Begin                           {Erase last flip}
               For i := 1 to 2 do FillRect(FlipFrame[i],dkGray);
               CopyBits(OffScreen,myWindow^.portBits,OffWagon[WagonNdx],
                                 WagonRect,srcCopy,Nil);  {draw wagon}
               ResetManHanging;{ set up another man/level or end}
            end;
      end; { of case 1: success}

   2,8,9: {Fail is underway... drawing splat shapes}
      begin
         CopyBits(OffScreen,myWindow^.portBits,OffCopter[CoptNdx],
                     CoptRect,srcCopy,CopterRgn);
         If FlipCount < 27 then  {for 8 to 13 shapes}
            begin
               CopyBits(OffScreen,myWindow^.portBits,      {draw wagon}
                        OffWagon[WagonNdx],WagonRect,srcCopy,Nil);
               If not odd(Flipcount) then begin {Draw every other time thru}
                  CopyBits(OffScreen,myWindow^.portBits,
                        OffMan[FlipCount div 2],ManRect,srcCopy,Nil);
                  end; {if not odd}
               inc(FlipCount);
            end
         Else  {Splat animation is complete...finish up}
            Begin
               EraseRect(ManRect);
               CopyBits(OffScreen,myWindow^.portBits,OffWagon[WagonNdx],
                                 WagonRect,srcCopy,Nil);  {draw wagon}
               Case ManStatus of
               8: begin    {hit the driver}
                  OffSetRect(DriverRect,WagonRect.right-DriverRect.right,
                                 WagonRect.top-DriverRect.top);
                  CopyBits(OffScreen,myWindow^.portBits,OffDriver,
                                 DriverRect,srcCopy,Nil);{draw dead driver}
                  InvertRect(ScoreMan[6-MenLeft]);
                  MenLeft := 1;  {this will end the game}
                  InvertRect(ScoreMan[6-MenLeft]);
                  WagonMoving := False;{leave the last wagon as is}
                  end; {of case 8:}
               9: begin    {hit the horse}
                  OffSetRect(horseRect,WagonRect.right-horseRect.right,
                                 WagonRect.top-horseRect.top);
                  CopyBits(OffScreen,myWindow^.portBits,Offhorse,
                                 horseRect,srcCopy,Nil);{draw dead horse}
                  InvertRect(ScoreMan[6-MenLeft]);
                  MenLeft := 1;  {end the game}
                  InvertRect(ScoreMan[6-MenLeft]);
                  WagonMoving := False;
                  end; {of case 8:}
               end; {of case Manstatus}

               ResetManHanging;
            end;
      end; {of case Fail}

   4: {ManHanging on to copter}
      begin   { Draw Man and Wagon and continue...waiting for mousedown}
         ManRect.left := CoptRect.left + 36;
         ManRect.right := ManRect.left + ManWdth;
         ManRect.top := CoptRect.top + 23;
         ManRect.bottom := ManRect.top + ManHt;{locate man relative to copter}
         CopyBits(OffScreen,myWindow^.portBits,OffWagon[WagonNdx],
                              WagonRect,srcCopy,nil);
         CopyBits(OffScreen,myWindow^.portBits,OffCopter[CoptNdx],
                     CoptRect,srcCopy,CopterRgn);
         CopyBits(OffScreen,myWindow^.portBits,OffMan[1],
                                 ManRect,srcCopy,CopterRgn);
      end; { of case 4: manhanging}

   end; { of Case ManStatus }
   If SpeedTrapOn then Delay(SpeedFactor,SpeedTick);{ii-384}
End;  { of procedure }

Procedure DrawUpDateStuff;
{will draw all our images in response to Update event,an Update event is
waiting for our newly opened window so will draw our first stuff too!}
var
   tRect: Rect;
   tpoint: Point;
   i: integer;
Begin
   { draw in the scorebox over gray background }
   tRect := myWindow^.portRect;tRect.top := ScoreBoxRect.top - 3;
   FillRect(tRect,dkGray);
   CopyBits(OffScreen,myWindow^.portBits,OffScoreBox,
                  ScoreBoxRect,srcCopy,Nil);
   Moveto(0,ScoreBoxRect.top-4);
   Lineto(512,ScoreBoxRect.top-4); {wagon Baseline or 'ground'line}

   CopyBits(OffScreen,myWindow^.portBits,OffWagon[WagonNdx],
                                 WagonRect,srcCopy,nil);{draw the wagon}

   {  Draw Thumbs into ScoreBox }
   For i := 1 to 5 do begin
      Case ThumbState[i] of   {ThumbState determines which thumb to draw if any}
      {0: don't do anything there is no thumb drawn in this position}
      1: CopyBits(OffScreen,myWindow^.portBits,OffMan[7],
                              ThumbUp[i],srcCopy,Nil);  {Thumbs UP! in upper box}
      2: CopyBits(OffScreen,myWindow^.portBits,OffMan[14],
                              ThumbDown[i],srcCopy,Nil); {Thumbs down in lower box}
      end; { of case}
   end; {of for i}

   DrawScoreIntoBox(Score,ScoreNum);      { Draw Scores into ScoreBox }
   DrawScoreIntoBox(HiScore,HiScoreNum);

   DrawWagonStatus;  { Draw Wagon and Gravity info}

   {Invert proper man in scorebox, don't think this is ever used}
   If (MenLeft > 0) and GameUnderWay then InvertRect(ScoreMan[6-MenLeft]);

   For i := 1 to 2 do FillRect(FlipFrame[i],dkGray);
   FillRect(YokeErase,Gray);   { cover the yoke until resume or newgame}

   If Mask = 1 then begin  {this is used on start up or waiting for begin}
      DrawAllmyStrings;
      ShowControl(BeginButton);
      end;
   {draw cloud if one is showing}
   If CloudOnDisplay then CopyBits(OffScreen,myWindow^.portBits,
         OffCloud[CloudNdx],Cloud[CloudNdx],srcCopy,CloudRgn[CloudNdx]);
end;

procedure TakeCareUpdates(Event:EventRecord);
var
   UpDateWindow,TempPort: WindowPtr;
   itemHit:    integer;
   Test:    Boolean;
Begin
   UpDateWindow := WindowPtr(Event.message);
   GetPort(TempPort);
   SetPort(UpDateWindow);
   BeginUpDate(UpDateWindow);
   EraseRect(UpDateWindow^.portRect);
   If UpDateWindow = myWindow then DrawUpDateStuff;
   DrawControls(UpDateWindow);
   EndUpDate(UpDateWindow);
   SetPort(TempPort);
End;

procedure MainEventLoop;
var
   myEvent: EventRecord;
   i: integer;
Begin
   InitCursor;
   Repeat
      SystemTask;
      If GetNextEvent(EveryEvent,myEvent) then
            Case myEvent.What of
            mouseDown:  TakeCareMouseDown(myEvent);
            mouseUp:
               begin
                  LastMouseUp := myEvent.when;   {to test for DoubleClick}
                  WhereMouseUp := myEvent.where;
               end;
            KeyDown: TakeCareKeyDown(myEvent);
            ActivateEvt:TakeCareActivates(myEvent);
            UpdateEvt:TakeCareUpdates(myEvent);
            End {of Case}
      Else {no event pending so lets do some game stuff}
         Begin
            If GameUnderWay then begin
                  AnimateOneLoop;   {draw all our shapes)

                  {sound stuff... ioresult will be <1 if sound is finished}
                  If (SoundParmBlk^.ioresult < 1) then begin {only if sound is done}
                     If GameUnderWay and SoundOn then begin {animate loop might end game}
                        aTick := TickCount;{we'll wait a tick before PBWrite}
                        Case WhichSound of
                        0: begin {reset copterSound}
                           SoundParmBlk^.iobuffer := ptr(CoptSound);
                           SoundParmBlk^.ioreqcount := CoptBuff;
                           end;
                        1,2,3: begin {reset next flipsound}
                           inc(WhichSound);
                           FlipSynth^.sndRec := FlipSound[whichSound];
                           end;
                        4: begin {reset last flipsound}
                           WhichSound := 0;
                           FlipSynth^.sndRec := FlipSound[4];
                           end; { of case 4:}
                        end; { of Case}
                        repeat until (TickCount > aTick); {wait a tick,just in case}
                        err := PBWrite(SoundParmBlk,true);  {start the sound}
                     end; { if GameUnderWay}
               end; {if SoundParmBlk}
               end { if GameUnderWay}
            else  {game is not underway..waiting for a begin or resume}
               Case Mask of
               1:Begin  { animate during Wait for Beginbutton press }
                  AnimateWagonCopter(FlightRgn[Mask],WagonMoving);
                  If SpeedTrapOn then Delay(SpeedFactor,SpeedTick);
                  End;
               3: { animate stationary copter during wait for Resume/end }
                  Begin
                     If SpeedTrapOn then Delay(SpeedFactor,SpeedTick);
                     If CoptNdx < 3 then inc(CoptNdx) else CoptNdx := 1;
                     CopyBits(OffScreen,myWindow^.portBits,OffCopter[CoptNdx],
                                       CoptRect,srcCopy,CopterRgn);
                     If ManStatus = 4 then begin
                        OffSetRect(ManRect,CoptRect.left+36-ManRect.left,
                                          CoptRect.top+23-ManRect.top);
                        CopyBits(OffScreen,myWindow^.portBits,OffMan[1],
                                 ManRect,srcCopy,CopterRgn);
                        end; { if ManStatus}
                  end; { of 3:}
               end; { case mask}
         End; {else no event pending}
   Until Finished;
End;

procedure SetUpMenus;
var
   i: integer;
Begin
   myMenus[1] := GetMenu(appleMenu);  {get menu info from resources}
   AddResMenu(myMenus[1],'DRVR'); {add in all the DA's}
   myMenus[2] := GetMenu(fileMenu);
   myMenus[3] := GetMenu(optionMenu);
   myMenus[4] := GetMenu(MessageMenu);  {this is the backspace message}
   CheckItem(myMenus[3],1,True); {check the Sound item}
   SoundOn := True;  {sound will start on first begin}
   For i := 1 to 3 do
      begin
         InsertMenu(myMenus[i],0);
      end;
   DrawMenuBar;
End;

procedure CloseStuff;
var i:integer;
Begin
   HideWindow(HelpDialog);
   HideWindow(AboutDialog);
   err := PBKillIO(SoundParmBlk,false);{always kill sound i/o before quitting!}
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

   {show the watch while we wait for inits & setups}
   SetCursor(ClockCursor^^);

   {init everything in case the app is the Startup App}
   InitFonts;
   InitWindows;
   InitMenus;
  TEInit;{for the Dialog stuff}
   InitDialogs(Nil);

   Finished := False;             {set terminator to false}
   FlushEvents(everyEvent,0);     {clear events}
   Screen := ScreenBits.Bounds;  { Get screen dimensions from thePort }
   with Screen do SetRect(DragArea,Left+4,Top+24,Right-4,Bottom-4);
End;

{Main Program begins here}
BEGIN
   InitThings;
   SetUpMenus;
   CreateRegions;
   CreateWindow;           {load window,dialogs,controls}
   CreateSound;            {set up sound buffers, Apple tech note 19}
   CreateOffScreenBitMap;  {see Apple tech note 41}
   CreatePictures;         {load pictures from resources}
   DrawPicsIntoOffScreen;
   CreateStrings;          {load strings from resources}
   CreateOffScreenRects;   {set all rectangles for 'copybits' shape drawing}
   DrawCloudsIntoOffScreen;{depends on OffScreenRects being defined}
   OneTimeGameStuff;       {Game varibles, scorebox stuff,etc}
   HiScore := 0;
   InitialCopterStuff;     {called at start of each game,begin button}
   GameUnderWay := False;
   Mask := 1;  { FlightRgn[1] }
         {first Update event will draw everything in our game window }
   MainEventLoop;
   CloseStuff;
END.
