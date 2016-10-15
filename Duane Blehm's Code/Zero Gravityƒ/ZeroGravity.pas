Program ZeroGravity;{Copyright © 1986 by Duane Blehm, All Rights Reserved}

{ Version 1.0 code enhancement,shrink pict resources...cover,mask,cntlbox}
{Format note: 'tabs' for this text should be set to '3'}

USES MacIntf; {used for TML version 2.0,instead of the 'includes' directive}

{$T APPL ZGRV set the TYPE and CREATOR}
{$B+ set the application's bundle bit }
{$L ZeroGravity.rsrc}   { Link resource file }

CONST
   WindResId = 128;  {Window Resource}

   lastMenu = 5;        {Number of Menus}
   appleMenu = 1;
   fileMenu = 256;      {Menu Resource Id's}
   optionMenu = 257;
   worksMenu = 258;
   messageMenu = 259;

   {Control Resources}
   pressResume = 130;
   pressEnd = 131;

   Disable = 255; {disable button controls,i-322}
   Enable = 0;
   maxint = 32767;
   Pi = 3.141593;
   Decimal = '.';

TYPE
   PilotActs = (InChamber,OpenDoors,FreeFlight,EnterLock,Resting);
   SoundList = (AirDoor,BigDoor,Game,GravTone,Buzz,Blue,Silence);

   PictureList = (Pilot,BigPilot,Pod,Door,Star,Flip,BigFlip,Numeral,
         BigChamber,TimerBox,TargetBox,AirLock,ScoreBox,Mask,Title,
         CntlBox,Cover);
   {2/14/87 note: Cntlbox... will use QuickDraw Commands
      also will shrink Mask in resource and expand it later..all to save
   on size of resources and application size!}

   DialogList = (Help,About,Name,LScore,SCode,BMap);

   {We used MacroMind's 'Music to Video' utility to convert Blue Danube notes
   into a resource... then did some compacting,etc. to come up with our 'SONG'
   resource which contains notes for use with the FourTone synthesizer}

   SongRec = Record  {we'll import a song record from our 'SONG' resource file}
      noteCount:integer;{how many notes in this song}
      pitch:array[1..160,1..4] of Longint;{160 notes,4 voices}
      duration:array[1..160] of integer;{how many ticks will pitch play}
      end;

   SongPtr = ^SongRec;
   SongHandle = ^SongPtr;

   Force = Record    {will contain facts about force acting on Pilot in Chamber}
         magH,magV: integer;  {horizontal,vertical magnitude of force}
         duration:   integer; {how many loops will force be in effect}
         liteNdx:integer;     {index to array of rects used to draw lites}
      end;{of record}

   ScoreNText = Record     {we're keeping our scores in a resource}
      nameStr:Str255;
      score: Real;
   end;

   ScoreBlk = Array[1..3,1..3] of ScoreNText;{3 difficultys,3 names per diff.}

   ScorePtr = ^ScoreBlk;


VAR
   tDialPeek:           DialogPeek; {so we can access TextH field of dialogrec}
   FontFacts:           FontInfo;      {so we can change TEHandle size stuff}
   MouseLoc,tpoint:  Point;
   FigureLoScore:    boolean;    {if true-track loscores; if false-don't bother}
   ScoreControl:        array[2..3] of Handle;{radio buttons,LoScoreDialog}
   ScoreHandle:         Handle;        {handle to our LoScore resource data}
   NameHandle:          Handle;        {Handle to textitem in NameDialog box}
   NameString:          Str255;        {will hold LoScore name from one time to next}
   WindFrame:           array[1..16] of Rect;{array frame rects around window}
   PauseUnderWay:    Boolean;    {flag if pause}
   LastPilot:           Rect;          {last location of Pilot}
   OffPatch,                                 {Pilot sized rect. over OffChamber shape}
   OffPilotMask:        Rect;          {Pilot sized rect. over OffMask shape}
   DoorOpening:         Boolean;    {true while airlock door is opening}
   FlipInProgress:      Boolean;    {true if a flip is being animated}
   OffHold:             Rect;          {Pilot sized rect. in OffScreen bitmap}
   CntlCover:           Rect;          {used to draw gray over diff. Controls}
   LoopCount:           integer;    {count each loop of game for avgscore}
   WholePart,
   FractPart:           Longint;    {used to draw real numbers}
   RotateRight:         Boolean;    {will pilot flip rotate right or left?}

   tinyBonus,tinyPenalty,
   tinyScore,
   tinyLoScore:         Rect;{four boxes for drawing text into box}
   BonusRect,PenaltyRect,
   ScoreRect,
   LoScoreRect:         Rect;       {four boxes inside of scoreBox}
   TimeLine:               integer; {how many loops to increment per game}
   TimeSlide:           Rect;       {rect inside TimerBox for drawing indictor}
   Difficulty:          integer; {1 issoeasy,2 issoso,3 issotuff}
   Radio:                  Array[1..3] of ControlHandle;{difficulty buttons}
   PicNdx:                 PictureList;{use as index to picture arrays}
   R:                      Array[Pilot..Cover] of Rect;{all our pic/shape rectangles!}
   Home:                   Point;{base for drawing shapes, R[BigChamber].topleft}
   TargetNum:           Rect;{destination for Numerals in TargetBox}

   ChamberRgn:          RgnHandle;{mask drawing of chamber interior}

   TopCover,BotCover:Rect;    {two halfs of the chamber cover that opens}
   PilotStatus:         PilotActs;{will determine which animation is going}
   CoverLoops:          integer;

   {all our offscreen rectangles}
   OffPod:                 Array[1..2] of Rect;
   OffDoor,OffFrame,
   OffStar,InStar,OffStarWindow,
   OffBigChamber,
   OffTargetBox,OffMask,
   OffTimerBox,OffScoreBox,
   OffAirLock,OffTitle:          Rect;
   OffNumeral:          Array[0..3] of Rect;
   OffFlip:             Array[1..7] of Rect;
   OffBigFlip:          Array[1..7] Of Rect;
   OffDoorSlide:        Rect;
   OffPilot:               array[1..3,1..3] of Rect;
   OffBigPilot:         array[1..3,1..3] of Rect;

   StarRgn,BigChamberRgn,{most regions are used to 'mask' during CopyBits}
   LimitRgn,
   DoorRgn,DoorSlideRgn,
   CoverRgn,tRgn:    RgnHandle;
   StarBox:             Rect;

   TargetRgn:           Array[0..3] of RgnHandle;{Rgns for finding subscore}
   Bonus,
   Penalty:             Longint;{running total of all subscores for game}
   SubScore:               Longint;{score for distance of pilot from scorecenter}
   LoScore:             ScorePtr;{access ScoreBlk in Resource file}
   AvgScore:               Real;{Score for game divided by no. of loops}
   ScoreCenter:         Point;
   ScoreStr,tStr:    Str255;
   ScoreH,ScoreV:    integer;{location of pen prior to drawing Score string}

   MouseRect,                       {limit mouse movement to this rect}
   DeltaRect:           Rect;       {map rect for copter control;dh,dv}
   BorderRect:          Rect;

   PilotNdx:               Point;      {index for OffPilot array}
   Dh,Dv:                  Integer;    {Offset for Pilot rectangle/shape}
   Grav:                   array[1..30] of Force; {will wind varibles for game}
   GravNdx:             integer;{index for Grav array}
   Gh,Gv:                  Integer;{offset for gravity forces}
   Sustain:             integer;{how many loops will force work?}
   Nh,Nv:                  integer;{net effect of Dh,Dv and Gh,Gv}
   Lights:                 array[0..16] of Rect;{list of lights around chamber}
   LightNdx:               integer;

   myMenus:             Array[1..lastMenu] of MenuHandle;
   refNum,theMenu,
   theItem:             integer;
   SoundOn:             Boolean;    {flag for sound off or on, a menu option}
   Finished:               Boolean;    {terminate the program,quit}
   GameUnderWay:        Boolean;    {are we playing or pausing?}
   ClockCursor:         CursHandle; {handle to watch cursor}
   myWindow:            WindowPtr;  {our game window}
   wRecord:             WindowRecord;{allocate record on stack}
   DialNdx:             DialogList;{will step through our dialogs array}
   myDialog:               Array[Help..BMap] of DialogPtr;
   myDialogRec:         Array[Help..BMap] of DialogRecord;
   Screen,DragArea:  Rect;
   mySize:                 Size; {longint for CompactMem call}

   OffScreen,OldBits,
   InScreen:               BitMap;     {for drawing into offscreen}
   SizeOfOff:           Size;       {Size offscreen bitmap}
   OffRowBytes:         Integer;

   pPict:                  Array[Pilot..CntlBox] of PicHandle;{array of pictures}

   ResumeButton,
   EndButton:           ControlHandle; { handles to controlbuttons }

   aTick:                  Longint;       {TickCount varible, sound delay}

   {Sound varibles}
   Buff:                   Array[AirDoor..Buzz] of Longint;{for Sound buffers}
   myPtr:                  Ptr;
   myHandle:            Handle;
   Sound:                  Array[AirDoor..Blue] of FFSynthPtr;{FreeForm synthesizer sound}
   BlueSynth:           FTSynthPtr;    {Blue is a FourTone sound}
   BlueSound:           FTSndRecPtr;   {four FourTone Sounds}
   SoundParmBlk:        ParmBlkPtr;    {used for PBWrite instead of StartSound}
   WhichSound:          SoundList;     {which sound is being played?}
   err:                    OSerr;
   SawToothWave:           wavePtr;
   SquareWave:          wavePtr;
   ToneTicks,ToneDelay:Longint;
   mySong:                 SongHandle;
   mySongPtr:           SongPtr;
   NoteCount:           Longint;

{**********************************************}
procedure MoveRect(VAR aRect:Rect;h,v:integer;WhichCorner:integer);
{move aRect so that 'whichCorner' is alligned with the point h,v}
Begin
   Case WhichCorner of
   1:Begin{aRect.topleft to h,v}
         aRect.right := aRect.right - aRect.left + h;
         aRect.bottom := aRect.bottom - aRect.top + v;
         aRect.left := h;
         aRect.top := v;
      end;
   2:Begin{aRect.topright to h,v}
         aRect.left := h - aRect.right + aRect.left;{h - width}
         aRect.bottom := aRect.bottom - aRect.top + v;
         aRect.right := h;
         aRect.top := v;
      end;
   3:Begin{aRect.bottomright to h,v}
         aRect.left := h - aRect.right + aRect.left;{h - width}
         aRect.top := v - aRect.bottom + aRect.top;{h - width}
         aRect.right := h;
         aRect.bottom := v;
      end;
   4:Begin{aRect.bottomleft to h,v}
         aRect.right := aRect.right - aRect.left + h;
         aRect.top := v - aRect.bottom + aRect.top;{h - width}
         aRect.left := h;
         aRect.bottom := v;
      end;
   end;{of case whichmatch}
End;

procedure DrawLoScores;{into loScoredialog window}
var
   i,j:integer;
begin
   {draw LoScores into Dialog window}
   For i := 1 to 3 do begin
         For j := 1 to 3 do begin
               MoveTo((i-1)*160 + 10,j*16 + 60);
               DrawString(LoScore^[i,j].nameStr);

               WholePart := trunc(LoScore^[i,j].score);{whole part of real number}
               NumToString(WholePart,ScoreStr);
               FractPart := Round((LoScore^[i,j].score-WholePart)*1000);
               NumToString(FractPart,tStr);
               While length(tStr) < 3 do tStr := concat('0',tStr);{ if fractpart< 0.1}
               ScoreStr := concat(ScoreStr,Decimal,tStr);
               MoveTo(i*160-10-StringWidth(ScoreStr),j*16+60);
               DrawString(ScoreStr);
            end; {for j}
      end;{for i}
end;{procedure}

procedure DrawIntegerIntoBox(theInteger:integer;theRect:Rect);
Begin
   NumToString(theInteger,ScoreStr);{rom call.. convert integer into string}
   MoveTo(theRect.right-StringWidth(ScoreStr),theRect.bottom);
   EraseRect(theRect);
   DrawString(ScoreStr);
end;

procedure DrawScoreIntoBox(theScore:Real;theRect:Rect);
Begin
   WholePart := trunc(theScore); {Whole&Fract Parts are Global Longint}
   NumToString(WholePart,ScoreStr);
   FractPart := Round((theScore-WholePart)*1000);
   NumToString(FractPart,tStr);
   While length(tStr) < 3 do tStr := concat('0',tStr);{ if fractpart< 0.1}
   ScoreStr := concat(ScoreStr,Decimal,tStr);
   MoveTo(theRect.right-StringWidth(ScoreStr),theRect.bottom);
   EraseRect(theRect);
   DrawString(ScoreStr);
End;{of procedure}

procedure ProcessNewLoScore;{display new LoScore stuff and get name}
var
   itemHit,i,index: integer;
Begin
   {put up the dialog box... get nameStr}
   Case Difficulty of
   1:ParamText('IsSoEasy','','','');{we're using the ^1 character, in Resource}
   2:ParamText('IsSoSo','','','');
   3:ParamText('IsSoTuff','','','');{display difficulty string in DialogBox}
   end;{of Case}

   ShowWindow(myDialog[Name]);{show the hidden dialog window}
   SelectWindow(myDialog[Name]);
   SetIText(NameHandle,NameString);{put default in text box}
   SelIText(myDialog[Name],4,0,maxint);{select the text}

   Repeat
   ModalDialog(Nil,itemHit);{Modal does an Update event for the dialog box}

   Until(itemHit = 1);{ok button}

   GetIText(NameHandle,NameString);{must be happy with text..so use it}
   {Test the length of the text... shorten if its too long}
   i := length(NameString);
   While (StringWidth(NameString)> 86) do begin {limit width of string}
         Dec(i);
         NameString := copy(NameString,1,i);{drop one char off the string}
      end;

   HideWindow(myDialog[Name]);{close the dialogwindow}
   SelectWindow(myWindow);

   {sort the New LoScore}
   index := 3;{we know that score is less than 3 already}
   For i := 2 Downto 1 do
         If AvgScore < LoScore^[Difficulty,i].score then index := i;

   i := 3;
   While (i > index) do begin {switch old for new scores}
         LoScore^[Difficulty,i] := LoScore^[Difficulty,i - 1];
         dec(i);
      end;{While}
   LoScore^[Difficulty,index].score := AvgScore;
   LoScore^[Difficulty,index].nameStr := NameString;

   DrawScoreIntoBox(LoScore^[Difficulty,1].score,tinyLoScore);{lowest to scorebox}

   ChangedResource(ScoreHandle);{flag so we will write out changes on Quit}
End;{of procedure}

procedure CreateLoScoreStuff;
{load in our LoScores from resource file}
Begin
   ScoreHandle := GetResource('LSCR',128);{we're keeping LoScores in Resource}
   HLock(ScoreHandle);{lock it permanently.. for speed}
   LoScore := ScorePtr(ScoreHandle^);
end;

procedure WriteASoundBlock(aSoundPtr:Ptr;BuffSize:Longint;LastTick:Longint);
{make changes to our SoundParmBlk and then start the sound,the lasttick pause
is included due to occassional buzz/click/or worse if sound is written
immediately.. might be because Sound Driver set ioResult to zero before
the other soundstuff was complete.. and we happened to peek at it at just
the wrong moment}
Begin
   SoundParmBlk^.iobuffer := aSoundPtr;{set pointer to our sound}
   SoundParmBlk^.ioreqcount := BuffSize;{size of our sound buffer}
   Repeat Until(TickCount > LastTick);{we'll wait a tick before writing sound}
   err := PBWrite(SoundParmBlk,true);{start the sound, asynch}
end;

procedure InitialFourToneSound;
{Set NoteCount to first pitch and duration of our Song array (loaded from
resource file), load that data into BlueSound record and start the sound.
The varible ToneDelay is checked on each event loop, will flag if another note
needs to be loaded into BlueSound.  We're loading in TakeCareSound...,if
BlueSound duration runs out then the Song is restarted from the top.}
var
   i:integer;
Begin
   NoteCount := 1;

   BlueSound^.sound1Rate := mySongPtr^.pitch[NoteCount,1];
   BlueSound^.sound2Rate := mySongPtr^.pitch[NoteCount,2];
   BlueSound^.sound3Rate := mySongPtr^.pitch[NoteCount,3];
   BlueSound^.sound4Rate := mySongPtr^.pitch[NoteCount,4];
   BlueSound^.duration := 80;{none of our notes is over 60 ticks long}

   ToneDelay := mySongPtr^.duration[NoteCount] + TickCount;

   If SoundOn then
            WriteASoundBlock(ptr(Sound[Blue]),SizeOf(Sound[Blue]^),TickCount);
End;{of Procedure}


procedure CreateSound;
Var
   i,j,k: integer;
Begin
   {load Blue Danube from resource file}
   mySong := SongHandle(GetResource('SONG',524));{this is BlueDanube notes}
   HLock(Handle(mySong));{we're locking it permanently}
   mySongPtr := SongPtr(mySong^);

   new(SawToothWave);   {wavePtr...a SawToothWave form for Blue sound}
   new(SquareWave);  {wavePtr...a squarewave form for Blue sound}
   for i := 0 to 127 do {build our four tone waves}
      begin
         SawToothWave^[i] := 2*i;{sort of a raspy sound....}
         SawToothWave^[i+128] := 0;
         SquareWave^[i] := 0;
         SquareWave^[i+128] := 192;{height of Square determines Loudness}
      end;

   {we'll coerce Blue to FreeForm pointer throughout the program just so we
   can use WhichSound and our SoundList type later on....}
   new(BlueSynth);   {my FTSynthPtr, FourTone Synthesizer}
   BlueSynth^.mode := ftMode;

   {note: the duration field must be reset after each Bluesound as the driver
   decrements its value}

   new(BlueSound);{our fourtone sound}
   BlueSound^.sound1Phase := 0;
   BlueSound^.sound2Phase := 128;
   BlueSound^.sound3Phase := 128; {out of phase just for fun}
   BlueSound^.sound4Phase := 0;
   BlueSound^.sound1Wave := SawToothWave;
   BlueSound^.sound2Wave := SawToothWave;
   BlueSound^.sound3Wave := SquareWave;
   BlueSound^.sound4Wave := SquareWave;

   {must make sndRec point to our Sound}
   BlueSynth^.sndRec := BlueSound;
   Sound[Blue] := FFSynthPtr(BlueSynth);{its just a pointer.. so coerce it}

   Buff[AirDoor] := 1486;{size all the freeform buffers}
   Buff[BigDoor] := 3706;{size should be multiple of 370 plus 6 bytes}
   Buff[Game] := 3706;     {6 bytes for mode and count fields}
   Buff[GravTone] := 1486;
   Buff[Buzz] := 1486;

   {now create all the FreeForm sounds....}
   For WhichSound := AirDoor to Buzz do begin {they all have these in common}
         myHandle := NewHandle(Buff[WhichSound]);{new block for our sound}
         HLock(myHandle);  {we're locking the blocks permanently!!}
         myPtr := myHandle^;     {dereference the handle}
         Sound[WhichSound] := FFSynthPtr(myPtr);
         Sound[WhichSound]^.mode := ffMode;
         {knock off 6 bytes for mode & count.. plus 1 for switch to Zero base}
         Buff[WhichSound] := Buff[WhichSound] - 7;
      end;

   {AirDoor Stuff}
   Sound[AirDoor]^.count := FixRatio(1,6);{see the Sound Driver stuff}
   j := 0;
   While j<= Buff[AirDoor] do Begin
      Sound[AirDoor]^.WaveBytes[j] := abs(Random) div 1024; {fill up the buffer}
      inc(j);
   end; { of while}

   {BigDoor sound}
   Sound[BigDoor]^.count := FixRatio(1,2);
   j := 0;
   While j<= Buff[BigDoor] do Begin
      If j< 2000 then i := abs(Random) div 1024;   {random number 0 to 64}
      If j = 2000 then i := 127;
      if (j mod 127 = 0) and (i=127) then i := 0
         else if (j mod 127 = 0) and (i=0) then i := 127;
      Sound[BigDoor]^.WaveBytes[j] := i; {fill up the buffer}
      inc(j);
   end; { of while}

   {Game background sound}
   Sound[Game]^.count := FixRatio(1,8); {fixed point notation}
   j := 0;
   k := 1;
   While j<= Buff[Game] do Begin
      If k > 0 then i := (abs(Random) div 1024) + 127;
      If k > 10 then i := 96;
      If k > 20 then i := 159;
      If k > 30 then k := 0;
      Sound[Game]^.WaveBytes[j] := i; {fill up the buffer}
      inc(k);
      inc(j);
   end; { of while}

   {GravTone when Force Changes sound...}
   {We'll set the Count Field each time we play a tone..in AnimateOneLoop}
   j := 0;
   i := 0;
   k := 0;
   While j<= Buff[GravTone] do Begin {Square wave with freq of 128 bytes}
      Sound[GravTone]^.WaveBytes[j] := i;
      If k = 64 then i := 255;
      If k = 128 then begin
            k := 0;
            i := 0;
         end;{if k}
      inc(k);
      inc(j);
   end; { of while}

   {Buzz Sound during penaltys against the chamber wall}
   Sound[Buzz]^.count := FixRatio(1,2); {fixed point notation}
   j := 0;
   i := 0;
   While j<= Buff[Buzz] do Begin
      Sound[Buzz]^.WaveBytes[j] := i;
      If i < 255 then inc(i) else i := 0;{SawTooth wave}
      inc(j);
   end; { of while}

   {create our Sound Parameter block for use with PBWrite}
   new(SoundParmBlk);
   with SoundParmBlk^ do begin {see Apple tech note 19, PBWrite vs. StartSound}
      iocompletion := nil;
      iorefnum := -4;
      {we'll poke in the pointers and size stuff in WriteASoundBlock}
      ioresult := 0; {will Start sound ,MainEventLoop}
   end; {of with}
end;

procedure BuildGravArray(Diff:integer);{Diff is difficulty}
{build array of 30 forces to be used during game}
var
   mag,dir: real;
   maxmag,maxdir,maxtime,mintime:real;
   i:integer;
Begin
   maxmag := diff + 1.5;      {maximum magnitude of vector}
   maxdir := diff*Pi/3.0;  {maximum change in angle of vector}
   maxtime := 30.0/diff;      {maximum number of loops force will last}
   minTime := 15.0/diff;      {minimum loops force will last}
   dir := abs(Random/(maxint/2*Pi));{set a random angle to start}
   For i := 1 to 30 do begin
         mag := abs(Random/(maxint/maxmag));{magnitude of force vector}
         If mag < 1.0 then mag := 1.0;
         dir := abs(dir + Random/(maxint/maxdir));{angle of force in radians}
         If dir > 2*Pi then dir := dir - 2*Pi;
         Grav[i].magH := round(mag*cos(dir));{x axis component of force}
         Grav[i].magV := round(mag*sin(dir));{y axis component of force}
         Grav[i].duration := round(abs(Random/(maxint/(maxtime-mintime)))+mintime);
         Grav[i].liteNdx := round(dir/(2*Pi/16.0));{which lite to light?}
      end;{for i := }
End;

procedure CreateWindow;{windows,dialogs}
var
   tRect: Rect;
Begin
   myWindow := GetNewWindow(WindResId,@wRecord,Pointer(-1));
   SetRect(tRect,0,0,600,400);{this will clip OffScreen bitMaps as well!!}

   {remember: Dialog itemlists should be purgable, dialogs invisible}
  SetDAFont(202);{Stuttgart font for all the dialogs...}
   For DialNdx := Help to BMap do   begin {read all the dialogs into array}
         myDialog[DialNdx] :=
               GetNewDialog(ord(DialNdx)+129,@myDialogRec[DialNdx],myWindow);
         SetPort(myDialog[DialNdx]);
         ClipRect(tRect);{set clip to smaller size..}
         TextSize(9);      {size of font}
      end;

   {editText item TextHandle controls the font stuff in the NameDialog box}
   GetFontInfo(FontFacts);{will get fontstuff from current grafport(BMap)}
   SetPort(myDialog[Name]);{has a editable text item...effects Text}
   tDialPeek := DialogPeek(myDialog[Name]);{coerce pointer}
   tDialPeek^.textH^^.txSize := 9;{see TextHandle stuff,changing font size}
   tDialPeek^.textH^^.fontAscent := FontFacts.ascent;
   tDialPeek^.textH^^.lineHeight := FontFacts.ascent + FontFacts.descent;

   ShowWindow(myWindow);{done so back to myWindow...}
   SetPort(myWindow);
   ClipRect(tRect); {i-166, set cliprgn to small rgn}
   TextFont(202);{Stuttgart font,installed in resource file}
   TextSize(9);
end;

procedure CreateControls;
var
   i,width: integer;
Begin
   ResumeButton := GetNewControl(pressResume,myWindow);
   EndButton := GetNewControl(pressEnd,myWindow);
   {load Difficulty buttons,locate them later in CntlBox rectangle}
   For i := 1 to 3 do Radio[i] := GetNewControl(132 + i,myWindow);
End;

procedure CreatePictures; {get all the PICT's from resource file}
{we've created a type called PictureList so that we can access the
PicHandle and Rect arrays by 'title' instead of a number,also
all Picture.picframes are preset in resource to proper coordinates for
drawing into OffScreen bitmap otherwise they'd have to be 'Located' first.}
var
   tRect:Rect;
Begin
   For PicNdx := Pilot to Title do begin {almost all of PictureList..}
         pPict[PicNdx] := GetPicture(ord(PicNdx) + 128);{get picture}
         R[PicNdx] := pPict[PicNdx]^^.picFrame;{get Rect for picture}
      end;

   {create CntlBox picture... just a frame}
   SetRect(R[CntlBox],0,0,97,59);{size of CntlBox}
   tRect := R[CntlBox];
   InSetRect(tRect,2,2);
   pPict[CntlBox] := OpenPicture(R[CntlBox]);
   EraseRect(R[CntlBox]);
   FrameRect(R[CntlBox]);
   FrameRoundRect(R[CntlBox],20,20);
   FrameRect(tRect);
   ClosePicture;
end;

procedure CreateOffScreenBitMap; {see CopyBits stuff,also tech.note 41}
var
   bRect: Rect;
Begin
   {OffScreen BitMap stuff, will hold all our shapes for animation}
   SetRect(bRect,0,0,320,296);   { drawing area,size to contain all pics }
   with bRect do begin
      OffRowBytes := (((right - left -1) div 16) +1) * 2;{has to be even!}
      SizeOfOff := (bottom - top) * OffRowBytes;
      OffSetRect(bRect,-left,-top);{move rect to 0,0 topleft}
   end; { of with }

   OffScreen.baseAddr := QDPtr(NewPtr(SizeOfOff));
   OffScreen.rowbytes := OffRowBytes;
   OffScreen.bounds := bRect;

   {InScreen BitMap, Shapes are 'overlaid' in InScreen, then go to myWindow}
   bRect := myWindow^.portRect;{ drawing area same as our onscreen window! }
   with bRect do begin
      OffRowBytes := (((right - left -1) div 16) +1) * 2;{has to be even!}
      SizeOfOff := (bottom - top) * OffRowBytes;
      OffSetRect(bRect,-left,-top);
   end; { of with }

   InScreen.baseAddr := QDPtr(NewPtr(SizeOfOff));
   InScreen.rowbytes := OffRowBytes;
   InScreen.bounds := bRect;
End;

procedure DrawPicsIntoOffScreen;
{watch out for clipping of portRect,visRgn,& clipRgn of grafport record}
var
   tRect:Rect;
Begin
   OldBits := myWindow^.portBits;   {preserve old BitMap}
   tRect := myWindow^.portRect;
   SetPortBits(OffScreen);             { our new BitMap }
   PortSize(400,330);{adjust portRect,visRgn & clipRgn for larger draw area}
   CopyRgn(myWindow^.visRgn,tRgn);
   CopyRgn(myWindow^.clipRgn,myWindow^.visRgn);

   FillRect(OffScreen.bounds,white);      {erase our new BitMap to white}

   {All our Pictures were copied from a drawing of the bitmap in FullPaint
   (the bitmap was located UpperLeft on the page) into the
      ScrapBook.  Then transfered from the ScrapBook to PICT resources with
      ResEdit.  By doing this the Picture.picFrame is already set to
      Coordinates of picture location in OffScreen.  OtherWise all Rects
      would have to be moved into correct position before drawing.}

   For PicNdx := Pilot to Title do begin
            DrawPicture(pPict[PicNdx],R[PicNdx]); {draw all the pictures}
            ReleaseResource(handle(pPict[PicNdx])); {done so dump them}
      end;

   {we've dumped the pictures so how about compacting the heap before loading
   other stuff, like all those sound buffers we're going to lock down?}
   mySize := CompactMem(1024);{force compaction of the heap...???}

   myWindow^.portRect := tRect; {restore old portRect}
   CopyRgn(tRgn,myWindow^.visRgn);{restore old visRgn}
   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure CreateOffScreenRects;
{ where are all those shapes? locate all the shapes in the OffScreen bitmap
by defining the rectangles that contain them.  We'll use the OffScreen rects
as the 'Source' in Copybits.  Probably would be more efficent to have all
OffScreen Rects in a list like our pict Rects and have them predefined in
a resource file... then just load in the whole bunch all at once. }
var
   i,j: integer;
   tRect: Rect;
Begin
   OffBigChamber := R[BigChamber];

   tRect := R[Pilot];      {locate OffPilot shapes}
   tRect.right := tRect.left + 19;
   tRect.bottom := tRect.top + 19; {size of one pilot}
   For i := 1 to 3 do begin
         For j := 1 to 3 do begin
            OffPilot[j,i] := tRect;{load 9 shapes}
            tRect.left := tRect.left + 19;
            tRect.right := tRect.right + 19;
         end;{for j}
      MoveRect(tRect,R[Pilot].left,tRect.bottom,1);{next row}
      end;{for i}
   R[Pilot] := tRect;{resize Pilot to a single shape}

   tRect := R[BigPilot];      {locate OffBigPilot shapes}
   tRect.right := tRect.left + 22;
   tRect.bottom := tRect.top + 22; {size of one BigPilot}
   For i := 1 to 3 do begin
         For j := 1 to 3 do begin
            OffBigPilot[j,i] := tRect;{9 shapes}
            tRect.left := tRect.left + 22;
            tRect.right := tRect.right + 22;
         end;{for j}
      MoveRect(tRect,R[BigChamber].right,tRect.bottom,1);
      end;{for i}
   R[BigPilot] := tRect;{resize to hold one BigPilot}

   tRect := R[Pod];
   tRect.right := tRect.left + 27;
   OffPod[1] := tRect;{empty pod}
   OffSetRect(tRect,26,0);{2 Pods one with pilot,one empty}
   OffPod[2] := tRect;
   R[Pod] := tRect;

   OffDoor := R[Door];
   OffDoor.right := OffDoor.left + 65;
   OffFrame := R[Door];
   OffFrame.left := OffFrame.right - 33;
   R[Door] := OffFrame;
   OffDoorSlide := OffFrame;{DoorSlide will slide along OffDoor}
   OffSetRect(OffDoorSlide,OffDoor.right-OffDoorSlide.right,0);

   OffStar := R[Star];
   SetRect(tRect,0,0,38,38);
   OffStarWindow := tRect;
   MoveRect(OffStarWindow,OffStar.right,OffStar.top,2);
   InStar := OffStarWindow;

   tRect := R[BigFlip];
   tRect.right := tRect.left + 22;{width of one flip}
   For i := 1 to 7 do begin
         OffBigFlip[i] := tRect;
         tRect.left := tRect.left + 22;
         tRect.right := tRect.right + 22;
      end;{for i}
   OffHold := tRect;{will hold last inscreen during freeflight animation}
   MoveRect(OffHold,OffPod[2].right,R[TargetBox].bottom,1);

   tRect := R[Flip];
   tRect.right := tRect.left + 19;{width of one flip}
   For i := 1 to 7 do begin
         OffFlip[i] := tRect;
         tRect.left := tRect.left + 19;
         tRect.right := tRect.right + 19;
      end;{for i}
   OffPatch := tRect;{will be used to refresh background under pilot}
   OffPilotMask := tRect;{will be used to mask target over pilot}

   OffAirLock := R[AirLock];
   OffTargetBox := R[TargetBox];

   OffScoreBox := R[ScoreBox];
   OffTimerBox := R[TimerBox];
   OffTitle := R[Title];

   tRect := R[Numeral];
   tRect.right := tRect.left + 20;
   for i := 0 to 3 do begin
         OffNumeral[i] := tRect;
         tRect.left := tRect.left + 20;
         tRect.right := tRect.right + 20;
      end;{for i}
   TargetNum := tRect;

   {expand Mask to size of BigChamber for OffPilotMask}
   i := R[Mask].left - R[BigChamber].left;
   InsetRect(R[Mask],-i,-i);
   OffMask := R[Mask];
End;

procedure CreateRegions;
var i: integer;
Begin
   StarRgn := NewRgn;{rgn used to mask stars drawn into InScreen}
   LimitRgn := NewRgn;{rgn used to limit Pilot movement to inside chamber}
   DoorRgn := NewRgn;
   CoverRgn := NewRgn;{rgn used to mask Cover doors over chamber}
   tRgn := NewRgn;{temporary region}
   ChamberRgn := NewRgn;{rgn used to mask to chamber}
   BigChamberRgn := NewRgn;{a little larger than chamber}
   DoorSlideRgn := NewRgn;
   for i := 0 to 3 do TargetRgn[i] := NewRgn;{used to find points/score}
End;

procedure DisplayDialog(WhichDialog:DialogList);
var
   tRect,fRect:   Rect;
   itemHit,i,j: integer;
   tPort: GrafPtr;
Begin
   GetPort(tPort);
   ShowWindow(myDialog[WhichDialog]);
   SelectWindow(myDialog[WhichDialog]);
   SetPort(myDialog[WhichDialog]);     {so we can draw into our dialog window}

   Case WhichDialog of
   Help:
         ModalDialog(Nil,itemHit);  {close it no matter what was hit}
   About:
         ModalDialog(Nil,itemHit);  {close it no matter what was hit}
   LScore:begin
         DrawLoScores;{draw the scorestuff into the dialog box}

         Repeat
         ModalDialog(Nil,itemHit);     {find which button hit,OK or BACKFLIP}

         Case itemHit of
         2:begin{control button, start processing loScores}
               SetCtlValue(ControlHandle(ScoreControl[2]),1);{set control true}
               SetCtlValue(ControlHandle(ScoreControl[3]),0);{set control true}
               FigureLoScore := True;{set the flag to true}
            end;
         3:begin{Stop processing LoScores}
               SetCtlValue(ControlHandle(ScoreControl[2]),0);{set control true}
               SetCtlValue(ControlHandle(ScoreControl[3]),1);{set control true}
               FigureLoScore := False;{set the flag to true}
            end;
         6:begin{Reset the LoScores to defaults}
               For i := 1 to 3 do
                  For j := 1 to 3 do begin
                     LoScore^[i,j].nameStr := 'Pilot';{set all nameStrings to pilot}
                     LoScore^[i,j].score := i + 1.0;{new loscores}
                  end;
               InvalRect(myDialog[LScore]^.portRect);{modalDialog will redraw items}
               EraseRect(myDialog[LScore]^.portRect);
               DrawLoScores;{draw our reset scores back in}
               DrawScoreIntoBox(LoScore^[Difficulty,1].score,tinyLoScore);
               ChangedResource(ScoreHandle);{flag so we write out changes}
            end;{case 6}
         end; { of case itemHit}

         Until (itemHit = 1); {the ok button or 'enter' key}
      end;{LScore}
   SCode:{about the sourcecode}
         ModalDialog(Nil,itemHit);  {close it no matter what was hit}
   BMap:begin{peek offscreen bitmap}
         CopyBits(OffScreen,myDialog[BMap]^.portBits,OffScreen.bounds,
                        OffScreen.bounds,srcCopy,nil);   {copy bitmap to dialog box}
         ModalDialog(Nil,itemHit);  {close it no matter what was hit}
      end;{BMap}
   end;{Case WhichDialog}

   HideWindow(myDialog[WhichDialog]);
   SelectWindow(myWindow);{restore our game window}
   SetPort(tPort);{restore port}
end;

procedure DoMenuCommand(mResult:LongInt);
var
   name: Str255;
   tPort: GrafPtr;
   i,h: integer;
Begin
   theMenu := HiWord(mResult);
   theItem := LoWord(mResult);
   Case theMenu of
      appleMenu:
         Begin
            GetPort(tPort);
            If theItem = 1 then DisplayDialog(About)
            Else begin
                  GetItem(myMenus[1],theItem,name);{must be a desk acc.}
                  refNum := OpenDeskAcc(name);
               end;
            SetPort(tPort);
         End;
      fileMenu: Finished := True;   {quit this program}
      optionMenu:
         Case theItem of
         1:DisplayDialog(Help);
         2:DisplayDialog(LScore);
         3:Begin           {toggle sound on or off}
               If SoundOn then SoundOn := false else SoundOn := true;
               CheckItem(myMenus[3],theItem,SoundOn);{check if true,none if false}
            end;
         end; { case theItem}
      worksMenu:
         Case theItem of
         1:DisplayDialog(BMap);
         2:DisplayDialog(SCode);
         end;{case theItem}
   End;
   HiliteMenu(0);
End;

procedure InitialThisGame;{set up for opening the coverdoors/starting game}
var i:integer;
Begin
   MoveRect(R[Pilot],Home.h+65,Home.v+65,1);{locate pilot}
   MoveRect(OffPilotMask,OffMask.left+65,OffMask.top+65,1);{synch with pilot}
   Dh := 0;Dv := 0;{no pilot movement}
   BuildGravArray(Difficulty);{create the forces for this difficulty}
   GravNdx := 1;{force stuff}
   Sustain := 0;
   LightNdx := 0;
   CoverLoops := 24; {number of loops that coverdoor animation will take}
   PilotStatus := OpenDoors;  {this will begin coverdoor animation in maineventloop}
   SetPt(PilotNdx,2,2);{this is standing still shape}
   Penalty := 0;
   Bonus := 0;{score stuff}
   TimeLine := TimeSlide.left - 1;{TimeLine will be coordinate and counter}
   LoopCount := 1;{divided into score to find avg.score}
   FlipInProgress := False;
   err := PBKillIO(SoundParmBlk,false);{kill AirLock sound}
   WhichSound := BigDoor;     {will start BigDoor Sound}
end;

procedure CloseTheCoverDoors;
Begin
   TopCover.bottom := R[Cover].top + 69;
   BotCover.top := R[Cover].bottom - 70;
End;{of CloseTheCover..}

procedure TakeCareControls(whichControl:ControlHandle;localMouse:point);
var
   ControlHit,i: integer;
Begin
   ControlHit := TrackControl(whichControl,localMouse,nil); { Find out which}
   If ControlHit > 0 then  {i-417}
      Begin
         If whichControl = ResumeButton then {RESUME the game..}
            Begin
               InsertMenu(myMenus[5],0);  {display exit message}
               For i := 1 to 4 do DisableItem(myMenus[i],0);
               DrawMenuBar;
               HideControl(ResumeButton);
               HideControl(EndButton);
               GameUnderWay := True;   {we're back into game mode}
               PauseUnderWay := False;
               HideCursor;
               FlushEvents(mDownMask,0); {clear all mouseDowns}
            End;
         If whichControl = EndButton then {END current game...}
            Begin
               HideControl(ResumeButton);{hide the resume and end}
               HideControl(EndButton);
               InvalRect(myWindow^.portRect);{force redraw of all}
               CloseTheCoverDoors;
               {close the airlock doors just in case}
               OffSetRect(OffDoorSlide,OffDoor.right-OffDoorSlide.right,0);
               For i := 1 to 3 do HiliteControl(Radio[i],0);{enable controls}
               EraseRect(CntlCover);
               For i := 1 to 3 do ShowControl(Radio[i]);
               PilotStatus := Resting;{just so drawupdate will handle controls ok}
               PauseUnderWay := False;
               WhichSound := Silence;{no sounds}
            End;
         For i := 1 to 3 do begin
            If whichControl = Radio[i] then begin
                  SetCtlValue(Radio[Difficulty],0);   {uncheck current button}
                  Difficulty := i;  {this is our new difficulty from 1 to 3}
                  {check new button,(contrlMax field must be set to 1)}
                  SetCtlValue(Radio[i],1);
                  DrawScoreIntoBox(LoScore^[Difficulty,1].score,tinyLoScore);
               end;{if which}
            end;{for i}
   End; {of If ControlHit}
End; { of procedure}

procedure PauseThisGame; {called if a keydown during game}
var
   i: integer;
Begin
   err := PBKillIO(SoundParmBlk,false);{kill sound}
   {copy current screen to InScreen, so update events are redrawn correctly}
   CopyBits(myWindow^.portBits,InScreen,myWindow^.portRect,
                        InScreen.bounds,srcCopy,nil);
   GameUnderWay := False; { halt animation }
   ShowCursor;
   ShowControl(ResumeButton);
   ShowControl(EndButton);
   DeleteMenu(MessageMenu);   {remove exit message,i-354}
   For i := 1 to 4 do EnableItem(myMenus[i],0);{show other menu options}
   DrawMenuBar;
   PauseUnderWay := True;
End;

procedure InitialAirLock;{setup to start Airlock animation}
Begin
   CopyBits(OffScreen,myWindow^.portBits,OffHold,
                                             R[BigPilot],srcCopy,nil);{erase last pilot}
   MoveRect(R[BigPilot],R[Door].left+3,R[Door].top+3,1);{pilot in front of door}
   SetPt(PilotNdx,2,2);{this is standing still shape}
   Dh := 0;Dv := 0;
   PilotStatus := EnterLock;{will begin Airlock animation}
   FlipInProgress := False;
   OffSetRect(OffDoorSlide,OffDoor.right-OffDoorSlide.right,0);{DoorSlide to right}
   DoorOpening := True;{flag if door is opening or closing};
   err := PBKillIO(SoundParmBlk,false);{kill Blue Danube sound}
   WhichSound := AirDoor;{will start AirDoor Sound}
end;{procedure}

procedure InitialFreeFlight;{on mousedown in Pod... begin Freeflight}
var
   i:integer;
Begin
   GameUnderWay := True;
   InsertMenu(myMenus[5],0);
   For i := 1 to 4 do DisableItem(myMenus[i],0);
   DrawMenuBar;               {display exit message}
   For i := 1 to 3 do HiliteControl(Radio[i],255);{disable Controls}
   FillRect(BonusRect,Gray);
   FillRect(PenaltyRect,Gray);{gray out for nice dark background}
   FillRect(ScoreRect,Gray);
   FillRect(LoScoreRect,Gray);
   FillRect(TargetNum,Gray);

   For i := 1 to 3 do HideControl(Radio[i]);{will generate update event}
   BeginUpdate(myWindow);{clear Update stuff...}
   EndUpDate(myWindow);
   FlushEvents(updateMask,0);{clear Update stuff caused by HideControl}

   FillRect(CntlCover,Gray);{cover where the controls were}
   CopyBits(OffScreen,myWindow^.portBits,OffPod[1],
                                                         R[Pod],srcCopy,nil);{empty Pod}
   {copy myWindow to InScreen so we can do animation 'overlays' in InScreen}
   CopyBits(myWindow^.portBits,InScreen,myWindow^.portRect,
                        myWindow^.portRect,srcCopy,nil); {copy screen to inscreen}

   MoveRect(R[BigPilot],R[Pod].left,R[Pod].bottom,4);{pilot on top of empty Pod}
   {OffHold will hold a copy of background under the pilot}
   CopyBits(InScreen,OffScreen,R[BigPilot],OffHold,srcCopy,nil);
   SetPt(PilotNdx,2,2);{this is standing still shape}
   PilotStatus := FreeFlight;{type of animation}
   Dh := 0;Dv := 0;
   FlipInProgress := False;
   LoopCount := 1;{for flashing door}
   HideCursor; {game mode,no normal mouse functions}
   FlushEvents(mDownMask,0);  {clear mousedowns}

   WhichSound := Blue;{Blue Danube song}
   InitialFourToneSound;{start the song}
end;

procedure BeginAFlip;
Begin {start a flip}
   FlipInProgress := True;
   If Dh>1  then begin {man is moving right so rotate flip right}
         PilotNdx.h := 1;{set to first flip}
         RotateRight := True;{will cause PilotNdx to be incremented}
      end {if Dh>1}
   else begin     {else pilot will flip to the left}
         PilotNdx.h := 7;
         RotateRight := False;{will cause PilotNdx to be decremented}
      end;{else}
end;{procedure}

procedure TakeCareMouseDown(myEvent:EventRecord);
var
   Location: integer;
   WhichWindow: WindowPtr;
   WhichControl: ControlHandle;
   MouseLoc: Point;
   WindowLoc: integer;
   ControlHit: integer;
Begin
   If GameUnderWay = True then   {handle a game click}
         Case PilotStatus of
         InChamber,OpenDoors: BeginAFlip;

         FreeFlight:If RectInRgn(R[BigPilot],DoorRgn) then InitialAirLock
               else BeginAFlip;
         end {Case pilotStatus}
   Else begin     {Mouse is normal...handle normal functions}
      MouseLoc := myEvent.Where; {Global coordinates}
      WindowLoc := FindWindow(MouseLoc,WhichWindow);  {I-287}
      case WindowLoc of
         inMenuBar:
            DoMenuCommand(MenuSelect(MouseLoc));
         inSysWindow:
            SystemClick(myEvent,WhichWindow);   {i-441}
         inContent:
            If WhichWindow <> FrontWindow then SelectWindow(WhichWindow)
            else
               Begin
                  GlobaltoLocal(MouseLoc);
                  ControlHit := FindControl(MouseLoc,whichWindow,whichControl);
                  If ControlHit > 0 then TakeCareControls(whichControl,Mouseloc)
                  Else  {check for click in Pod Rect, will begin freeflight}
                     If (PtInRect(MouseLoc,R[Pod])) and (not(PauseUnderWay))
                                    then InitialFreeFlight;
               end;
         end; {case of}
      end; { of Else}
end; { TakeCareMouseDown   }

PROCEDURE TakeCareKeyDown(Event:EventRecord);
Var
   CharCode: char;
Begin
   CharCode := chr(LoWord(BitAnd(Event.message,CharCodeMask)));

   If BitAnd(Event.modifiers,CmdKey) = CmdKey then
            DoMenuCommand(MenuKey(CharCode))
   Else If GameUnderWay then PauseThisGame;{pause with any other key press}
End;

procedure TakeCareActivates(myEvent:EventRecord);
var
   WhichWindow: WindowPtr;
Begin
   WhichWindow := WindowPtr(myEvent.message);
   SetPort(WhichWindow);
End;

procedure OneTimeGameStuff;   {set up the gamestuff only needed on startup}
var
   Dest: Point;
   i,j,width,dh,dv,h,v:integer;
   tRect:Rect;
Begin
   SetRect(MouseRect,210,134,302,206); { this is for mapping control }
   SetRect(DeltaRect,-4,-4,4,4);    { this is for finding Pilot offset }
   BorderRect := myWindow^.portRect; { limit pilot to this area }
   InsetRect(BorderRect,10,10);{shrink by width of pilot}
   MoveRect(BorderRect,0,0,1);{will use topleft}

   SetRect(tRect,32,32,463,274); {inside rect of borderframes}
   For i := 1 to 16 do begin
         WindFrame[i] := tRect;{we'll let update draw the border}
         InsetRect(tRect,-2,-2);
      end;

   OpenRgn;
   FrameOval(InStar);
   CloseRgn(StarRgn);{used as mask for drawing stars into chamber 'window'}

   OpenRgn;
   SetRect(tRect,0,0,105,105);
   FrameOval(tRect);
   CloseRgn(LimitRgn);{used to limit pilot.topleft movement inside chamber}

   tRect := OffBigChamber;
   InsetRect(tRect,13,13);
   OpenRgn;
   FrameOval(tRect);
   CloseRgn(ChamberRgn); {used to mask Chamber}

   tRect := OffFrame; {DoorFrame}
   InsetRect(tRect,3,3);
   OpenRgn;
   FrameRect(tRect);
   CloseRgn(DoorRgn); {used to mask door during slide open}

   tRect := OffFrame; {DoorFrame}
   OpenRgn;
   FrameRect(tRect);
   CloseRgn(DoorSlideRgn); {used to mask door during slide closed}

   {Locate BigChamber !!!!! note: was (32,30) in small window}
   OffSetRect(R[BigChamber],64,66);

   {all other shapes are relative to R[BigChamber].topleft..call it 'Home'}
   Home := R[BigChamber].topleft;

   OpenRgn;
   FrameOval(R[BigChamber]);
   CloseRgn(BigChamberRgn);{mask when drawing onto screen}

   OffSetRgn(StarRgn,Home.h+54-StarRgn^^.rgnBBox.left,
                        Home.v+54-StarRgn^^.rgnBBox.top);
   StarBox := StarRgn^^.rgnBBox;
   MoveRect(InStar,StarBox.right,StarBox.top,2);   {InStar is dest.for OffStar}

   R[Cover] := R[BigChamber];
   InsetRect(R[Cover],4,4);{size of cover over the chamber}
   TopCover := R[Cover];{locate... CloseTheCover.. will set proper size}
   BotCover := R[Cover];
   CloseTheCoverDoors;

   OpenRgn;
   FrameOval(R[Cover]);
   CloseRgn(CoverRgn); {used to mask coverdoors}

   i := 13; {this is amount Chamber is inset from R[BigChamber]}
   OffSetRgn(ChamberRgn,Home.h + i-ChamberRgn^^.rgnBBox.left,
                        Home.v + i-ChamberRgn^^.rgnBBox.top);

   OffSetRgn(LimitRgn,Home.h+12-LimitRgn^^.rgnBBox.left,
                        Home.v+12-LimitRgn^^.rgnBBox.top);

   {create target rings...concentric regions with limitRgn as outside}
   CopyRgn(LimitRgn,TargetRgn[3]);{copy of LimitRgn for extreme target edge}

   For i := 3 downto 1 do begin
         CopyRgn(TargetRgn[i],TargetRgn[i-1]);
         InsetRgn(TargetRgn[i-1],10,10);
         DiffRgn(TargetRgn[i],TargetRgn[i-1],TargetRgn[i]);
      end;{for i}

   MoveRect(R[Mask],Home.h+24,Home.v+24,1);

   MoveRect(R[TargetBox],Home.h+147,Home.v-7,1);
   MoveRect(TargetNum,R[TargetBox].left+14,R[TargetBox].top+17,1);

   MoveRect(R[AirLock],Home.h+157,Home.v+47,1);
   MoveRect(R[Door],Home.h+171,
                        Home.v+67,1);
   OffSetRgn(DoorRgn,R[Door].left+3-DoorRgn^^.rgnBBox.left,
                  R[Door].top+3-DoorRgn^^.rgnBBox.top);

   MoveRect(R[CntlBox],Home.h+208,
                        Home.v-14,1);
   CntlCover := R[CntlBox];
   InsetRect(CntlCover,3,3);{will cover controls during freeflight}

   h := R[CntlBox].left + 9;
   v := R[CntlBox].top + 6;
   For i := 1 to 3 do begin
         MoveControl(Radio[i],h,v);{locate Diff.buttons in Cntlbox}
         v := v + 16;
      end;{for i}

   MoveRect(R[ScoreBox],Home.h+313,Home.v-14,1);
   {locate the four score areas in scorebox}

   BonusRect := R[ScoreBox];
   OffSetRect(BonusRect,3,16);{move topleft to bonus rect}
   BonusRect.right := BonusRect.left + 62;
   BonusRect.bottom := BonusRect.top + 18;
   tinyBonus := BonusRect;
   InsetRect(tinyBonus,7,5);{inset to reduce erase area,calculation for text}
   PenaltyRect := BonusRect;
   OffSetRect(PenaltyRect,0,41);
   tinyPenalty := PenaltyRect;
   InsetRect(tinyPenalty,7,5);
   ScoreRect := PenaltyRect;
   OffSetRect(ScoreRect,0,41);
   tinyScore := ScoreRect;
   InsetRect(tinyScore,7,5);
   LoScoreRect := ScoreRect;
   OffSetRect(LoScoreRect,0,41);
   tinyLoScore := LoScoreRect;
   InsetRect(tinyLoScore,7,5);

   MoveRect(R[TimerBox],Home.h+19,Home.v+166,1);
   MoveRect(R[Title],R[TimerBox].left,R[TimerBox].top,1);{title on top of Timerbox}
   SetRect(TimeSlide,0,0,99,7);{size of rect inside TimerBox}
   MoveRect(TimeSlide,R[TimerBox].left+5,R[TimerBox].top+11,1);
   MoveRect(R[Pod],Home.h+252,Home.v+144,1);
   MoveRect(MouseRect,R[Pod].left-50,R[Pod].top-35,1);{center mouse on R[Pod]}

   Difficulty := 1;{Radio buttons come with 1 preset,IsSoEasy value = 1}

   CreateLoScoreStuff;
   NameString := 'Pilot';{will start with pilot then use user input}
   GetDItem(myDialog[Name],4,i,NameHandle,tRect);{get handle to text item}
   {get handle to controls,Calculate LoScore buttons}
   For i := 2 to 3 do GetDItem(myDialog[LScore],i,j,
                                          ScoreControl[i],tRect);
   SetCtlValue(ControlHandle(ScoreControl[2]),1);{set control true}
   FigureLoScore := True;{flag to true,we will calculate LoScores as default}
   Penalty := 0;
   Bonus := 0;
   AvgScore := 0.0;
   PauseUnderWay := False;
   PilotStatus := Resting;{for proper update drawing}

   CopyBits(OffScreen,InScreen,OffBigChamber,R[BigChamber],srcCopy,nil);

End; { of OneTimeGameStuff }

procedure MapMouseToDelta;
{change current mouse location into offset for pilot..Dh,Dv}
Begin
   If FlipInProgress and (PilotStatus <> FreeFlight) then SetPt(MouseLoc,0,0)
   Else begin {get user mouse input}
         GetMouse(MouseLoc);  { MouseLoc in Coords of currentGrafPort }

         {if out of bounds then limit MouseLoc to MouseRect extremes }
         If MouseLoc.h > MouseRect.right then MouseLoc.h := MouseRect.right
         else If MouseLoc.h < MouseRect.left then MouseLoc.h := MouseRect.left;

         If MouseLoc.v > MouseRect.bottom then MouseLoc.v := MouseRect.bottom
         else If MouseLoc.v < MouseRect.top then MouseLoc.v := MouseRect.top;

         {now map MouseLoc from MouseRect into DeltaRect...MouseLoc becomes
         request from user for new Offset for Pilot}
         MapPt(MouseLoc,MouseRect,DeltaRect);{great!,thanks to Bill Atkinson}
      end;{else}
   {we want change of direction to be smooth so 'damp' by letting MouseLoc
   change Dh,Dv only one unit per loop.}
   If MouseLoc.h>Dh then inc(Dh) {MouseLoc.h won't be over 4 or under -4}
   else if MouseLoc.h < Dh then dec(Dh);
   If MouseLoc.v > Dv then inc(Dv)
   else if MouseLoc.v < Dv then dec(Dv);{Dh,Dv are rate of pilot movement}
end;

procedure AnimateStuffInCommon;{for both OneLoop & CoverDoors}
Begin
   {test if new location is ok... not outside the chamber area}
   tPoint.h := R[Pilot].left + Nh;{tPoint = temporary new pilot location}
   tPoint.v := R[Pilot].top + Nv;
   If not(PtInRgn(tPoint,LimitRgn)) then begin  {new pilot is outside the Chamber!}
         Repeat
            Nh := Nh div 2;{move half way back to last pilot location}
            Nv := Nv div 2;
            tPoint.h := R[Pilot].left + Nh;
            tPoint.v := R[Pilot].top + Nv;
         Until(PtInRgn(tPoint,LimitRgn));{half offset until back inside limitRgn}

         inc(Penalty);{add to penalty,does nothing in CoverDoors}

         If SoundOn and (WhichSound <> Buzz) then begin {write out a buzzsound}
               err := PBKillIO(SoundParmBlk,false);{kill current sound}
               WriteASoundBlock(ptr(Sound[Buzz]),Buff[Buzz],TickCount);
               WhichSound := Buzz;
            end;{if soundOn}
      end;{of if not PtInRect}

   {locate our 3 rects which move in sequence}
   R[Pilot].left := R[Pilot].left + Nh;   {faster than an OffsetRect}
   R[Pilot].right := R[Pilot].right + Nh;
   R[Pilot].top := R[Pilot].top + Nv;
   R[Pilot].bottom := R[Pilot].bottom + Nv;

   OffPatch.left := OffPatch.left + Nh;   {faster than an OffsetRect}
   OffPatch.right := OffPatch.right + Nh;
   OffPatch.top := OffPatch.top + Nv;
   OffPatch.bottom := OffPatch.bottom + Nv;

   OffPilotMask.left := OffPilotMask.left + Nh; {faster than an OffsetRect}
   OffPilotMask.right := OffPilotMask.right + Nh;
   OffPilotMask.top := OffPilotMask.top + Nv;
   OffPilotMask.bottom := OffPilotMask.bottom + Nv;

   {which shape to draw?,PilotNdx points to one of 9 shapes}
   If not(FlipInProgress) then begin
         If MouseLoc.h = 0 then PilotNdx.h := 2
         else if MouseLoc.h > 0 then PilotNdx.h := 3 else PilotNdx.h := 1;
         If MouseLoc.v = 0 then PilotNdx.v := 2
         else if MouseLoc.v > 0 then PilotNdx.v := 3 else PilotNdx.v := 1;
      end;{if not flip}

   If OffStarWindow.left = OffStar.left then
         OffSetRect(OffStarWindow,OffStar.right-OffStarWindow.right,0)
   Else OffSetRect(OffStarWindow,-1,0);{so we can animate our stars}

   {score ....start in center, if pilot is there fall thru else try next,
   TargetRgn is an array of concentric rings}
   SubScore := 0;
   While (not(PtInRgn(R[Pilot].topleft,TargetRgn[SubScore]))) do begin
         inc(SubScore); {find if pilot is in 0-3 target circles}
      end;

   CopyBits(OffScreen,myWindow^.portBits,OffNumeral[SubScore],
                     TargetNum,srcCopy,nil);{proper numeral into target box}
end;{of procedure}

procedure DrawTheCoverDoors;
Begin
   OldBits := myWindow^.portBits;
   SetPortBits(InScreen);

   FillRect(TopCover,dkGray);
   FillRect(BotCover,dkGray);
   MoveTo(TopCover.left,TopCover.bottom);
   LineTo(TopCover.right,TopCover.bottom);
   MoveTo(BotCover.left,BotCover.top);
   LineTo(BotCover.right,BotCover.top);

   SetRectRgn(tRgn,TopCover.left,TopCover.bottom,TopCover.right,BotCover.top);
   DiffRgn(CoverRgn,tRgn,tRgn);{find area for mask on coverdoors}
   CopyBits(OffScreen,InScreen,OffMask,R[BigChamber],srcBic,tRgn);

   SetPortBits(OldBits);
  CopyBits(InScreen,myWindow^.portBits,R[Cover],R[Cover],srcCopy,CoverRgn);
end;

procedure AnimateOneLoop;{this is the main game loop}
var
   i,j:integer;
   tRect: Rect;
Begin
   {OffPatch floats over OffBigChamber..used to restore background over
      last pilot in InScreen}
   CopyBits(OffScreen,InScreen,OffPatch,R[Pilot],srcCopy,nil);
   lastPilot := R[Pilot];{keep a temporary copy of our last R[Pilot]}

   MapMouseToDelta;{get new Dh,Dv for pilot}

   If Sustain <1 then begin {then go get another Grav record,new force}
         Gh := Grav[GravNdx].magH;
         Gv := Grav[GravNdx].magV;
         Sustain := Grav[GravNdx].duration;{how many loops will grav work}

         FillOval(Lights[LightNdx],dkgray);{erase last light}
         LightNdx := Grav[GravNdx].liteNdx;{get next light index}
         EraseOval(Lights[LightNdx]);
         FrameOval(Lights[LightNdx]);{turn on new light}
         If SoundOn then begin {write a Tone Sound for new force}
               err := PBKillIO(SoundParmBlk,false);{kill current sound}
               i := abs(Gh) + abs(Gv);{watch out for zero magnitude}
               Sound[GravTone]^.count := FixRatio(i,2);{let magnitude influence GravTone}
               WriteASoundBlock(ptr(Sound[GravTone]),Buff[GravTone],TickCount);
            end;{if soundOn}
         If GravNdx < 30 then inc(GravNdx) else GravNdx := 1;{30 elements in array}
      end{if Sustain}
   Else dec(Sustain);
   Nh := Dh + Gh;{net effect of flight control and gravity}
   Nv := Dv + Gv;

   AnimateStuffInCommon;{stuff in common to OneLoop and CoverDoors}

   Penalty := Penalty + SubScore;
   inc(LoopCount);
   DrawIntegerIntoBox(Penalty,tinyPenalty);
   AvgScore := (Penalty - Bonus)/LoopCount;
   If AvgScore < 0 then AvgScore := 0;
   DrawScoreIntoBox(AvgScore,tinyScore);

   CopyBits(OffScreen,InScreen,OffStarWindow,InStar,srcCopy,StarRgn);

   If FlipInProgress then begin {draw the Pilot flip shapes, get next}
         CopyBits(OffScreen,InScreen,OffFlip[PilotNdx.h],
                                    R[Pilot],notSrcBic,nil);
         If RotateRight then
               If PilotNdx.h < 7 then inc(PilotNdx.h) {next flip shape}
               else begin
                     FlipInProgress := False; {flip is over.. reset normal status}
                     Bonus := Bonus + Difficulty;{more points for higher level}
                     DrawIntegerIntoBox(Bonus,tinyBonus);
                  end{else}
         else
               If PilotNdx.h > 1 then dec(PilotNdx.h) {next flip shape}
               else begin
                     FlipInProgress := False; {flip is over.. reset normal status}
                     Bonus := Bonus + Difficulty;
                     DrawIntegerIntoBox(Bonus,tinyBonus);
                  end;{else}
      end { if flipinprogress}
   Else {normal pilot... not flipping}
      CopyBits(OffScreen,InScreen,OffPilot[PilotNdx.h,PilotNdx.v],
                     R[Pilot],notSrcBic,nil);      {modes on page i-157}

   {copy pilot sized piece of mask over the new pilot,OffPilotMask
   floats over OffMask shape in synch with Pilot and OffPatch}
   CopyBits(OffScreen,InScreen,OffPilotMask,R[Pilot],srcOr,nil);

   UnionRect(LastPilot,R[Pilot],LastPilot);{rect that contains both Pilots}
   UnionRect(LastPilot,Instar,LastPilot); {find rect that contains pilots & Stars}

   CopyBits(InScreen,myWindow^.portBits,LastPilot,
                                          LastPilot,srcCopy,ChamberRgn);

   {monitor our game time...indicator below chamber}
   If (LoopCount mod 6 = 0) then begin {we only draw a line every 6 loops}
         inc(TimeLine);{one step closer to ending game}

         If TimeLine = TimeSlide.right then begin {then end this game }
               GameUnderWay := False; { halt animation }
               PilotStatus := Resting;{for draw update stuff}
               err := PBKillIO(SoundParmBlk,false);
               WhichSound := Silence;
               ShowCursor;
               DeleteMenu(MessageMenu);   {remove exit message,i-354}
               For i := 1 to 4 do EnableItem(myMenus[i],0);{show other menu options}
               DrawMenuBar;
               FillOval(Lights[LightNdx],dkGray);{erase last light}
               FillRect(TargetNum,Gray);{Cover last Num...}
               CloseTheCoverDoors;
               DrawTheCoverDoors;{draw cover & mask}

               CopyBits(OffScreen,myWindow^.portBits,OffPod[2],
                                          R[Pod],srcCopy,nil);
               If (AvgScore < LoScore^[Difficulty,3].score) and
                                          FigureLoScore then ProcessNewLoScore;
               For i := 1 to 3 do HiliteControl(Radio[i],0);{enable controls}
               InvalRect(CntlCover);{will force redraw of controls}
               InvalRect(R[Title]);{will force redraw of Title over TimerBox}
            end{then begin}
         Else begin
               moveTo(TimeLine,TimeSlide.top);
               LineTo(TimeLine,TimeSlide.bottom);{draw the indicator line in timerbox}
            end;{else}
      end;{if LoopCount mod 6}
End;{of procedure}

procedure AnimateFreeFlight;{animate Pilot over the entire window}
var
   i,j:integer;
   tRect: Rect;
   Where:Longint;
Begin
   MapMouseToDelta;

   tRect := R[BigPilot];{keep last location in temporaryRect}
   R[BigPilot].left := R[BigPilot].left + Dh;   {faster than an OffsetRect}
   R[BigPilot].right := R[BigPilot].right + Dh;
   R[BigPilot].top := R[BigPilot].top + Dv;
   R[BigPilot].bottom := R[BigPilot].bottom + Dv;

   If not(PtInRect(R[BigPilot].topleft,BorderRect)) then begin{outside,find which}
         If R[BigPilot].left > BorderRect.right then
            OffSetRect(R[BigPilot],BorderRect.right-R[BigPilot].left,0);
         If R[BigPilot].left < BorderRect.left then
            OffSetRect(R[BigPilot],BorderRect.left-R[BigPilot].left,0);
         If R[BigPilot].top > BorderRect.bottom then
            OffSetRect(R[BigPilot],0,BorderRect.bottom-R[BigPilot].top);
         If R[BigPilot].top < BorderRect.top then
            OffSetRect(R[BigPilot],0,BorderRect.top-R[BigPilot].top);
      end;{of if not PtInRect}

   {which shape to draw?}
   If not(FlipInProgress) {no flip} then begin
         If MouseLoc.h = 0 then PilotNdx.h := 2
         else if MouseLoc.h > 0 then PilotNdx.h := 3 else PilotNdx.h := 1;
         If MouseLoc.v = 0 then PilotNdx.v := 2
         else if MouseLoc.v > 0 then PilotNdx.v := 3 else PilotNdx.v := 1;
      end;{if not flip}

   CopyBits(OffScreen,InScreen,OffHold,tRect,srcCopy,nil);{restore inscreen}
   CopyBits(InScreen,OffScreen,R[BigPilot],OffHold,srcCopy,nil);{save current}

   If FlipInProgress then begin
         CopyBits(OffScreen,InScreen,OffBigFlip[PilotNdx.h],
                     R[BigPilot],notSrcBic,nil);
         If RotateRight then
               If PilotNdx.h < 7 then inc(PilotNdx.h) {next flip shape}
               else FlipInProgress := False {flip is over.. reset freeflight status}
         else
               If PilotNdx.h > 1 then dec(PilotNdx.h) {next flip shape}
               else FlipInProgress := False;{flip is over.. reset freeflight status}
      end { if FlipInProgress}
   Else {normal pilot... not flipping}
      CopyBits(OffScreen,InScreen,OffBigPilot[PilotNdx.h,PilotNdx.v],
                     R[BigPilot],notSrcBic,nil);

   UnionRect(tRect,R[BigPilot],tRect);{Rect to contain both last and current}

   CopyBits(InScreen,myWindow^.portBits,tRect,tRect,srcCopy,nil);

   If LoopCount < 7 then inc(LoopCount)
   else begin
      InvertRect(R[Door]);{flashing Airlock door stuff}
      LoopCount := 1;
      {take care of offscreen stuff in case of invert on screen}
      CopyBits(OffScreen,InScreen,OffHold,R[BigPilot],srcCopy,nil);{restore inscreen}
      OldBits := myWindow^.portBits;
      SetPortBits(InScreen);
      InvertRect(R[Door]);{invert the patched Door in InScreen bitmap}
      SetPortBits(OldBits);
      CopyBits(InScreen,OffScreen,R[BigPilot],OffHold,srcCopy,nil);{save current}
   end;

End;{of procedure}

procedure DrawAirLockShapes;{tRgn masks frame over or behind pilot}
Begin
   CopyBits(OffScreen,InScreen,OffFrame,R[Door],srcCopy,nil);
   CopyBits(OffScreen,InScreen,OffDoorSlide,R[Door],srcCopy,DoorRgn);
   CopyBits(OffScreen,InScreen,OffBigPilot[PilotNdx.h,PilotNdx.v],
                                          R[BigPilot],notsrcBic,tRgn);
   CopyBits(InScreen,myWindow^.portBits,R[Door],R[Door],srcCopy,nil);
end;

procedure AnimateAirLock;
var
   i,j:integer;
   MouseLoc,tpoint: Point;
   tRect: Rect;
Begin
   {find random movement for our Pilot while door is opening/closing}
   SetPt(MouseLoc,Random div (Maxint div 2),Random div (Maxint div 2));
   If MouseLoc.h>Dh then inc(Dh) {MouseLoc.h won't be over 4 or under -4}
   else if MouseLoc.h < Dh then dec(Dh);
   If MouseLoc.v > Dv then inc(Dv)
   else if MouseLoc.v < Dv then dec(Dv);{Dh,Dv are rate of pilot movement}

   R[BigPilot].left := R[BigPilot].left + Dh;   {faster than an OffsetRect}
   R[BigPilot].right := R[BigPilot].right + Dh;
   R[BigPilot].top := R[BigPilot].top + Dv;
   R[BigPilot].bottom := R[BigPilot].bottom + Dv;

   If R[BigPilot].left < R[Door].left then
      OffSetRect(R[BigPilot],R[Door].left-R[BigPilot].left,0)
   else If R[BigPilot].right > R[Door].right then
      OffSetRect(R[BigPilot],R[Door].right-R[BigPilot].right,0);
   If R[BigPilot].top < R[Door].top then
      OffSetRect(R[BigPilot],0,R[Door].top-R[BigPilot].top)
   else If R[BigPilot].bottom > R[Door].bottom then
      OffSetRect(R[BigPilot],0,R[Door].bottom-R[BigPilot].bottom);

   If DoorOpening then begin {The door is opening}
         If OffDoorSlide.left > OffDoor.left then begin {still sliding}
               OffSetRect(OffDoorSlide,-1,0); {move it one to left}
               RectRgn(tRgn,myWindow^.portRect);{whole screen,just so its not nil}
               DrawAirLockShapes;

            end {if still sliding}
         else begin {begin door closing stuff}
               OffSetRgn(DoorSlideRgn,R[Door].right-DoorSlideRgn^^.rgnBBox.left,
                        R[Door].top-DoorSlideRgn^^.rgnBBox.top);{will mask pilot}
               DoorOpening := False;
            end;{else}
      end {door is opening}
   Else begin {Door is Closing}
         If OffDoorSlide.right < OffDoor.right then begin {still sliding}
               OffSetRect(OffDoorSlide,1,0); {move it one to right}
               OffSetRgn(DoorSlideRgn,-1,0); {move it to left, will hide pilot}
               DiffRgn(DoorRgn,DoorSlideRgn,tRgn);{pilot appears to be behind door}

               DrawAirLockShapes;

            end {if still sliding}
         else InitialThisGame;{will begin coverdoor sequence and game}
   end; {else door is closing}
End;  { of procedure }

procedure AnimateCoverDoors;
var
   i,j:integer;
   tRect: Rect;
Begin
   MapMouseToDelta;
   Nh := Dh;{net force and flight effects on Pilot}
   Nv := Dv;

   AnimateStuffInCommon;

   CopyBits(OffScreen,InScreen,OffBigChamber,R[BigChamber],srcCopy,nil);
   CopyBits(OffScreen,InScreen,OffStarWindow,InStar,srcCopy,StarRgn);

   If FlipInProgress then begin
         CopyBits(OffScreen,InScreen,OffFlip[PilotNdx.h],
                     R[Pilot],notSrcBic,nil);      {modes on page i-157}
         If RotateRight then
               If PilotNdx.h < 7 then inc(PilotNdx.h) {next flip shape}
               else FlipInProgress := False {flip is over.. reset normal status}
         else
               If PilotNdx.h > 1 then dec(PilotNdx.h) {next flip shape}
               else FlipInProgress := False; {flip is over.. reset normal status}
      end { if flipinprogress}
   Else {normal pilot... not flipping}
      CopyBits(OffScreen,InScreen,OffPilot[PilotNdx.h,PilotNdx.v],
                     R[Pilot],notSrcBic,nil);      {modes on page i-157}

   {copy just pilot sized piece of mask over the new pilot}
   CopyBits(OffScreen,InScreen,OffPilotMask,R[Pilot],srcOr,nil);

   TopCover.bottom := TopCover.bottom - 3;
   BotCover.top := BotCover.top + 3;

   DrawTheCoverDoors;

   If CoverLoops > 0 then dec(CoverLoops)
   Else begin
         PilotStatus := InChamber;{doors are open so begin the game animation}
         EraseRect(BonusRect);
         EraseRect(PenaltyRect);
         EraseRect(ScoreRect);
         EraseRect(LoScoreRect);
         EraseRect(CntlCover);
         For i := 1 to 3 do ShowControl(Radio[i]);
         DrawScoreIntoBox(LoScore^[Difficulty,1].score,tinyLoScore);
         CopyBits(OffScreen,myWindow^.portBits,OffTimerBox,
                           R[TimerBox],srcCopy,nil);{will erase Titlebox}
         {sequence OffPatch and OffPilotMask with current R[Pilot]}
         i := R[Pilot].left - Home.h;
         j := R[Pilot].top - Home.v;
         MoveRect(OffPatch,OffBigChamber.left+i,OffBigChamber.top+j,1);
         err := PBKillIO(SoundParmBlk,false);{kill CoverDoors sound}
         WhichSound := Game;                             {will start GameSound}
      end;{of Else}
End;{of procedure}

procedure CreateLightsArray;{array of 17 rects around chamber}
var
   dir:real;
   mag,i,centerH,
   centerV: integer;
   tpoint: Point;
   tRect:Rect;
begin
   SetRect(tRect,0,0,12,12);
   dir := 0;
   mag := 84;{radius to center of buttons}
   centerh := R[BigChamber].left + ((R[BigChamber].right-R[BigChamber].left) div 2);
   centerV := R[BigChamber].top + ((R[BigChamber].right-R[BigChamber].left) div 2);

   For i := 0 to 15 do begin
         tPoint.h := round(mag * cos(i*2*Pi/16.0))+centerH-6;{-6 for half tRect}
         tPoint.v := round(mag * sin(i*2*Pi/16.0))+centerV-6;
         MoveRect(tRect,tpoint.h,tpoint.v,1);
         Lights[i] := tRect;
   end; {for i :=}
   Lights[16] := Lights[0]; {0 radians is same as 2*Pi radians}
end;

Procedure DrawUpDateStuff;
{will draw all our images in response to Update event,an Update event is
waiting for our newly opened window so will draw our first stuff too!}
var
   tRect: Rect;
   tpoint: Point;
   i: integer;
Begin
   {if the game is paused the screen has been saved in InScreen Bitmap}
   If PauseUnderWay then CopyBits(InScreen,myWindow^.portBits,
                  InScreen.bounds,myWindow^.portRect,srcCopy,nil) {restore screen}
   Else begin
         For i := 16 downto 2 do FrameRect(WindFrame[i]);
         FillRect(WindFrame[1],dkgray);
         FrameRect(WindFrame[1]);

         CopyBits(OffScreen,myWindow^.portBits,OffBigChamber,
                        R[BigChamber],srcCopy,BigChamberRgn);

         DrawTheCoverDoors;{draw the Covers}

         For i := 0 to 15 do begin
               FillOval(Lights[i],dkgray);
            end;{for i :=}

         CopyBits(OffScreen,myWindow^.portBits,OffTargetBox,
                        R[TargetBox],srcCopy,nil);
         CopyBits(OffScreen,myWindow^.portBits,OffAirLock,
                        R[AirLock],srcCopy,nil);
         DrawPicture(pPict[CntlBox],R[CntlBox]);
         If PilotStatus = FreeFlight then FillRect(CntlCover,gray);{update during freeflight}
         CopyBits(OffScreen,myWindow^.portBits,OffScoreBox,
                        R[ScoreBox],srcCopy,nil);

         CopyBits(OffScreen,myWindow^.portBits,OffFrame,
                        R[Door],srcCopy,nil);
         CopyBits(OffScreen,myWindow^.portBits,OffDoorSlide,
                        R[Door],srcCopy,DoorRgn);{mask to inside of door frame}

         Case PilotStatus of
         InChamber:Begin {draw the timerBox instead of title,due to Switcher}
               CopyBits(OffScreen,myWindow^.portBits,OffTimerBox,
                        R[TimerBox],srcCopy,nil);
               tRect := TimeSlide;{indicator area}
               tRect.right := TimeLine + 1;
               FillRect(tRect,black);
            end;{InChamber}
         Otherwise  CopyBits(OffScreen,myWindow^.portBits,OffTitle,
                                    R[Title],srcCopy,nil);
         end;{case Pilotstatus}

         CopyBits(OffScreen,myWindow^.portBits,OffPod[2],
                        R[Pod],srcCopy,nil);

         DrawIntegerIntoBox(Penalty,tinyPenalty);
         DrawIntegerIntoBox(Bonus,tinyBonus);
         DrawScoreIntoBox(AvgScore,tinyScore);
         DrawScoreIntoBox(LoScore^[Difficulty,1].score,tinyLoScore);
      end;{of Else}
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

procedure TakeCareSoundStuff;
Begin
   If SoundParmBlk^.ioResult < 1 then {sound is finished find another/play it}
         Case WhichSound of
         Blue: InitialFourToneSound; {Waltz quit.. so start again}

         Buzz:begin  {buzz pilot touching wall sound,finished so go back to game}
               WhichSound := Game;
               WriteASoundBlock(ptr(Sound[Game]),Buff[Game],TickCount);
            end;{buzz}

         AirDoor,BigDoor,Game:
               WriteASoundBlock(ptr(Sound[WhichSound]),Buff[WhichSound],TickCount);
         end {of case WhichSound}
   Else If (WhichSound = Blue) and (TickCount > ToneDelay) then begin
               inc(NoteCount);
               BlueSound^.sound1Rate := mySongPtr^.pitch[NoteCount,1];
               BlueSound^.sound2Rate := mySongPtr^.pitch[NoteCount,2];
               BlueSound^.sound3Rate := mySongPtr^.pitch[NoteCount,3];
               BlueSound^.sound4Rate := mySongPtr^.pitch[NoteCount,4];
               BlueSound^.duration := 80;

               ToneDelay := mySongPtr^.duration[NoteCount] + TickCount;

               If mySongPtr^.noteCount = NoteCount then NoteCount := 0;

            end; {if TickCount}
End;{of procedure}

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
            KeyDown: TakeCareKeyDown(myEvent);
            ActivateEvt:TakeCareActivates(myEvent);
            UpdateEvt:TakeCareUpdates(myEvent);
            End {of Case}
      Else {no event pending so lets do some game stuff}
         Begin
            If GameUnderWay then begin
                  Case PilotStatus of
                  InChamber:     AnimateOneLoop;{animate Pilot in chamber, gamestuff}
                  OpenDoors:     AnimateCoverDoors;{animate Chamber doors opening}
                  FreeFlight:begin  {animate Pilot over entire window}
                        If not(SoundOn) then begin
                              aTick := TickCount;
                              Repeat Until(TickCount > aTick + 2);{slow down}
                           end;
                        AnimateFreeFlight;
                     end;{case 3};
                  EnterLock:begin      {animate pilot entering airlock door}
                        If not(SoundOn) then begin
                              aTick := TickCount;
                              Repeat Until(TickCount > aTick + 1);{slow down}
                           end;
                        AnimateAirLock;
                     end;{case 4}
                  end;{case PilotStatus}

                  If SoundOn then TakeCareSoundStuff;

               end { if GameUnderWay}

         End; {else no event pending}
   Until Finished;
End;

procedure SetUpMenus;
var
   i: integer;
Begin
   myMenus[1] := GetMenu(appleMenu);   {get menu info from resources}
   AddResMenu(myMenus[1],'DRVR'); {add in all the DA's}
   myMenus[2] := GetMenu(fileMenu);
   myMenus[3] := GetMenu(optionMenu);
   myMenus[4] := GetMenu(worksMenu);
   myMenus[5] := GetMenu(MessageMenu); {this is the backspace message}
   CheckItem(myMenus[3],3,True); {check the Sound item}
   SoundOn := True;  {sound will start on first begin}
   For i := 1 to 4 do
      begin
         InsertMenu(myMenus[i],0);
      end;
   DrawMenuBar;
End;

procedure CloseStuff;
var i:integer;
Begin
   err := PBKillIO(SoundParmBlk,false);{kill sound before quitting}
   WriteResource(ScoreHandle);{write out if changes were flagged..LoScore}
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

   Finished := False;                  {set terminator to false}
   FlushEvents(everyEvent,0);    {clear events}
   Screen := ScreenBits.Bounds;  { Get screen dimensions from thePort }
End;

{Main Program begins here}
BEGIN
   InitThings;
   SetUpMenus;
   CreateWindow;           {load window,dialogs}
   CreateControls;         {our buttons, and radio controls}
   CreateRegions;       {newRgn for all our regions}
   CreateOffScreenBitMap;  {see Apple tech note 41,create OffScreen,InScreen}
   CreatePictures;         {load pictures from resources}
   DrawPicsIntoOffScreen;{draw the pics into the OffScreen Bitmap}
   CreateOffScreenRects;   {set all rectangles for 'copybits' shape drawing}
   CreateSound;               {create all the sound buffers, etc}
   OneTimeGameStuff;       {Game varibles, scorebox stuff,etc}
   CreateLightsArray;      {array of rects for drawing indicator lights}
   GameUnderWay := False;{click on Pod will begin a game sequence, mousedown event}
   WhichSound := Silence;
   For Dh := 1 to 3 do ShowControl(Radio[Dh]);{these are our difficulty controls}
   MainEventLoop;    {manage all user input until quit}
   CloseStuff;          {do this before quitting... always kill sound before quit}
END.
