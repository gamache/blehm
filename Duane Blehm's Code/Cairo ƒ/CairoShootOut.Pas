Program CairoShootOut;{Copyright © 1987 by Duane Blehm, All Rights Reserved,
Distribution of this SourceCode is strictly prohibited!}

{version 1.2, fixes bug in formula to find random Char's for targets}
{disclaimer: We make not claims about the 'elegance' of this code.  We are
relatively new to Pascal and to Mac specific memory management, etc.  Our
trial and error code will seem crude to anyone experienced in these matters.
... but we just keep on learning and having fun!  If you find any 'for sure'
Errors, let us know.}

{A couple of procedures dealing with the 'Double KeyCode Lock' scheme
have been removed from this code.  Also the game resulting
from compiling this code will not execute very well beyond the first
few levels; however as an example of how the game works the code
is otherwise complete.  Please do not distribute any copys of the
game produced by compiling this code!  The Copy of 'Cairo ShootOut!'
on this disk is complete in every way.}

{we have a growing library of 'crude' utilitys for creating the various
'custom' resources used in this and our other programs.  For instance
we've written one to create our 'RGN ' resources which are 'tracings' of
picture outlines used to mask irregular shapes for use with CopyBits. We
have a couple that take resources created with MacroMind's Music to
Video utility (from MusicWorks data) and create our 'SONG' resources.
Also one that reads text from a text file data fork and creates the
'TBUF' text resources we use with the TextBox() rom call.  We noticed the
'bmap' resource type in ResEdit and came up with procedures to save and
'get' this type resource which can result in significant savings of space
and code in the late stages of program developement.  Including all this
stuff is beyond the scope of this code.  However, if you are interested
in specific (not elegant) code, it is available.  Drop us a line about
what you'd like to see plus $15 and we'll send you a disk on
'how we did it'.}

{note this version executes GameLoop level#1 at approx. 4 ticks/loop
or 15 loops/ second}
{also does away with Cairo font,had to write myTextBox() to draw clues
between levels with myCFPtr (Cairo font bitimage)}

USES MacIntf,MacPrint;{we may have to print the order form}

{$T APPL NILE set the TYPE and CREATOR}{TML Pascal Directives}
{$B+ set the application's bundle bit }
{$L aCairo.rsrc}{link all our resource stuff}

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
   LastTarget = 7;{number of targets in list}
   MaxInteger = 32767;

TYPE
   {type Dialogs and Sounds so we can access them by name}
   DialogList = (Help,About,ClueDial,BMap,Tomb,Guard,What,
                     UnLock,Source,Scores,Name,SetSpeed,PrintDial);
   SoundList = (GunShot,GoodHit,BadHit,Miss,BonusSnd,TimeOut,
            SnakeCharmer,Walk,Silence);

   {type bmap for loading previously created 'bmap' resources}
   BmapRec = Record
      baseAddr:Ptr;
      rowBytes:integer;
      bounds:Rect;
      bitStart:array[1..1] of byte;{so we can Ptr to start of BitImage}
   end;
   BmapPtr = ^BmapRec;
   BmapHand = ^BmapPtr;

   {to get bmap's we created the BitMaps as in the Animation Example, then
   drew the pictures,etc... then called the following to make the bmap:

   procedure CreateBMaps(addBits:Boolean);
   var
      theErr:OsErr;
      myBMap:BmapHand;
   Begin
      (*make a copy of the Bitmap with a Handle*)
      myBMap := BmapHand(NewHandle(SizeOf(BitMap)));
      myBMap^^.rowBytes := OffScreen.rowBytes;
      myBMap^^.bounds := OffScreen.bounds;
      (*now stick a copy of the BitImage on the end of the Handle*)
      If addBits then theErr := PtrAndHand(OffScreen.baseAddr,
                        Handle(myBMap),GetPtrSize(OffScreen.baseAddr));
      (*watch out for memory errors!*)
      AddResource(Handle(myBmap),'bmap',128,'offscreen');
      If theErr <> noErr then SysBeep(1);(*our PtrAndHand probably failed*)
   End;

   this is more efficient than a lot of pictures, creating Bitmaps,
   drawing, locating rects, etc... however locking all this down too soon
   in development process could hinder making changes later on....}

   ScoreNText = Record  {record for hiscores}
      nameStr:Str255;{we'll pack 4 names into NameStr}
      level:array [1..4] of Longint;
      score:array [1..4] of Longint;
   end;
   ScorePtr = ^ScoreNText;

   {at one time we included the Cairo font in resources, loaded it and made
   copies of Bitimage and locate table... but came up with this record to
   store only the parts we needed!.. see 'CairoFont.pro' file for more info}
   CFRec = Record {resource contains only bitimage and locate table of Cairo}
         bitImage:Array[1..105,1..24] of integer;{char. bitimage}
         locate:Array[0..130] of integer;{partial location table}
      end;
   CFPtr = ^CFRec;
   CFHandle = ^CFPtr;

   {note: it is easy to create a resource... just create the data with a
   handle to it... do an AddResource()..copy/paste it into application
   resource file and reverse the procedure to load it into application.}

   nrctRec = Record  {so we can load a list of rects from resource}
      num:integer;{Number of records}
      theRects:array[1..100] of Rect;{limits on # of rects??}
      end;
   nrctPtr = ^nrctRec;
   nrctHandle = ^nrctPtr;

   ClueRec = Record{record of stuff for drawing clues between levels}
      message:Str255;   {message for this clue}
      messRect:Rect; {box to contain message.. TextBox()}
      hint:Str255;      {clue word}
      hintRect:Rect;
      just:integer;     {justification for hint textbox,all messages centered}
      glyphPic:PicHandle;{heiroglyph picture from resource}
      dialHand:Handle;{handle to textitem in dialog}
      dialWord:Str255;{string contains user input}
      end;

   SongRec = Record {import a song record from our snake 'SONG' resource}
      noteCount:integer;{how many notes in this song}
      pitch:array[1..48,1..2] of Longint;{48 notes,2 voices}
      duration:array[1..48] of integer;{how many ticks will pitch play}
      end;
   SongPtr = ^SongRec;
   SongHandle = ^SongPtr;

   WSongRec = Record {import a song record from our Walk 'SONG' resource}
      noteCount:integer;{how many notes in this song}
      pitch:array[1..68,1..2] of Longint;{68 notes,2 voices}
      duration:array[1..68] of integer;{how many ticks will pitch play}
      end;
   WSongPtr = ^WSongRec;
   WSongHandle = ^WSongPtr;
   {note:could have used same song type for both songs except for # of notes,
   We'll change the Record to be note 'independent' next time.}

   TimeBonusRec = Record  {stuff for display of Time-to-Score at end of level}
      frame:Rect;    {size window for Timebonus}
      hourmove:Point;   {offset for hourglass...move from normal position}
      numbox:Rect;      {frame for numbers}
      arrowDest:Rect;   {destination for copybits of arrow}
      arrowSource:Rect;{source in Cairo bitmap}
   end;

   TargetRec = Record   {record of individual targets on display}
      theChar:integer;{character in the font}
      head:integer;     {pixOff when the target begins in Wings}
      wide:integer;     {width of target}
   end;

   ValidRec = Record {record for scorebox and score targets}
      which:integer; {which char in font}
      points:integer;   {points for hitting this target}
      remain:integer;   {how many of this target left to hit}
      remainPt:Point;   {for finding moveto point for drawString}
      blankRect:Rect;   {erase rect for drawing remain # into scorebox}
      centerPt:Point;   {top,centerline of box in scoreframe}
   end;

   StatusRec = Record {4 boxes for score,hiscore,etc}
      blankRect:Rect;   {rect to erase before drawing new number}
      centerPt:Point;   {for finding MoveTo point before DrawString}
   end;

VAR
   {local var's made global.. for speed of execution of code}
   unNames:          array[1..4] of Str255; {unpack our hiscore names}
   RListHand:           nrctHandle;
   si,sj:               integer;{StartOne and StaggerOne}
   di,dj,dk,dm:         integer;{DetectAHit and HandlAHit}
   HitAValidTarget:  boolean;

   GameOver:            Boolean;    {set True if hourglass empty}
   myRects:          nrctHandle; {access to Rects in nrct resource}
   TarWindPic:       PicHandle;     {pic of our collective windows}
   myCFPtr:          CFPtr;         {access to Cairo font stuff in resources}
   SpeedTrapOn:         Boolean;    {if true slow down the game}
   SpeedFactor,
   SpeedTicks:       Longint;    {rate of delay / slow down}
   theHighs:            ScorePtr;      {access to hiscore record/handle}
   ScoreHandle:         Handle;        {handle to hiscore resource}
   NameString:       Str255;        {store our players name for hiscore}
   BuffSize:            Longint;    {size buffers}
   PagePrint:           THPrint;    { handle to the page setup record   }
   ResRefNum:           integer;    {reference number for appl.resource file}
   tBuf:                Handle;        {text from TBUF resource for TextBox}
   ClueNdx:          integer;    {point to next clueword}
   ClueWords:           Array[1..10] of Str255; {hold various possible clues}
   DialNdx:          DialogList; {will step through our dialogs array}
   myDialog:            Array[Help..PrintDial] of DialogPtr;
   myDialogRec:         Array[Help..PrintDial] of DialogRecord;
   Tut:                 Array[168..171] of PicHandle;    {for drawing tomb}
   ClueShadow:       PicHandle;     {shadow the booth to hilight clue}
   ClueErase:           Rect;          {rect for erase before Clues}
   Clues:               Array[1..4] of ClueRec; {our awards..}
   FetchChar:           Rect;          {used in startOne... constant top/bottom}
   CursorNdx:           integer;    {which cursor to use}
   myCursor:            Array[1..3] of CursHandle;{our three cursors}
   StartPitch:       Array[1..4] of Longint;{pitches to start targetsound}
   UpDateMap:           BitMap;        {keep a copy of targetwindows during pause}
   UpDateRect:       Rect;          {for copybits of bitmap}
   ResumeButton,
   EndButton:           ControlHandle; { handles to controlbuttons }
   RedrawRect:       Rect;          {area for invalRect for levels}
   TimeCount:           integer;    {interval between hourglass moves}
   TBone:               TimeBonusRec;{hold all our timebonus stuff}
   ShadowRect:       Rect;          {rect used to shadow booth interior}
   LastValid:           integer;    {number of Score targets..max of 6}
   Score,HiScore,
   Level,MissCount:  Longint;
   StatPic:          PicHandle;     {Status is pic of Score/HiScore frame}
   StatList:            Array[1..4] of StatusRec;{stuff for drawing Scores,etc}
   ValidDone:           Boolean;    {flag is all valids have 0 remain}
   Direction:           Array[1..3] of integer;{scroll right or left}
   Vector:              Array[1..3] of integer;{will be product of speed and direction}
   TarWindRgn:       RgnHandle;  {region to mask drawing eye in TarWindow[4]}
   BonusMap:            BitMap;     {load from bmap resource, contains BTarget pics}
   OffBonus:            Array[1..6,1..2] of Rect;{Rects to shapes in BonusMap}
   BonusNdx:            integer;    {pointer to OffBonus rects, 1-6}
   BonusShape:       integer;    {pointer to 1 of two shapes,internal anim.}
   BonusRect:           Rect;          {onScreen Rect for CopyBits of Bonus Shapes}
   BonusUnderWay:    Boolean;    {is bonus underway?}
   BonusLoops,
   PrevBonusLoops:      integer;    {count for # of loops}
   BonusSpeed:       integer;    {-4 to +4 lateral movement...left or right}

   MouseRect,
   GunLimit:            Rect;          {limit movement of site during game}
   GameUnderWay:        Boolean;
   PauseStatus:         integer;    {0 no pause,1 game pause, 2 clue pause}
   NowValid:            Array[1..6] of integer;{list of Valids with targets remaining}
   NowNdx:              integer;    {index for NowValid}
   ScoreNumRect,
   ScoreFrameRect:      Rect;
   ScoreNum,
   ScoreFrame:       PicHandle;     {for drawing ScoreBox frame}
   tPt:                 Point;
   tFlag:               Boolean;
   tRect,sRect,dRect:   Rect;          {global temporary varibles}
   LeftSide,RightSide,
   BackSide:            PicHandle;     {our shooting gallery pics}
   Valid:               Array[1..6] of ValidRec;{list of valid targets}

   OffHour,Hour,                       {hourglass}
   OffBotSand,OffTopSand,           {frame complete top and bottom sand}
   OBSand,BotSand,                     {partial top and bottom sand,for animation}
   OTSand,TopSand:      Rect;
   TrickleTop,
   TrickleBot:       Point;         {left sand trickle (line) top and bottom}
   TrickTopR,
   TrickBotR:           Point;         {points for drawing right sand trickle line}
   TrickleLeft:         Boolean;    {true if trickle currently leftside}
   BotSandRgn,
   TopSandRgn:       RgnHandle;     {regions for masking sand into hourglass}

   {for drawing spot targets in side windows}
   SpotSpeed:           Array[5..6] of integer;{window 5&6,speed of target}
   OffSpotTarget:    Rect;          {whole spot}
   OffSpot:          Array[5..6] of Rect;{partial spot...}
   SpotRect:            Array[5..6] of Rect;{locate spot on screen}
   TopSpot,BotSpot:  Array[5..6] of integer;{turn around point for spots,speed}

   TarList:          Array[1..3,1..LastTarget] Of TargetRec;{targets on Screen}
   NxtTar,              {points to TarList element}
   Speed,PixOff:        Array[1..3] of integer;{pixoff= # of pixels target moves}
   HitWhich,            {which target in the window target list}
   HitWindow:           integer;    {which window hit was made in}
   Hit:                 Boolean;    {true if a target was hit}
   TargetCenter:        Point;      {point at center of Rect pointed to by mouse/site}
   myMenus:          Array[1..lastMenu] of MenuHandle;
   refNum,theMenu,
   theItem:          integer;
   Finished:            Boolean;    {used to terminate the program,quit}
   ClockCursor:         CursHandle; {handle to watch cursor}
   myWindow:            WindowPtr;
   wRecord:          WindowRecord;{we alocate window on the stack}
   Screen,DragArea:  Rect;          {set limits of drag area}
   myMouse:          Point;         {used with GetMouse in animateoneloop}
   aTick:               Longint; {usually with TickCount but sometimes just temp.}

   ExplodeRect,
   OffExplode:       Rect;          {Rects to explode shape in offscreen}
   WhichGun:            integer;    {which gun to draw for gray backgound}
   GunRect:          Rect;          {destination rect for drawing Gun}
   OffGun,OffSite:      Array[0..1] of Rect;{two guns, for drawing over gray}
   TarWindow:           Array[1..6] of Rect;{our targets windows..6 of them}
   ShotFired:           Boolean;
   Piece,OffPiece:      Array[1..3] of Rect;{rects to tiny area left after scroll}
   SiteRect:Rect;
   SiteRgn:          Array[0..1] of RgnHandle;{for drawing site into OffGun rects}
   myPattern,
   myDiagPat:           Pattern;    {patterns for drawing shading}

   FontMap:          BitMap;        {Cairo font bitimage from resource,myCFPtr}
   Wings:               Array[1..3] of BitMap;{new targets just coming into window}

   tStr:                Str255;
   tPtr:                Ptr;
   tLong:               Longint;

   OffScreen,OldBits:   BitMap;        {for drawing into offscreen}
   tRgn:                RgnHandle;
   Counter:          integer;    {count loops for hourglass/time}
   i,j,k,m,n:           integer;

   {Sound varibles}
   Buff:                Array[GunShot..TimeOut] of Longint;{for Sound buffers}
   myPtr:               Ptr;
   myHandle:            Handle;
   Sound:               Array[GunShot..SnakeCharmer] of FFSynthPtr;{FreeForm synthesizer sound}
   SnakeSynth:       FTSynthPtr; {Snake is a FourTone sound/use for Walk too}
   SnakeSound:       FTSndRecPtr;   {two FourTone Sounds}
   SoundParmBlk:        ParmBlkPtr;    {used for PBWrite instead of StartSound}
   WhichSound:       SoundList;     {which sound is being played?}
   err:                 OSerr;
   SawToothWave:        wavePtr;
   SquareWave:       wavePtr;
   mySongPtr:           SongPtr;    {snake song}
   myWSongPtr:       WSongPtr;      {walk song.. different # of notes}
   ToneTicks,
   ToneDelay:           Longint;    {# of ticks each song pitch will play}
   NoteCount:           Longint;    {# of notes played for song}
   SoundOn:          Boolean;    {user request for sound off/on}
{----------------------------------------------}
procedure SetCursorMenus(StartGame:Boolean);
var i:integer;
Begin
   If StartGame then begin {starting the game}
         InsertMenu(myMenus[5],0);  {display 'any key to exit' message}
         For i := 1 to 4 do DisableItem(myMenus[i],0);{disable (gray) others}
         DrawMenuBar;                  {draw the menus}
         GameUnderWay := True;   {we're back into game mode}
         HideCursor;
         FlushEvents(mDownMask,0); {clear all mouseDowns}
      end
   Else Begin  {interrupt the game}
         If CursorNdx < 3 then inc(CursorNdx) else CursorNdx := 1;
         SetCursor(myCursor[CursorNdx]^^);{display one of our 3 cursors}
         ShowCursor;
         GameUnderWay := False;
         DeleteMenu(MessageMenu);   {remove exit message,i-354}
         For i := 1 to 4 do EnableItem(myMenus[i],0);{show other menu options}
         DrawMenuBar;
      end;
End;

procedure DrawStatus(which:integer;amount:Longint);
{draw score,missCount, etc. into Stat frame}
Begin
   NumToString(amount,tStr);{convert number to string}
   MoveTo(StatList[which].centerPt.h-(StringWidth(tStr) div 2),
                        StatList[which].centerPt.v);{center it}
   EraseRect(StatList[which].blankRect);{erase last}
   DrawString(tStr);{draw it!}
end;

{myTextBox is similar to TextBox() rom but uses Cairo BitImage in myCFPtr}
procedure myTextBox(text:Ptr;length:Longint;box:Rect;just:integer);
var
   StartLine:Ptr;
   EndLine,TestEnd:Ptr;
   LineWidth,TestWidth:integer;
   Done:Boolean;
   which:byte;
procedure DrawLine;
var
   index:Longint;
Begin
   Case just of {justification....find starting point for first dRect}
   -1: dRect.left := box.right - LineWidth; {right}
   0: dRect.left := box.left;{left}
   1: dRect.left := box.left + ((box.right-box.left-LineWidth) div 2);{center}
   end;{case}
   For index := ord(StartLine) to ord(EndLine) do begin
         If Ptr(index)^ <> 32 then begin {Ptr(index)^ points to which}
               sRect.left := myCFPtr^.locate[Ptr(index)^];
               sRect.right := myCFPtr^.locate[Ptr(index)^+1];
               dRect.right := dRect.left + sRect.right-sRect.left;
               CopyBits(FontMap,myWindow^.portBits,sRect,dRect,srcCopy,nil);
               dRect.left := dRect.right + 2;{move over for next char}
            end{if Ptr(}
         else dRect.left := dRect.right + 10;{for space char}
      end;{for index}
End;

procedure InitialLine;
Begin
   StartLine := EndLine;
   TestEnd := Endline;
   LineWidth := 0;
   TestWidth := 0;
end;

procedure NewLine;
Begin
   OffSetRect(dRect,0,28);{move down a line,font height + 4}
   EndLine := Ptr(ord(EndLine)+1);{end currently a space so move one}
   {could test here for more spaces!}
   InitialLine;
End;

Begin
   SetRect(sRect,0,0,0,24);{height of 24 for Cairo}
   If length > 0 then length := length -1;{we're zero based}
   {initialize varibles}
   EndLine := text;
   InitialLine;
   dRect.top := box.top;
   dRect.bottom := dRect.top + 24;{fHeight := 24 for Cairo}
   Done := false;
   EraseRect(box);
   Repeat
      which := TestEnd^;
      If which <> 32 then begin {break lines on spaces}
            TestWidth := TestWidth + myCFPtr^.locate[which+1] -
                                             myCFPtr^.locate[which] + 2;
            {test for end of text here}
            If ord(TestEnd) >= (ord(text) + length) then Begin {end of text}
                  If TestWidth > (Box.right-Box.left) then begin {line too long}
                        DrawLine;
                        NewLine;{set TestEnd back to Last EndLine and continue}
                     end
                  else begin {line width ok so draw it all}
                        EndLine := Ptr(ord(text)+length);{set to end of text}
                        LineWidth := TestWidth;{approx width?}
                        DrawLine;
                        Done := True; {we're finished}
                     end;{else}
               end;{if ord}
         end{if which}
      else begin {current which is a space}
            TestWidth := TestWidth + 10;{width of my space}
            If TestWidth > (Box.right-Box.left) then begin {word won't fit}
                  DrawLine;{draw the line without Test stuff on end}
                  NewLine;
               end
            else begin {move actual end of line up to testend}
                  EndLine := TestEnd;
                  LineWidth := TestWidth;
               end;{else }
         end;{else}
      TestEnd := Ptr(ord(TestEnd)+1);{move TestEnd up one}

   Until(Done);
End;

procedure DrawAClue(index:integer);{clues are displayed on even levels 2-8}
Begin
   DrawPicture(ClueShadow,ClueShadow^^.picFrame);{shadow on booth}
   EraseRect(ClueErase);{erase the background in target area}
   {draw one of 4 glyph pictures}
   DrawPicture(Clues[index].glyphpic,Clues[index].glyphpic^^.picframe);
   {myTextBox uses Cairo bitimage in FontMap to display text}
   myTextBox(Pointer(ord(@Clues[index].message)+1),Length(Clues[index].message),
                     Clues[index].messRect,teJustCenter);{draw message}
   myTextBox(Pointer(ord(@Clues[index].hint)+1),Length(Clues[index].hint),
                     Clues[index].hintRect,Clues[index].just);{draw clueword}
End;

procedure DrawRemainIntoScoreBox(which:integer);
{draw # of targets remaining for 'which' Valid target}
Begin
   EraseRect(Valid[which].blankRect);{erase last}
   NumToString(Valid[which].remain,tStr);
   MoveTo(Valid[which].remainPt.h-(StringWidth(tStr) div 2),
                        Valid[which].remainPt.v);{center it}
   DrawString(tStr);
end;

procedure PaintAShadow(aRect:Rect);{used to shade booth and Valid targets}
Begin
   PenMode(patOr);{ will combine pattern with existing background}
   PenPat(myDiagPat);{diagonal lines}
   PaintRect(aRect);{fill aRect with the pattern... mode 'or'}
   PenNormal;        {reset the Pen stuff to default}
end;

procedure DrawHourGlass;{draw hourglass and top/bottom sand}
Begin
   CopyBits(OffScreen,myWindow^.portBits,OffHour,Hour,srcCopy,nil);{hourglass}
   {OTSand & OBSand rects are moving over Sand pics on OffScreen}
   CopyBits(OffScreen,myWindow^.portBits,OTSand,
                              TopSand,srcCopy,TopSandRgn);{top Sand}
   CopyBits(OffScreen,myWindow^.portBits,OBSand,
                              BotSand,srcCopy,BotSandRgn);{Bottom sand}
end;

procedure SizeRectsForBox(whichchar,whichbox:integer);
{for drawing char/targets into scorebox each level and updates}
Begin
   {sRect.top and bottom are constant.. fontMap.bounds}
   sRect.left := myCFPtr^.locate[whichchar];{left point from locate table}
   sRect.right := myCFPtr^.locate[whichchar+1];{right point from locate table}
   {center tRect in its ScoreBox}
   tRect.left := Valid[whichBox].centerPt.h - ((sRect.right-sRect.left) div 2);
   tRect.right := tRect.left + (sRect.right-sRect.left);
End;

procedure DrawTargetsInScoreBox;
Begin
   {draw the targets into the scoreBox}
   sRect := FontMap.bounds;{bounds rect of FontMap bitmap,top/bottom constant}
   For i := 1 to LastValid do begin {4-6 scoreboxes}
         tRect.top := Valid[i].centerPt.v;{topcenter of box}
         tRect.bottom := tRect.top + 24;{height of font}

         SizeRectsForBox(Valid[i].which,i);{size sRect/tRect left and right}

         CopyBits(FontMap,myWindow^.portBits,sRect,tRect,srcCopy,nil);
         DrawRemainIntoScoreBox(i);{# remaining, draw just below target}
         if Valid[i].remain = 0 then begin {disabled shading over box}
               tRect := Valid[i].blankrect;
               tRect.top := Valid[i].centerPt.v;{tRect now is whole box}
               PaintAShadow(tRect);
            end;{if valid remain}
      end;
End;

procedure DrawWindowContents(WhichWindow:WindowPtr);{update events}
Begin
   DrawPicture(BackSide,BackSide^^.picFrame);{back/center of booth}
   DrawPicture(LeftSide,LeftSide^^.picFrame);{left side of booth}
   DrawPicture(RightSide,RightSide^^.picFrame);{right side of booth}
   DrawPicture(ScoreFrame,ScoreFrameRect);      {score box frame}
   DrawPicture(ScoreNum,ScoreNumRect);       {points in score box}
   DrawPicture(StatPic,StatPic^^.picFrame);  {status/score box frame}
   DrawHourGlass;       {hourglass stuff}
   DrawStatus(1,Level);{four varibles in status box, score etc.}
   DrawStatus(2,Score);
   DrawStatus(3,MissCount);
   DrawStatus(4,HiScore);

   Case PauseStatus of
   {PauseStatus tells us 'how' the screen 'looks',what to draw}
   0:Begin {no pause.. usually in between  games}
         DrawPicture(TarWindPic,TarWindPic^^.picFrame);
         If not(GameUnderWay) then begin
               PaintAShadow(ShadowRect);{shadow the booth interior}
               DrawTargetsInScoreBox;
            end;
      end;{case 0}
   1,2:Begin   {game under way pause...1 = keydown interrupt?, 2 = clue}
         If PauseStatus = 1 then CopyBits(OffScreen,mywindow^.portBits,
                           OffGun[whichGun],GunRect,srcCopy,nil);{redraw gun}
         DrawTargetsInScoreBox;
         If PauseStatus = 2 then DrawAClue(Level div 2) {clue on display}
         else {Copy from UpDateMap... contains copy of targets, when pause began}
            CopyBits(UpDateMap,myWindow^.portBits,UpDateMap.bounds,UpDateRect,
                        srcCopy,nil);
      end;{case 1,2}
   end;{case pauseStatus}

   DrawControls(myWindow);{draw Continue/End buttons if they're not hidden}
End;

procedure UpdateMyWindow;
Begin
   BeginUpDate(myWindow);
   EraseRect(myWindow^.portRect);{will be clipped to update rgn}
   DrawWindowContents(myWindow);
   EndUpDate(myWindow);
End;

procedure DrawBoldButton(WhichDialog:DialogList);{bold button in dialogs}
var
   tHand:Handle;{j:integer,tRect:Rect}
Begin
   PenSize(3,3);
   GetDItem(myDialog[WhichDialog],1,j,tHand,tRect);{frame Item #1}
   InsetRect(tRect,-4,-4);
   FrameRoundRect(tRect,16,16);
   PenSize(1,1);
End;

procedure DisplayWhatDialog(WhichDialog:DialogList);{called from Guard dialog}
var
   tRect,fRect:   Rect;
   itemHit,i,j: integer;
   tPort: GrafPtr;
Begin
   GetPort(tPort);
   ShowWindow(myDialog[WhichDialog]);{all dialogs are hidden}
   SelectWindow(myDialog[WhichDialog]);{bring it to the front, activate}
   SetPort(myDialog[WhichDialog]);  {so we can draw into our dialog window}
   tBuf := GetResource('TBUF',127);{load our text from resource}
   HLock(tBuf);{lock it down, so we can use a ptr, don't want it moving on us}
   TextFont(3);
   TextSize(9);
   {draw text into dialog window}
   TextBox(tBuf^,GetHandleSize(tBuf),myDialog[what]^.portRect,teJustLeft);
   HUnLock(tBuf);{done}
   DrawBoldButton(WhichDialog);
   ModalDialog(Nil,itemHit);

   HideWindow(myDialog[WhichDialog]);
   SetPort(tPort);{restore port}
end;

procedure DrawOrderForm(frame:Rect);{for printing}
var
   tRect:Rect;
   tStr:Str255;
   myHandle:Handle;
Begin
   {all drawing is being done into the printer port/bit map}
   TextFont(geneva);
   TextSize(10);
   tRect := frame;{size of printing output}
   tRect.top := tRect.top + 130;{reserve 130 pixels for our header}
   InsetRect(tRect,20,0);{shink the page size}
   {draw page stuff here}
   HLock(tBuf);{tbuf loaded in the DoPrint procedure}
   TextBox(tBuf^,GetHandleSize(tBuf),tRect,teJustCenter);{draw it }
   HUnLock(tBuf);
   tRect := Clues[3].glyphpic^^.picframe;{Chariot glyph pic, upper left}
   OffSetRect(tRect,frame.left+20-tRect.left,frame.top+10-tRect.top);
   DrawPicture(Clues[3].glyphpic,tRect);

   GetIndString(tStr,1000,7);{source of copy of program}
   tRect.top := tRect.top + 10;{relocate tRect from pic above}
   tRect.left := tRect.right + 10;
   tRect.right := tRect.left + 100;
   tRect.bottom := 129;
   TextBox(Pointer(ord(@tStr)+1),Length(tStr),tRect,teJustLeft);

   TextSize(12);
   GetIndString(tStr,1000,5);{logo text stuff,upper right}
   tRect := frame;
   tRect.top := tRect.top + 10;
   tRect.left := tRect.right - 180;
   tRect.bottom := 129;{just above completed textbox!}
   TextBox(Pointer(ord(@tStr)+1),Length(tStr),tRect,teJustLeft);

   OffSetRect(tRect,-186,0);
   tRect.bottom := tRect.top + 32;
   tRect.left := tRect.right - 32;{for drawing logo icon}
   myHandle := GetIcon(130);
   PlotIcon(tRect,myHandle);

   MoveTo(Frame.left + 20,Frame.top + 120);{just below glyph pic}
   TextSize(12);
   TextFace([Bold,Shadow]);
   DrawString('Cairo #1 KeyCode = ');
End;

procedure DoPrintUpdates;{Printer dialogs erase the windows behind them so
update myWindow,Guard dialog,display PrintDialog}
{there has got to be a better way of updating while dialogs are on display..
perhaps by using Modeless dialogs and handling all events in the program rather
than calling ModalDialog()}
var
   EventFlag,Result:Boolean;
   tPort:GrafPtr;
   myEvent:EventRecord;
   itemHit:integer;
   Digit:Char;
Begin
   GetPort(tport);
   SetPort(myWindow);
   UpdateMyWindow;{dialogs have erased our window so do updates}
   SetPort(myDialog[Guard]);{do updates pending for dialog}
      Repeat
         Result := GetNextEvent(everyEvent,myEvent);{mask only Updates?}
         EventFlag := IsDialogEvent(myEvent);
         If EventFlag then
               Result := DialogSelect(myEvent,myDialog[guard],itemHit)
      Until(not(EventAvail(EveryEvent,myEvent)));

   ShowWindow(myDialog[PrintDial]);{our 'cancel printing' dialog}
   SelectWindow(myDialog[PrintDial]);
   SetPort(myDialog[PrintDial]); {so we can draw into our dialog window}
   Digit := chr(17);{this is the 'Commandkey symbol'}
   tStr := concat(Digit,' .');
   ParamText(tStr,'','','');{install command key-period into dialog ^0}
         Repeat
         Result := GetNextEvent(everyEvent,myEvent);{do updates}
         EventFlag := IsDialogEvent(myEvent);
         If EventFlag then
               Result := DialogSelect(myEvent,myDialog[PrintDial],itemHit)
         Until(not(EventAvail(EveryEvent,myEvent)));
   SetPort(tPort);{restore port and get back to printing stuff}
End;

procedure DoPrint;{print the order form}
var
   myPrPort:TPPrPort;
   myStRec:TPrStatus;
   tPort:GrafPtr;
begin
   GetPort(tPort);{we'll be changing to printer port, so get copy of current}
   tBuf := GetResource('TBUF',128);{order form text,had error during OpenPage?}
   PagePrint := THPrint(NewHandle(SizeOf(TPrint)));{create our print record}
   PROpen;{open the print manager!! ii-157}
   If PrError = noErr then begin
      PrintDefault(PagePrint);{fill with default values ii-158}
      {tFlag := PrStlDialog(PagePrint);this is page setup stuff}
      If PrJobDialog(PagePrint) then begin {dialog with user}
            DoPrintUpDates;{clean up our windows,display 'cancel' dialog}
            myPrPort := PrOpenDoc(PagePrint,nil,nil);
            PrOpenPage(myPrPort,nil); { start new page}
            If PrError = noErr then
                  DrawOrderForm(PagePrint^^.prInfo.rPage);{draw my page}

            PrClosePage(myPrPort);

            PrCloseDoc(myPrPort);
            If (PagePrint^^.prJob.bjDocLoop = bSpoolLoop) AND
                                                    (PrError = noErr) then
                     PrPicFile(PagePrint,nil,nil,nil,myStRec);

            {If PrError <> noErr then alert user of printing error}
         end;{if user says then open the printing job}
      end;{if PROpen successfull}
   PRClose;{close the print manager}
   HideWindow(myDialog[PrintDial]);{close our cancel/command-period dialog}
   SetPort(tPort);
End;

procedure DisplayAlert(WhichAlert:integer;Var result:integer);
var
   tPort:GrafPtr;
Begin
   GetPort(tPort);
   result := NoteAlert(WhichAlert,nil);{display the alert}
   ResetAlrtStage;{i-423}
   SetPort(tPort);
End;

procedure SetControlValue(which:integer);
{for SetSpeed dialog,which item#, the radio controls are numbered 2 thru 4}
var
   i,h:integer;
Begin
   For i := 2 to 4 do begin {reset controls to user selected control,which}
         GetDItem(myDialog[SetSpeed],i,h,myHandle,tRect);
         If i = which then SetCtlValue(ControlHandle(myHandle),1)
         else SetCtlValue(ControlHandle(myHandle),0);
      end;
   Case which of
   2: SpeedTrapOn := False;{normal mode... no delays}
   3,4:begin
         SpeedTrapOn := True;{flag that delays are needed}
         If which = 3 then SpeedFactor := 2
         else SpeedFactor := 3;{how much delay.. 2 or 3 ticks}
      end;
   end;{case which}
End;

procedure DisplayDialog(WhichDialog:DialogList);{from dialog list}
var
   tRect,fRect,messFrame,itemRect:  Rect;
   itemHit,i,j,theType: integer;
   tPort: GrafPtr;
   tHandle: Handle;
   index:integer;
Begin
   GetPort(tPort);
   ShowWindow(myDialog[WhichDialog]);{dialogs are hidden in resource}
   SelectWindow(myDialog[WhichDialog]);{bring to front, activate}
   SetPort(myDialog[WhichDialog]);  {so we can draw into our dialog window}

   FlushEvents(mDownMask,0); {clear all mouseDowns}

   DrawBoldButton(whichDialog);{draw item one button bold, Enter key default}
   Case WhichDialog of
   Help:
         ModalDialog(Nil,itemHit);  {close it no matter what was hit}
   About:begin
      aTick := 1;{for a delay}
      Repeat
         ModalDialog(Nil,itemHit);
         If itemHit = 8 then begin {animate the chariot from OffScreen}
               SetRect(tRect,0,0,43,19);{size of one chariot}
               fRect := tRect;
               OffSetRect(tRect,OffScreen.bounds.right-tRect.right,
                           OffScreen.bounds.bottom-tRect.bottom);{in offScreen}
               OffSetRect(fRect,myDialog[About]^.portRect.left-fRect.right,
                        myDialog[About]^.portRect.bottom - 2 -fRect.bottom);
               MoveTo(fRect.right,fRect.bottom);
               LineTo(500,fRect.bottom);{baseline}
               {animate until chariot is off right side}
               While (fRect.left < myDialog[About]^.portRect.right) do begin
                  CopyBits(OffScreen,myDialog[About]^.portBits,tRect,fRect,
                                 srcCopy,nil);{draw a chariot}
                  OffSetRect(fRect,3,0);{move destination to right 3 pixels}
                  {make tRect point to one of chariot shapes in ChariotMap}
                  If tRect.right < OffScreen.bounds.right then
                      OffSetRect(tRect,43,0) {move right to next shape}
                  else OffSetRect(tRect,-86,0);{move back to first}
                  Delay(aTick,SpeedTicks);{delay one tick}
               end;{while fRect}
            end;{if itemhit}

      Until(itemHit = 1);
      end;
   ClueDial:{get 4 clue words from user to open tomb}
      Begin
         For i := 1 to 4 do SetIText(Clues[i].dialHand,'');{empty strings}
         SelIText(myDialog[ClueDial],6,0,0);{select first box}
         Repeat
            ModalDialog(Nil,itemHit);{Modal does an Update event for the dialog box}

         Until((itemHit = 1) or (itemHit = 11));{ok button or Pass}

         {exit with Pausestatus = 3 for tomb or 0 for continue}
         If itemHit = 1 then begin {check the user input against hints}
               PauseStatus := 3;
               For i := 1 to 4 do begin {check user input against clues}
                  GetIText(Clues[i].dialHand,Clues[i].dialWord);
                  If Clues[i].hint <> Clues[i].dialWord then PauseStatus := 0;
               end;{for i}

               If PauseStatus = 0 then DisplayAlert(134,i);{sorry, bad clues}
            end{If itemhit}
         else If itemHit = 11 then PauseStatus := 0;{user wants to pass}
      End;{cluedial}

   BMap:begin{peek offscreen bitmap}
         CopyBits(OffScreen,myDialog[BMap]^.portBits,OffScreen.bounds,
                  OffScreen.bounds,srcCopy,nil);   {copy bitmap to dialog box}
         tRect := BonusMap.bounds;
         OffSetRect(tRect,myDialog[BMap]^.portRect.right - 3 - trect.right,
                  myDialog[BMap]^.portRect.bottom - 3 - trect.bottom);
         CopyBits(BonusMap,myDialog[BMap]^.portBits,BonusMap.bounds,
                        tRect,srcCopy,nil); {bonus pics to bottom right}
         DrawBoldButton(whichDialog);
         ModalDialog(Nil,itemHit);  {close it no matter what was hit}
      end;{BMap}

   Tomb:begin
         SetOrigin(70,6);{shrink tut to fit in dialogue window}

         {draw inside of tomb}
         DrawPicture(Tut[170],Tut[170]^^.picFrame);{background}
         tRect := Tut[169]^^.picFrame;
         For i := 1 to 11 do begin
               DrawPicture(Tut[169],tRect);{pics along back wall}
               OffSetRect(tRect,36,0);
            end;
         DrawPicture(Tut[171],Tut[171]^^.picFrame);{tutplatform}
         DrawPicture(Tut[168],Tut[168]^^.picFrame);{tut}

         SetOrigin(0,0);
         GetDItem(myDialog[Tomb],1,j,myHandle,tRect);{erase under button}
         InsetRect(tRect,-2,-2);
         EraseRect(tRect);

         {frame the text box, item #2}
         DrawBoldButton(WhichDialog);
         GetDItem(myDialog[Tomb],2,j,myHandle,tRect);
         InsetRect(tRect,-1,-1);{frame the text item}
         EraseRect(tRect);
         FrameRect(tRect);

         ModalDialog(Nil,itemHit);
      end;{tomb}
   Guard:begin {this is the protection dialog}
         GetDItem(myDialog[Guard],9,theType,tHandle,itemRect);
         tStr := 'disabled';
         GetDItem(myDialog[Guard],13,theType,tHandle,tRect);
         SetIText(tHandle,tStr);
         InsetRect(tRect,-3,-3);
         GetDItem(myDialog[Guard],10,theType,tHandle,messFrame);
         InsetRect(messFrame,-4,-8);{message frame}
         Repeat
            FrameRect(tRect);{this is around our #1keycode}
            FrameRoundRect(messFrame,10,10);{around our message}
            DrawBoldButton(whichDialog);{draw each time in case updates}
            ModalDialog(Nil,itemHit);
            Case itemHit of
            2: DisplayWhatDialog(What);{reinterate dialogs? don't work}
            4: begin
                  DoPrint;{print out our order form stuff}
                  InvalRect(myDialog[Guard]^.portRect);{redraw our Dialog}
                  FlushEvents(KeyDownMask,0);{case of key commands or such}
               end;{4:}
            5: begin {lock the game}
                  {display alert... consequences}
                  DisplayAlert(135,i);
                  If i = 2 then begin {item LOCKIT}
                        Finished := True;{quit the game after lock!}
                        itemHit := 1;{will close the Guard dialog}
                     end; {if i = 2}
               end;
            6: begin {unlock all the features?}
                  GetDItem(myDialog[Guard],7,theType,tHandle,fRect);
                  GetIText(tHandle,tStr);
                  SetIText(tHandle,'disabled');
                  DisplayAlert(136,i);{sorry invalid keycode2}
               end;{6:}
            end;{case itemHit}
            InvalRect(itemRect);{always redraw the Messages:}
         Until(itemHit = 1);{done button}
      end;
   UnLock:begin {at end of Locked levels,about more levels,etc.}
         tBuf := GetResource('TBUF',129);{get text from resource}
         HLock(tBuf);{locked for Ptr}
         TextFont(3);
         TextSize(10);
         TextBox(tBuf^,GetHandleSize(tBuf),myDialog[UnLock]^.portRect,teJustLeft);
         HUnLock(tBuf);
         DrawBoldButton(WhichDialog);
         ModalDialog(Nil,itemHit);
      end;{Unlock:}
   Source:{source code message}
         ModalDialog(Nil,itemHit);  {close it no matter what was hit}
   Scores:begin {hiscore stuff}
         TextFont(3);
         Repeat
         For i := 1 to 4 do begin
               TextSize(9);
               {unpack 4 names stored in theHighs^.nameStr,etc.
               and draw into dialog}
               unNames[i] := copy(theHighs^.nameStr,((i-1) * 23)+1,23);{short}
               MoveTo(7,87+16*i);
               DrawString(unNames[i]);{draw all 4 names}
               TextSize(12);
               Moveto(180,87+16*i);
               NumToString(theHighs^.level[i],tStr);{draw all 4 levels}
               DrawString(tStr);
               NumToString(theHighs^.score[i],tStr);
               MoveTo(myDialog[Scores]^.portRect.right -
                                          StringWidth(tStr) - 7,87+16*i);
               DrawString(tStr);{draw all 4 scores}
               PenPat(gray);
               move(0,3);
               lineto(7,90+16*i);{draw the lines in between scores}
               PenPat(black);
            end;
            ModalDialog(Nil,itemHit);
            if itemHit = 4 then begin {reset the hiscore stuff}
                  For i := 1 to 4 do begin
                        theHighs^.level[i] := 0;
                        theHighs^.score[i] := 0;
                     end;
                  theHighs^.nameStr := '';
                  While Length(theHighs^.nameStr) < 102 do
                        theHighs^.nameStr := Concat(theHighs^.nameStr,'    ');
                  ChangedResource(ScoreHandle);{write changes on quit}
                  InvalRect(myDialog[Scores]^.portRect);{modalDialog will redraw items}
                  EraseRect(myDialog[Scores]^.portRect);
                  HiScore := 0;
                  DrawBoldButton(WhichDialog);{redraw after erase}
               end;{if itemhit}
         Until(itemhit = 1)
      end;{Score}
   Name:Begin {get hiscorer's name/sort into hiscore record}
         GetDItem(myDialog[Name],3,theType,tHandle,tRect);
         SetIText(tHandle,NameString);{put default in text box}
         SelIText(myDialog[Name],3,0,maxint);{select the text}

         Repeat
         ModalDialog(Nil,itemHit);{Modal handles Update events for dialog}
         Until(itemHit = 1);{ok button}

         GetIText(tHandle,NameString);{must be happy with text..so use it}

         For i := 1 to 4 do {copy packed strings into temp full strings}
                  unNames[i] := copy(theHighs^.nameStr,((i-1) * 23)+1,23);
         {sort the New LoScore}
         index := 4;{we know that score is more than 4 already}
         For i := 3 Downto 1 do
               If Score > theHighs^.score[i] then index := i;{how how is it,#1?}

         i := 4;
         While (i > index) do begin {switch old for new scores}
               unNames[i] := unNames[i-1];
               theHighs^.score[i] := theHighs^.score[i-1];
               theHighs^.level[i] := theHighs^.level[i-1];
               dec(i);
            end;{While}
         theHighs^.score[index] := Score;{make 'index' score = new high}
         theHighs^.level[index] := Level;
         unNames[index] := copy(NameString,1,23);{just first 23 chars of name}

         theHighs^.namestr := '';
         For i := 1 to 4 do begin {repack the strings into namestr}
               theHighs^.nameStr := concat(theHighs^.nameStr,unNames[i]);
               While Length(theHighs^.nameStr)< (i*23) do
                     theHighs^.nameStr := concat(theHighs^.nameStr,' ');
            end;{for i}

         ChangedResource(ScoreHandle);{flag, write out changes on Quit}
      end;{Name:}
   SetSpeed:Begin
         Repeat
            ModalDialog(Nil,itemHit);
            Case itemHit of
            2,3,4: SetControlValue(itemHit);{our radio controls}
            end;{case itemhit}
         Until(itemHit = 1);
      end;{SetSpeed}
   end;{Case WhichDialog}

   HideWindow(myDialog[WhichDialog]);
   SelectWindow(myWindow);{restore our game window}
   SetPort(tPort);{restore port}
end;

procedure GetIndRect(Var theRect:Rect;rectListID:integer;index:integer);
{similar to GetIndString RomCall for use with 'nrct' resource type}
Begin
   {make sure we've got a copy of resource in memory}
   RListHand := nrctHandle(GetResource('nrct',rectListID));
   If (index > RListHand^^.num) or (RListHand = Nil) {watch out for errors}
         then SetRect(theRect,0,0,0,0)
   else
         theRect := RListHand^^.theRects[index];{copy the rect...}
End;

procedure CreateStrings;{messages and hints}
Begin
   For i := 1 to 4 do begin
         GetIndString(Clues[i].message,1000,i);{4 messages}
         GetIndRect(Clues[i].messRect,1000,i);{box for textbox messages}
         GetIndRect(Clues[i].hintRect,1001,i);{box to contain hints}
      end;
   For i := 1 to 10 do GetIndString(ClueWords[i],1001,i);{10 cluewords}

   Clues[1].just := teJustRight;{justification for hint rect... next to glyph}
   Clues[2].just := teJustCenter;
   Clues[3].just := teJustLeft;
   Clues[4].just := teJustCenter;
end;

procedure NextTrgtSound(Trgt:integer);{we'll use our snake stuff to play sound}
Begin
   SnakeSound^.sound1Rate := StartPitch[1] * Trgt;{*2 is one octave}
   SnakeSound^.sound2Rate := StartPitch[2] * Trgt;
   SnakeSound^.sound3Rate := StartPitch[3] * Trgt;
   SnakeSound^.sound4Rate := StartPitch[4] * Trgt;
   SnakeSound^.duration := 120;{so tone will keep playing}
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

procedure SetSnakeSoundStuff;{for whichsound}
Begin
   Case WhichSound of {our 2 voice FourTone sounds}
   SnakeCharmer:Begin
         SnakeSound^.sound1Rate := mySongPtr^.pitch[NoteCount,1];
         SnakeSound^.sound2Rate := mySongPtr^.pitch[NoteCount,2];
         ToneDelay := mySongPtr^.duration[NoteCount] + TickCount;
      end;
   Walk:Begin
         SnakeSound^.sound1Rate := myWSongPtr^.pitch[NoteCount,1];
         SnakeSound^.sound2Rate := myWSongPtr^.pitch[NoteCount,2];
         ToneDelay := myWSongPtr^.duration[NoteCount] + TickCount;
      end;
   end;{case whichsound}
   SnakeSound^.duration := 80;{none of our notes is over 60 ticks long}

end;

procedure InitialSnakeSong(BeginNote:integer);{use for 'Walk' also, just use myWSongPtr stuff}
Begin
   NoteCount := BeginNote;{set to first note in our song array}
   SetSnakeSoundStuff;
   SnakeSound^.sound3Rate := 0;{no 3 and 4 voices sound}
   SnakeSound^.sound4Rate := 0;

   If SoundOn then WriteASoundBlock(ptr(Sound[SnakeCharmer]),
                              SizeOf(Sound[SnakeCharmer]^),TickCount);
End;{of Procedure}

procedure CreateSound;{i,j,k = global}
{we're writing direct to the sound driver with PBWrite...this procedure sets
up all the various buffers, Parm blocks, and such for the different
types of sounds used in this game.  You can determine if a sound is finished
by checking the ioresult field of the Parmblock, if it is less than 1
then the sound is done.  In the mainloop we check it and start another sound
if the last one is done. Sometimes the Driver has changed ioresult but is not
done with the ParmBlock so writing another sound can be messed up.. buzzing,
this can be avoided by waiting for Tickcount to increment once,or by doing
a PBKillIO.  We use the PBKill when we want to switch sounds before they
are complete... this avoids the problem of our program trying to write to
the Driver buffers at the same time the driver is trying to access them.
To avoid system errors always be sure to Kill sound I/O before exiting the
program!!.. and remember freeform sound slows the program by about 20%,
fourTone sound by 50%.}
Begin
   myHandle := (GetResource('SONG',522));{snake charmer notes}
   {HLock(myHandle);locked in resource file}
   mySongPtr := SongPtr(myHandle^);

   myHandle := (GetResource('SONG',523));{'Walk like' notes}
   {HLock(myHandle);locked in resource file}
   myWSongPtr := WSongPtr(myHandle^);

   new(SawToothWave);   {wavePtr...a SawToothWave form for Blue sound}
   new(SquareWave);  {wavePtr...a squarewave form for Blue sound}
   for i := 0 to 127 do {build our four tone waves}
      begin
         SawToothWave^[i] := 2*i;{sort of a raspy sound....}
         {SawToothWave^[i+128] := 0;}
         SquareWave^[i] := 0;
         SquareWave^[i+128] := 255;{height of Square determines Loudness}
      end;

   {we'll coerce Snake to FreeForm pointer throughout the program just so we
   can use WhichSound and our SoundList type later on....}
   new(SnakeSynth);  {my FTSynthPtr, FourTone Synthesizer}
   SnakeSynth^.mode := ftMode;

   new(SnakeSound);{our fourtone sound}
   SnakeSound^.sound1Phase := 0;
   SnakeSound^.sound2Phase := 128;
   SnakeSound^.sound3Phase := 128; {out of phase just for fun}
   SnakeSound^.sound4Phase := 0;
   SnakeSound^.sound1Wave := SawToothWave;
   SnakeSound^.sound2Wave := SquareWave;
   SnakeSound^.sound3Wave := SawToothWave;
   SnakeSound^.sound4Wave := SquareWave;

   {must make sndRec point to our Sound}
   SnakeSynth^.sndRec := SnakeSound;
   Sound[SnakeCharmer] := FFSynthPtr(SnakeSynth);{its just a pointer.. so coerce it}

   {note: We're using Snake FourTone stuff also for both Walk and Trgt sounds}

   Buff[GunShot] := 376;{size of all the freeform buffers,keep multiples of 370}
   Buff[GoodHit] := 1486;{!!! remember to set range below}
   Buff[BadHit] := 746;
   Buff[Miss] := 746;
   Buff[BonusSnd] := 746;

   {now create all the FreeForm sounds....}
   For WhichSound := GunShot to BonusSnd do begin {they all have these in common}
         Sound[WhichSound] := FFSynthPtr(NewPtr(Buff[WhichSound]));{sound block}
         Sound[WhichSound]^.mode := ffMode;
         {knock off 6 bytes for mode & count.. plus 1 for switch to Zero base}
         Buff[WhichSound] := Buff[WhichSound] - 7;{size of waveBytes}
      end;

   {GunShot Stuff, played when a shot is fired, mousedown}
   Sound[GunShot]^.count := FixRatio(1,6);{see the Sound Driver stuff}
   j := 0;
   While j<= Buff[GunShot] do Begin
      If j > 30 then i := abs(Random) div (j*3) {just fading noise}
      else begin
            If (j mod 5) = 0 then i := 255;{SquareWave with Period of 10}
            If (j mod 10) = 0 then i := 0;
         end;{else}
      Sound[GunShot]^.WaveBytes[j] := i; {fill up the buffer}
      inc(j);
   end; { of while}

   {GoodHit Stuff, sound played if valid target hit}
   {set .count field by target value}
   j := 0;
   While j<= Buff[GoodHit] do Begin
      If j > 370 then begin
            If (j mod 64) = 0 then i := 255 - (j div 12);
            If (j mod 128) = 0 then i := (j div 12);
         end
      else begin
            If (j mod 64) = 0 then
                  If (j mod 128) = 0 then i := 0 else i := 255;
         end;{else}
      Sound[GoodHit]^.WaveBytes[j] := i; {fill up the buffer}
      inc(j);
   end; { of while}

{BadHit Stuff, hit a target but not a valid one}
   Sound[BadHit]^.count := FixRatio(1,4);
   j := 0;
   While j<= Buff[BadHit] do Begin
      if i < 127 then inc(i) else i := 0;{sawtooth}
      Sound[BadHit]^.WaveBytes[j] := i; {fill up the buffer}
      inc(j);
   end; { of while}

   {Miss Stuff, missed everything! splat}
   Sound[Miss]^.count := FixRatio(1,2);{see the Sound Driver stuff}
   j := 0;
   i := 0;
   While j<= Buff[Miss] do Begin
      if i < 255 then inc(i) else i := 0;
      Sound[Miss]^.WaveBytes[j] := i;
      inc(j);
   end; { of while}

   {BonusSnd Stuff, sound played if bonus target underway}
   Sound[BonusSnd]^.count := FixRatio(1,4);
   j := 0;
   While j<= Buff[BonusSnd] do Begin
      If (j mod 37) = 0 then
                  If (j mod 74) = 0 then i := 0 else i := 63;
      Sound[BonusSnd]^.WaveBytes[j] := i; {fill up the buffer}
      inc(j);
   end; { of while}

   {create our Sound Parameter block for use with PBWrite}
   new(SoundParmBlk);{create record the Ptr will point to!}
   with SoundParmBlk^ do begin {see Apple tech note 19, PBWrite vs. StartSound}
      iocompletion := nil;
      iorefnum := -4;
      {we'll poke in the pointers and size stuff in WriteASoundBlock}
      ioresult := 0; {will Start sound ,MainEventLoop}
   end; {of with}
end;

procedure PauseThisGame(index:integer); {called if a keydown during game}
var
   i: integer;
Begin
   err := PBKillIO(SoundParmBlk,false);{kill sound}
   PauseStatus := index;{determines update drawing}

   {copy current screen to UpDateMap, so update events are redrawn correctly}
   CopyBits(myWindow^.portBits,UpDateMap,UpDateRect,
                                       UpDateMap.bounds,srcCopy,nil);

   ShowControl(ResumeButton);
   ShowControl(EndButton);
   SetCursorMenus(false);
End;

procedure NewHiScore;{check for new hiscore/update HiScore??}
Begin
   If Score > HiScore then begin
         HiScore := Score;
         DrawStatus(4,HiScore);
      end;
End;

procedure MoveHourGlass(Horz,Vert:integer);{move for timescore after each level}
Begin
   OffSetRect(Hour,Horz,Vert);
   OffSetRect(TopSand,Horz,Vert);
   OffSetRgn(TopSandRgn,Horz,Vert);
   OffSetRect(BotSand,Horz,Vert);
   OffSetRgn(BotSandRgn,Horz,Vert);

   TrickleTop.h := TrickleTop.h + Horz;
   TrickleBot.h := TrickleTop.h;
   TrickTopR.h := TrickleTop.h + 1;{right side line trickle}
   TrickBotR.h := TrickTopR.h;
   TrickleTop.v := BotSand.top;
   TrickleBot.v :=TrickleBot.v + Vert;
   TrickBotR.v := TrickleBot.v;
end;

procedure BuildValidNow;
{list of Valids which have targets remaining, we step thru NowValid to find
the next valid target to display in StartOne(), so we have a good mix of
all the remaining valid targets in the windows, for instance if we have 6 valid
targets numbered 1..6 but the user has completed numbers 2,5 and 6 (they
have no targets remaining) then after this procedure NowValid will contain
the following... 1,3,4,0,0,0 NowNdx is inc'd until NowValid = 0
then its reset to 1}
Var
   i:integer;
Begin
   For i := 1 to 6 do NowValid[i] := 0;{initialize all to zero}
   NowNdx := 1;
   For i := 1 to LastValid do
      If Valid[i].remain > 0 then begin {has targets remaining so Valid}
            NowValid[NowNdx] := i;
            inc(NowNdx);{inc to point to next now}
         end;
   NowNdx := 1;{reset to first in list}
End;

procedure BuildValidTargets;
{create list of targets for scorebox & initial them}
Var
   i,j:integer;
Begin
   randSeed := TickCount;{longint seed Random Function}
   {our font bitimage has shapes for chars 33 thru 129}
   Valid[1].which := trunc(abs(Random) / MaxInteger * 96) + 33;{pick one}
   For i := 2 to LastValid do begin
      Repeat
         Valid[i].which := trunc(abs(Random) / MaxInteger * 96) + 33;{33 to 129}
         tFlag := True;
         For j := 1 to i-1 do {check against ones already picked}
            If (Valid[i].which = Valid[j].which) then tFlag := False;
      Until(tFlag = True);
   end;{for i}
   If LastValid < 6 then begin {create #of each target to be hit}
         For i := 1 to LastValid do Valid[i].remain := LastValid+1-i;{4,3,2,1}
      end
   else  For i := 1 to LastValid do Valid[i].remain := Level+4-i;
   BuildValidNow;
End;

procedure CreatePictures; {get PICT's from resource file}
Begin
   {note: we've either created our pics in FullPaint or by doing 'openPicture'
   type stuff.  In the case of FullPaint we 'copy' the picture from a document
   where the pic is located in same position relative to upperleft of page
   as it will be relative to upperleft of window origin.. this way when we
   draw the picture in its picFrame it appears in proper place in window, to
   move a picture.. just set a rect = to picframe and OffsetRect it, then
   draw the picture into the rect instead of the picframe}

   LeftSide := GetPicture(138);
   RightSide := GetPicture(139);{of gallery walls}
   BackSide := GetPicture(140);

   ScoreFrame := GetPicture(142);
   ScoreFrameRect := ScoreFrame^^.picFrame;
   ScoreNum := GetPicture(141);
   ScoreNumRect := ScoreNum^^.picFrame;
   OffSetRect(ScoreFrameRect,8,3);
   OffSetRect(ScoreNumRect,ScoreFrameRect.left +2-ScoreNumRect.left,
            ScoreFrameRect.top + 4-ScoreNumRect.top);

   StatPic := GetPicture(145);{status display box}
   {locate all the stuff for drawing our scores, etc. into Status}
   StatList[1].centerPt := StatPic^^.picFrame.topleft;
   StatList[1].centerPt.h := StatList[1].centerPt.h + 44;
   StatList[1].centerPt.v := StatList[1].centerPt.v + 26;
   StatList[2].centerPt.h := StatList[1].centerPt.h + 84;
   StatList[2].centerPt.v := StatList[1].centerPt.v;
   StatList[3].centerPt.h := StatList[1].centerPt.h;
   StatList[3].centerPt.v := StatList[1].centerPt.v + 27;
   StatList[4].centerPt.h := StatList[2].centerPt.h;
   StatList[4].centerPt.v := StatList[3].centerPt.v;
   For i := 1 to 4 do SetRect(StatList[i].blankRect,
         StatList[i].centerPt.h - 38,StatList[i].centerPt.v - 13,
         StatList[i].centerPt.h + 38,StatList[i].centerPt.v);

   For i := 1 to 4 do Clues[i].glyphPic := GetPicture(160 + i);{load glyphs}
   ClueShadow := GetPicture(165);
   For i := 168 to 171 do Tut[i] := GetPicture(i);{load tut pics}

   TarWindPic := GetPicture(166);

   BotSandRgn := RgnHandle(GetResource('RGN ',356));{mask sand into glass}
   TopSandRgn := RgnHandle(GetResource('RGN ',357));
   {these rgns are a tracing of the outline of the top and bottom half of
   the Hourglass.  We wrote a little utility that can import a picture, trace
   its outline into a RgnHandle then save the new rgn into our 'RGN ' resource,
   the rgn resource can then be used to mask drawing done by CopyBits().. both
   our GunSite and the sand in the hourGlass are examples of this.  Some truly
   stunning effects can be created with Rgn masks and CopyBits()!}
end;

{bmap Type resources contain a Bitmap 'and' bitimage. we created our bmaps by
using PtrAndHand to stick our bitimage (already containing pictures
shapes,etc.) onto the end of its bitmap and store as bmap...
Getbmap() loads the resource, locks it down, and makes 'theMap' point to
the BitImage.  In some cases there is no bitimage (empty) so we create a
ptr in the conventional way}
procedure Getbmap(Var theMap:Bitmap;resID:integer);
var
   myBmap:BmapHand;
Begin
   myBMap := BmapHand(GetResource('bmap',resID));
   {HLock(Handle(myBMap));locked in resource file}
   theMap.rowBytes := myBMap^^.rowBytes;
   theMap.bounds := myBMap^^.bounds;
   theMap.baseAddr := Ptr(@myBMap^^.bitStart[1]);{point to bitimage}
End;

procedure CreateOffScreenBitMap;  {see CopyBits stuff,also tech.note 41}
Begin
   {offScreen contains Gun/explode/spot/hourglass/sand and chariot pics}
   Getbmap(OffScreen,128);{bmaps come with complete BitImages!}
   Getbmap(BonusMap,129);
   Getbmap(UpDateMap,131);
   {we saved no bitimage for UpDateMap, so create it}
   UpDateMap.baseAddr := QDPtr(NewPtr((UpdateMap.bounds.bottom-
         UpdateMap.bounds.top)*UpdateMap.rowBytes));

   For i := 1 to 3 do begin
      GetbMap(Wings[i],131+i);
      Wings[i].baseAddr := QDPtr(NewPtr((Wings[i].bounds.bottom-
                     Wings[i].bounds.top)*Wings[i].rowBytes));
   end;
End;

procedure CreateCairoStuff;
{we're only using bitimage and locate table of Cairo font, to access the
'parts' of the Font we did some pointer math and made copies of only
bitImage and locate table, then saved the new records in our 'MYCF' resource,
the bitImage contains shapes for chars 33 thru 129.. see CairoFont.pro file
for more information on how we accessed the Cairo Font.}
var
   trect,bRect:Rect;
   i:integer;
Begin
   {load font Character image and locate table}
   myHandle := GetResource('MYCF',128);
   {HLock(myHandle);locked in resource}
   myCFPtr := CFPtr(myHandle^);{lock it down, used as ptr block}

   FontMap.baseAddr := QDPtr(myCFPtr);{make FontMap point to bit image}
   FontMap.rowbytes := 210;{row width in bytes, must be even number}
   SetRect(FontMap.bounds,0,0,1656,24);{looked at with ResEdit};
End;

procedure InitialHourGlass;{position hourglass stuff for start of game}
Begin
   OffSetRect(OBSand,0,OffBotSand.top-OBSand.top);{at top, will move down}
   OffSetRect(OTSand,0,OffTopSand.bottom-OTSand.bottom);{at bottom, will move up}
   TrickleBot.v := BotSand.bottom-1;{trickle to top of pile}
End;

procedure SizeLocateSpots(offset:integer);
Begin
   For i := 5 to 6 do begin
         OffSpot[i].bottom := OffSpot[i].bottom - (5 + offset);
         SpotRect[i] := OffSpot[i];{size SpotRect}
      end;
   OffSetRect(OffSpot[5],0,OffSpotTarget.top+offset-OffSpot[5].top);
   OffSetRect(OffSpot[6],0,OffSpotTarget.bottom-offset-OffSpot[6].bottom);
End;

procedure InitialSpotTargets;
Var
   i:integer;
Begin
   {locate and size all the Spot target rectangles, we're doing some
   shifting/sizing of OffSpots to minimize the work of CopyBits()}
   For i := 5 to 6 do OffSpot[i] := OffSpotTarget;
   Case SpotSpeed[5] of
   2: SizeLocateSpots(2);
   4: SizeLocateSpots(0);
   End;{Case Spotspeed}

   OffSetRect(SpotRect[5],TarWindow[5].left+7-SpotRect[5].left,
            TarWindow[5].top-SpotRect[5].top);{top moving down}
   OffSetRect(SpotRect[6],TarWindow[6].left+7-SpotRect[6].left,
            TarWindow[6].bottom-SpotRect[6].bottom);{bottom moving up}
End;

procedure OneTimeGameStuff;
Begin
   {when we created the bmaps we saved the rects we'd already calculated
   in a 'nrct' resource so we wouldn't have to rewrite the code}
   GetIndRect(OffGun[0],2000,1);{Rects for shapes in OffScreen bmap}
   GunRect := OffGun[0];{size}
   GetIndRect(OffGun[1],2000,2);
   GetIndRect(OffExplode,2000,3);
   ExplodeRect := OffExplode;
   GetIndRect(OffSpotTarget,2000,4);
   GetIndRect(OffHour,2000,5);
   GetIndRect(OffBotSand,2000,6);
   GetIndRect(OffTopSand,2000,7);

   {find all individual bonus shapes in the map... 6 in a row, 2 rows}
   with BonusMap.bounds do SetRect(tRect,left,top,left+37,top+23);{size of one}
   For i := 1 to 6 do begin
      OffBonus[i,1] := tRect;{top row}
      OffSetRect(tRect,0,23);
      OffBonus[i,2] := tRect;{bottom row}
      OffSetRect(tRect,37,-23);
   end;
   BonusRect := OffBonus[1,1];{size BonusRect}

   GetIndPattern(myPattern,sysPatListID,25);{see i-473}
   GetIndPattern(myDiagPat,sysPatListID,26);{used to disable valid}

   For i := 1 to 3 do begin {size 3 scrolling windows}
      SetRect(TarWindow[i],125,39 + 36*i,125+251,66 + 36*i);{font - 1}
      OffPiece[i] := TarWindow[i];{establish Height of OffPiece}
      Piece[i] := TarWindow[i];{establish Height of Piece}
      OffSetRect(OffPiece[i],0,1-OffPiece[i].top);{ready for startone}
   end;

   SetRect(SiteRect,0,0,25,25);{circular site in synch with gun}

   For i := 0 to 1 do begin
         OffSite[i] := SiteRect;{two offSites for two offguns}
         OffSetRect(OffSite[i],OffGun[i].left+ 4 -OffSite[i].left,
                     OffGun[i].top+ 13-OffSite[i].top);
         SiteRgn[i] := NewRgn;{create the site regions for use with CopyBits}
         OpenRgn;
         FrameOval(OffSite[i]);{used to mask background drawn into Offsite}
         CloseRgn(SiteRgn[i]);
   end;

   SetRect(TarWindow[5],0,0,37,105);{top is even,bottom odd due to pattern}
   OffSetRect(TarWindow[5],TarWindow[1].left-TarWindow[5].right-10,
            TarWindow[1].top-TarWindow[5].top-5);{locate to left of others}
   TarWindow[6] := TarWindow[5];{6 is exactly like 5,except on right side}
   OffSetRect(TarWindow[6],TarWindow[1].right-TarWindow[5].left+10,0);{right}
   For i := 5 to 6 do begin
         TopSpot[i] := TarWindow[i].top + 4;{used in SpotStatus for speed}
         BotSpot[i] := TarWindow[i].bottom - 4;
      end;

   {locate and size #4/bottom window.. bonus targets}
   TarWindow[4].top := TarWindow[3].top + 38;
   TarWindow[4].bottom := TarWindow[3].bottom + 38;
   TarWindow[4].left := TarWindow[5].left +1;
   TarWindow[4].right := TarWindow[6].right -1;
   OffSetRect(BonusRect,TarWindow[4].left-BonusRect.right,
                           TarWindow[4].top-BonusRect.top);

   TarWindRgn := NewRgn;{region - frame of bonus target window}
   OpenRgn;
   FrameRect(TarWindow[4]);{will mask the bonuspics}
   CloseRgn(TarWindRgn);

   Hour := OffHour;{hourglass stuff}
   OffSetRect(Hour,280-Hour.left,3-Hour.top);{position in scorebox}
   TopSand := TopSandRgn^^.rgnBBox;{size of rgn or of sand pic????}
   OTSand := TopSand;
   OffSetRect(TopSand,Hour.left-TopSand.left,Hour.top+4-TopSand.top);
   OffSetRect(TopSand,(Hour.right-TopSand.right) div 2,0);{center it}
   OffSetRgn(TopSandRgn,TopSand.left -TopSandRgn^^.rgnBBox.left,
                     TopSand.top-TopSandRgn^^.rgnBBox.top);

   BotSand := BotSandRgn^^.rgnBBox;{size of rgn or of sand pic????}
   OBSand := BotSand;
   OffSetRect(BotSand,Hour.left -BotSand.left,Hour.bottom-4-BotSand.bottom);
   OffSetRect(BotSand,(Hour.right-BotSand.right) div 2,0);{center it}
   OffSetRgn(BotSandRgn,BotSand.left -BotSandRgn^^.rgnBBox.left,
                     BotSand.bottom-BotSandRgn^^.rgnBBox.bottom);

   OffSetRect(OBSand,OffBotSand.left-OBSand.left,
                  OffBotSand.bottom-OBSand.bottom);
   OffSetRect(OTSand,OffTopSand.left-OTSand.left,
            OffTopSand.top-OTSand.top);

   TrickleTop.h := Hour.left + ((Hour.right-Hour.left)div 2)-1;
   TrickleBot.h := TrickleTop.h;
   TrickTopR.h := TrickleTop.h + 1;{right side line trickle}
   TrickBotR.h := TrickTopR.h;
   TrickleTop.v := BotSand.top;

   {all the Score box stuff}
   tPt.h := ScoreFrameRect.left + 2 + 22;{center of first box}
   tPt.v := ScoreFrameRect.top + 16;{to top of draw area}
   j := ScoreFrameRect.bottom - 5;{to bottom of blank area}
   For i := 1 to 6 do begin
      Valid[i].centerPt := tPt;
      Valid[i].remainPt.h := tPt.h;
      Valid[i].remainPt.v := j;
      SetRect(Valid[i].blankRect,tPt.h-20,tPt.v +28,tPt.h+20,j);
      tPt.h := tPt.h + 44;
      end;{for i}
   Valid[6].points := 500;{scoring for our valid targets}
   Valid[5].points := 100;
   Valid[4].points := 50;
   Valid[3].points := 20;
   Valid[2].points := 10;
   Valid[1].points := 5;

   {set up all the Timebonus stuff.. TBone topleft := 179,85}
   SetRect(TBone.frame,179,85,328,154);
   SetRect(TBone.numBox,267,110,319,130);
   SetPt(TBone.hourMove,-93,88);
   SetRect(TBone.arrowSource,myCFPtr^.locate[104],FontMap.bounds.top,
                              myCFPtr^.locate[105],FontMap.bounds.bottom);
   TBone.arrowDest := TBone.arrowSource;
   OffsetRect(TBone.arrowDest,234-TBone.arrowDest.left,
                           108-TBone.arrowDest.top);

   StartPitch[1] := 29316;{Long integers for notes,played when targets}
   StartPitch[2] := 78264;{are displayed,doubling long integers is an octive}
   StartPitch[3] := 98607;
   StartPitch[4] := 117264;

   {locate gun and site}
   OffSetRect(GunRect,100-GunRect.left,
            300-GunRect.bottom);
   OffSetRect(SiteRect,GunRect.left+ 4-SiteRect.left,
            GunRect.top+ 13-SiteRect.top);{synch Site with gun}

   SetRect(MouseRect,LeftSide^^.picFrame.right,ScoreFrameRect.bottom,
            RightSide^^.picFrame.left - 32,GunRect.top - 32);
   GunLimit := MouseRect;{GunLimit is fixed... MouseRect will slide with mouse}
   SetRect(ShadowRect,LeftSide^^.picFrame.left,ScoreFrameRect.bottom+3,
            RightSide^^.picFrame.right,297);

   {shadow rect extends down to edge of front counter in booth}
   RedrawRect := ShadowRect;
   RedrawRect.bottom := GunRect.bottom;{redraw extends farther,to bottom of gun}

   SetRect(ClueErase,LeftSide^^.picFrame.right+1,64,
            RightSide^^.picFrame.left-1,219);{erase tarwindows for Clues}

   UpDateRect := ClueErase;{update area to redraw windows from CopyBits copy}
   {our UpDateMap.bounds is equal to UpDateRect}

   FetchChar := FontMap.bounds;{Used to speed up StartOne, top/bottom coords.}

   For i := 1 to 4 do  {get handle to text items in clue dialog}
   GetDItem(myDialog[ClueDial],5 + i,j,Clues[i].dialHand,tRect);

   RandSeed := TickCount;
   ClueNdx := (abs(Random) div 3277) + 1;{ndx to cluewords,1-10}
   tRgn := NewRgn;{used tRgn in the ScrollRect call}
   ShotFired := False;{flag a shot fired... mousedown}
   NameString := '';
   GameUnderWay := False;{game is not under way on start up}
   PauseStatus := 0;{no pause}
   HiScore := theHighs^.score[4];{lowest of the hiscores}
   Score := 0;
   Level := 0;
   MissCount := 0;{number of misses}
   CursorNdx := 1;{point to first of three cursors}
   LastValid := 6;{we'll draw 6 targets on start up}
   Level := 4;    {for BuildValidTargets to work}
   BuildValidTargets;{so that update will work correctly}
End;

procedure StaggerOne(Which:integer);
{fill wings with pattern and OffSet, so our targets aren't lined up vertically}
Begin
   OldBits := myWindow^.portBits;  {preserve old BitMap}
   SetPortBits(Wings[Which]);          { our new BitMap }

   FillRect(Wings[Which].bounds,myPattern);{fill with horz.lines}

   si := abs(Random div 1368) + 10;{10 to 33,random offset for start}
   If Direction[Which] > 0 then begin
      OffPiece[Which].right := Wings[Which].bounds.right - si;
      OffPiece[Which].left := OffPiece[Which].right - Speed[Which];
    end
   Else begin
      OffPiece[Which].left := si;
      OffPiece[Which].right := si + Speed[Which];
   end;

   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure StartOne(Which:integer); {which TarWindow[1..3]}
{get a char from either valid targets or not-valid targets and draw it into
a Wings Bitmap and initial stuff for scrolling it onto the screen via
OffPiece/Piece and CopyBits()}
Begin
   OldBits := myWindow^.portBits;  {preserve old BitMap}
   SetPortBits(Wings[Which]); { our new BitMap }

   FillRect(Wings[Which].bounds,myPattern);{erase previous with horiz.line patt}
   {FetchChar := FontMap.bounds;}{bounds rect of FontMap bitmap}

   {find which char to draw... one from Valid targets or not}
   If ((abs(Random) div 3277) > 5) and not(ValidDone) then begin {get a Valid.which}
      si := Valid[NowValid[NowNdx]].which;{NowValid points to Valid with remain}
      If NowNdx < 6 then begin
         inc(NowNdx);
         If NowValid[NowNdx] = 0 then NowNdx := 1;{reset to first}
         end{if NowNdx}
      else NowNdx := 1;{6 is last so reset to first}
   end {if ((abs...}
   Else {put up one that's not on our list}
      Repeat {find i not in our Valid list}
         si := trunc(abs(Random) / MaxInteger * 96) + 33;{si := 33 to 129}
         tFlag := True;
         For sj := 1 to LastValid do
            If (si = Valid[sj].which) then tFlag := False;{in our list}
      Until(tFlag = True);

   FetchChar.left := myCFPtr^.locate[si];{locate[i] is offset in Bitimage}
   FetchChar.right := myCFPtr^.locate[si+1];{FetchChar frames Char image in Fontmap}
   dRect := FetchChar;

   {dRect.top := 0;}{FetchChar.top is already 0}
   dRect.bottom := 29;

   {expand dRect make white border/frame around target}
   If Direction[Which] > 0 then begin {offset to rightside}
      {resize dRect to frame target and offset to proper side}
      dRect.left := 42 - (FetchChar.right - FetchChar.left);{grow by 8 pixels}
      dRect.right := 50;{Wings[Which].bounds.right}
      OffPiece[Which].right := Wings[Which].bounds.right;
      {'Speed' := width of OffPiece/Piece and vice versa}
      OffPiece[Which].left := OffPiece[Which].right - Speed[Which];
    end
   Else begin {offset to leftside}
      dRect.left := 0;
      dRect.right := 8 + FetchChar.right - FetchChar.left;
      OffPiece[Which].left := 0;
      OffPiece[Which].right := Speed[Which];{size based on speed}
   end;

   EraseRect(dRect);{to erase pattern...inside target area}
   FrameRect(dRect);{frame around target}

   {TarList stuff...install this new target in TarList for this window}
   TarList[Which,NxtTar[Which]].theChar := si;
   TarList[Which,NxtTar[Which]].head := PixOff[Which] - Speed[Which];
   TarList[Which,NxtTar[Which]].wide := dRect.right - dRect.left;

   If NxtTar[Which] < LastTarget then inc(NxtTar[Which])
   Else NxtTar[Which] := 1;{index of TarList}

   {now shrink relocated dRect back to size of FetchChar before copybits}
   dRect.top := dRect.top + 3;
   dRect.bottom := dRect.bottom - 2;
   dRect.left := dRect.left + 4;
   dRect.right := dRect.right - 4;
   CopyBits(FontMap,Wings[Which],FetchChar,dRect,srcCopy,nil);{char into target}

   SetPortBits(OldBits);      {restore old bitmap}
end;

procedure InitialBonus;{set up bonus for drawing..movement}
Begin
   BonusUnderWay := True;
   BonusRect.left := TarWindow[4].left - (BonusRect.right-BonusRect.left);
   BonusRect.right := TarWindow[4].left;{move BonusRect to left side window}
   BonusSpeed := 4;{max right, pixels per loop}
   BonusLoops := 20;{20 * 4 = 80 pixels....}
   WhichSound := BonusSnd;{will start the BonusSnd}
End;{of procedure}

Procedure InitialAnimation;
Var
   i,j:integer;
   myErase:Rect;
Begin
   BuildValidTargets;{pick out Cairo chars for targets,etc.}

   {draw the scorebox}
   EraseRect(ScoreFrameRect);{erase old}
   DrawPicture(ScoreFrame,ScoreFrameRect);
   DrawPicture(ScoreNum,ScoreNumRect);

   If SoundOn then begin
         NextTrgtSound(1);{initialize pitches for sound during drawing}
         WriteASoundBlock(ptr(Sound[SnakeCharmer]),
               SizeOf(Sound[SnakeCharmer]^),TickCount);{use snake for target}
      end;{if soundon}
   {draw the targets into the scoreBox, for each level}
   SpeedTicks := 1;{for our delay}
   sRect := FontMap.bounds;{bounds rect of FontMap bitmap,top/bottom constant}
   For i := 1 to LastValid do begin
      NextTrgtSound(i);{change pitch for each box}
      with Valid[i].centerPt do SetRect(myErase,h-21,v,h+21,v+24);{erase area}
      tRect.top := Valid[i].centerPt.v;
      tRect.bottom := tRect.top + 24;
      For j := 32 to Valid[i].which do begin
            SystemTask;
            If SpeedTrapOn then Delay(SpeedTicks,aTick);{slow down for MacII's}
            SizeRectsForBox(j,i);{sRect and tRect}
            EraseRect(myErase);{erase the previous}
            CopyBits(FontMap,myWindow^.portBits,sRect,tRect,srcCopy,nil);
      end;{for j := 32}
      DrawRemainIntoScoreBox(i);{# remaining, draw just below target}
   end;

   err := PBKillIO(SoundParmBlk,false);{kill sound}

   randSeed := TickCount;
   For i := 1 to 3 do begin {initilize for each of scrolling windows}
      For j := 1 to LastTarget do TarList[i,j].theChar := 0;{no targets}
      NxtTar[i] := 1;{point to first target}

      PixOff[i] := -32766;{will determine offsets to targets in list}
      If odd(Random) then Direction[i] := 1 else Direction[i] := -1;
      Vector[i] := Direction[i] * Speed[i];{used to speed up animateoneloop}
      {locate Piece}
      If Direction[i] > 0 then begin {moving right, Piece is on left side}
            Piece[i].left := TarWindow[i].left;
            Piece[i].right := Piece[i].left + Speed[i];
         end
      else begin
            Piece[i].right := TarWindow[i].right;{Piece is on right side}
            Piece[i].left := Piece[i].right - Speed[i];
         end;
   end;

   StartOne(1);{start a target in top window}
   StaggerOne(2);{stagger wings, so targets out of synch}
   StaggerOne(3);

   Counter := 1;{number of loops before sand in hourglass moves}

   InitialSpotTargets;
   ValidDone := False;
   MissCount := 0;
   DrawStatus(3,MissCount);
   BonusNdx := 0;{will be inc'd by first bonus to point to first}
   BonusShape := 1;{point to first shape}
   If SoundOn then begin {start the Walk song just before start of level}
         WhichSound := Walk;
         InitialSnakeSong(57);{start the walk song...just the last bit...}
         Repeat
            SystemTask;
            If (TickCount > ToneDelay) then begin {start another note}
                  inc(NoteCount);
                  SetSnakeSoundStuff;{get next sound,etc.}
               end; {if TickCount}
         Until(NoteCount = myWSongPtr^.noteCount);{our last walk note}
         err := PBKillIO(SoundParmBlk,false);
         WhichSound := Silence;
      end;{if soundOn}
   InitialHourGlass;{position and draw hourglass}
   TrickleLeft := True;
   CopyBits(OffScreen,myWindow^.portBits,OffHour,
                              Hour,srcCopy,nil);
   CopyBits(OffScreen,myWindow^.portBits,OTSand,
                              TopSand,srcCopy,TopSandRgn);
end;

procedure BeginTheGame;
Begin
   SetCursorMenus(True);{do all the cursor and menus stuff}
   DisableItem(myMenus[2],1);{disable 'begin' until end of game}
   ClipRect(RedrawRect);{so drawing will only affect RedrawREct}
   EraseRect(RedrawRect);{erase the shadow in booth}
   DrawWindowContents(myWindow);{redraw shaded area (gameunderWay)}
   ClipRect(myWindow^.portRect);{reset clipRgn to whole window}

   For i := 1 to 4 do begin {list of clues for this game}
         Clues[i].hint := ClueWords[ClueNdx];
         If ClueNdx < 10 then inc(ClueNdx) else ClueNdx := 1;
      end;

   Score := 0;
   DrawStatus(2,Score);
   DrawStatus(4,HiScore);
   Level := 1;
   DrawStatus(1,Level);
   LastValid := 4;{only 4 valid targets for now}
   For i := 1 to 3 do Speed[i] := 1;{start out at slowest speed, 1 pix/loop}
   SpotSpeed[5] := 2;{start at top moving down}
   SpotSpeed[6] := -2;{start at bottom moving up}
   TimeCount := 45;{# of loops for each move of hourglass}
   InitialAnimation;
   BonusUnderWay := False;
end;

procedure DetectAHit;{search targets for a hit}
Begin
   Hit := False;
   For dj := 1 to 6 do begin {check all 6 TarWindows}
      If PtInRect(TargetCenter,TarWindow[dj]) then {is hit in the Window Rect?}
         Case dj of
         1,2,3:{check the three scrolling windows}
            Case Direction[dj] of
            1: begin {scrolling right}
                  dk := TarWindow[dj].left + PixOff[dj];{locate head constant}
                  di := LastTarget;{search TarList in reverse}
                  Repeat
                  If TarList[dj,di].theChar <> 0 then
                     If TargetCenter.h < (dk - TarList[dj,di].head) then
                        if TargetCenter.h > (dk - TarList[dj,di].head -
                                                TarList[dj,di].wide) then begin
                           Hit := True;
                           HitWhich := di;{which target in List is hit}
                           HitWindow := dj;{which window}
                        end;
                  dec(di);
                  Until((di = 0) or (Hit = True));
               end;{case 1:}
            -1: begin {scrolling left}
                  dk := TarWindow[dj].right - PixOff[dj];{Locate head constant}
                  di := LastTarget;
                  Repeat
                     If TarList[dj,di].theChar <> 0 then
                        If TargetCenter.h > (dk + TarList[dj,di].head) then
                           if TargetCenter.h < (dk + TarList[dj,di].head +
                                                   TarList[dj,di].wide) then begin
                              Hit := True;
                              HitWhich := di;{which target in List is hit}
                              HitWindow := dj;{which window}
                           end;
                        dec(di);
                  Until((di = 0) or (Hit = True));
               end;{Case -1:}
            end;{Case Direction}
         4: If BonusUnderWay then begin   {this is bonus window}
               tRect := BonusRect;
               tRect.left := tRect.left + 4;
               tRect.right := tRect.right - 4;{shrink the rect border for hittest}
               If PtInRect(TargetCenter,tRect) then begin
                     Hit := True;
                     HitWindow := dj;
                     WhichSound := Silence;{kill bonus sound}
                  end;{if PtInRect}
            end;{ If BonusUnderWay }
         5,6: begin
               tRect := SpotRect[dj];
               tRect.top := tRect.top + abs(SpotSpeed[dj]);
               tRect.right := tRect.right - abs(SpotSpeed[dj]);{shrink the rect for hittest}
               If PtInRect(TargetCenter,tRect) then begin
                     Hit := True;
                     HitWindow := dj;
                  end;{if PtInRect}
            end; {these are spot windows}
         end;{Case dj}
   end;{for dj:= 1}
   If not(Hit) then begin {hit will be true if a hit was detected}

         If SoundOn then begin  {play miss sound}
               err := PBKillIO(SoundParmBlk,false);{kill current sound}
               WriteASoundBlock(ptr(Sound[Miss]),Buff[Miss],TickCount);
            end;{if soundOn}

         inc(MissCount);
         DrawStatus(3,MissCount);{draw in new missCount}
      end;{if not(Hit)}
End;

procedure EraseTargetInTarWindow(Window,Index:integer);
{remove a target from a window... watch out for targets on window borders}
Begin
   {erase the target in window}
   tRect.top := TarWindow[Window].top;
   tRect.bottom := TarWindow[Window].bottom;
   If Direction[Window] > 0 then begin{moving right}
         tRect.right := TarWindow[Window].left + PixOff[Window]
                                              - TarList[Window,Index].head;
         tRect.left := tRect.right - TarList[Window,Index].wide;
         {in case the target is not fully in the window yet}
         If tRect.left < TarWindow[Window].left then begin
               OldBits := myWindow^.portBits; {preserve old BitMap}
               SetPortBits(Wings[Window]); { our new BitMap }
               FillRect(Wings[Window].bounds,myPattern);
               SetPortBits(OldBits);      {restore old bitmap}

               tRect.left := TarWindow[Window].left;{limit to left}
            end{if tRect.left}
         else If tRect.right > TarWindow[Window].right then
                              tRect.right := TarWindow[Window].right;
      end
   Else begin
         tRect.left := TarWindow[Window].right -
                           (PixOff[Window] - TarList[Window,Index].head);
         tRect.right := tRect.left + TarList[Window,Index].wide;
         {in case the target is not fully in the window yet}
         If tRect.right > TarWindow[Window].right then begin
               OldBits := myWindow^.portBits; {preserve old BitMap}
               SetPortBits(Wings[Window]); { our new BitMap }
               FillRect(Wings[Window].bounds,myPattern);
               SetPortBits(OldBits);      {restore old bitmap}

               tRect.right := TarWindow[Window].right;{limit to left}
            end{if tRect.left}
         else If tRect.left < TarWindow[Window].left then
                           tRect.left := TarWindow[Window].left;
      end;

     FillRect(tRect,myPattern);{fill what is showing with myPattern}
End;

procedure HandleAHit;{Hit = True... process it}
Begin
   Case HitWindow of {one of our 6 windows}
   1,2,3:begin {scrolling windows}
      EraseTargetInTarWindow(HitWindow,HitWhich);{erase the hit target}
      HitAValidTarget := False;{initialize to false}
      {is the target hit on our Valid list?}
      dj := TarList[HitWindow,HitWhich].theChar;{this is target char we hit}
      For di := 1 to LastValid do begin {is it a valid target?}
         If (Valid[di].which = dj) and
                     (Valid[di].remain > 0) then begin {this is a valid target}

            If SoundOn then begin {start the hit sound}
               err := PBKillIO(SoundParmBlk,false);{kill current sound}
               Sound[GoodHit]^.count := FixRatio(di+3,2);{tone by value of target}
               WriteASoundBlock(ptr(Sound[GoodHit]),Buff[GoodHit],TickCount);
            end;{if soundOn}

            Score := Score + Valid[di].points;{update score}
            DrawStatus(2,Score);
            NewHiScore;
            HitAValidTarget := True;
            dec(Valid[di].remain);{one less of this target}
            DrawRemainIntoScoreBox(di);{draw into scorebox}

            If Valid[di].remain = 0 then begin {disable this valid target}
               If not(BonusUnderWay) then begin {start only if not already going}
                     InitialBonus;{start a bonus target}
                     BonusUnderWay := True;
                     If BonusNdx < 6 then inc(BonusNdx);
                  end
               else If BonusNdx < 6 then inc(BonusNdx);{get next bonus}
               Sound[BonusSnd]^.count := FixRatio(BonusNdx,10);

               BuildValidNow; {rebuild NowValid list}

               {draw disabled Validtarget in scorebox}
               tRect := Valid[di].blankrect;
               tRect.top := Valid[di].centerPt.v;
               PenPat(myDiagPat);
               PenMode(patOr);{black force black,white leave alone}
               PaintRect(tRect);{use penPat and mode to fill rect,i-177}
               PenNormal;{i-170}
               {erase other targets of this char already on the screen}
               For dk := 1 to 3 do  {three tarWindows}
                  For dm := 1 to LastTarget do {search thru list for each window}
                     If TarList[dk,dm].theChar = Valid[di].which then begin
                           TarList[dk,dm].theChar := 0;
                           EraseTargetInTarWindow(dk,dm);
                        end;{if TarList}

               {check to see if all Valids are disabled/complete}
               If NowValid[NowNdx] = 0 then ValidDone := True;
            end;{if Valid.remain}

         end;{if (Valid.which}
      end;{for di}
      If not(HitAValidTarget) then begin {target hit was not a Valid one}
         If SoundOn then begin
               err := PBKillIO(SoundParmBlk,false);{kill current sound}
               WriteASoundBlock(ptr(Sound[BadHit]),Buff[BadHit],TickCount);
            end;{if soundOn}
         inc(MissCount);
         DrawStatus(3,MissCount);
         end;
      TarList[HitWindow,HitWhich].theChar := 0;{reset TarList}
   end;{Case 1,2,3}

   4:begin {bonus window}
         If SoundOn then begin
               err := PBKillIO(SoundParmBlk,false);{kill current sound}
               Sound[GoodHit]^.count := FixRatio(8,2);
               WriteASoundBlock(ptr(Sound[GoodHit]),Buff[GoodHit],TickCount);
            end;{if soundOn}
         Score := Score + (Level * 100);
         DrawStatus(2,Score);
         NewHiScore;
         FillRect(TarWindow[4],myPattern);{erase the BonusRect}
         BonusUnderWay := False;
      end;{bonus window}
   5,6:begin {spot targets on sides}
         If MissCount > 0 then begin {if there are misses then reduce count}
               If SoundOn then begin
                     err := PBKillIO(SoundParmBlk,false);{kill current sound}
                     Sound[GoodHit]^.count := FixRatio(8,2);
                     WriteASoundBlock(ptr(Sound[GoodHit]),Buff[GoodHit],TickCount);
                  end;{if soundOn}
               dec(MissCount);
               DrawStatus(3,MissCount);
            end;{if Misscount}
      end;{spot windows on sides}
   end;{Case HitWindow}
End;{procedure}

procedure CheckSpotStatus;{move spot targets to next position}
Begin
   For si := 5 to 6 do begin {both targets}
      If SpotSpeed[si] < 0 then begin {moving up...}
            If SpotRect[si].top > TopSpot[si] then begin {move up by speed pixels}
                  SpotRect[si].top := SpotRect[si].top + SpotSpeed[si];
                  SpotRect[si].bottom := SpotRect[si].bottom + SpotSpeed[si];
               end
            else begin {upper limit,reverse direction}
               OffSpot[si].top := OffSpot[si].top + SpotSpeed[si]-1;{speed is minus}
               OffSpot[si].bottom := OffSpot[si].bottom + SpotSpeed[si]-1;
               SpotSpeed[si] := -SpotSpeed[si];{reverse direction}
               dec(SpotRect[si].top);
               dec(SpotRect[si].bottom);
            end;
         end {If SpotSpeed}
      Else begin  {moving down}
            If SpotRect[si].bottom < BotSpot[si] then begin
                  SpotRect[si].top := SpotRect[si].top + SpotSpeed[si];
                  SpotRect[si].bottom := SpotRect[si].bottom + SpotSpeed[si];
               end
            else begin {at lower limit, reverse direction}
               OffSpot[si].top := OffSpot[si].top + SpotSpeed[si]+1;{speed is plus}
               OffSpot[si].bottom := OffSpot[si].bottom + SpotSpeed[si]+1;
               SpotSpeed[si] := -SpotSpeed[si];{reverse direction}
               inc(SpotRect[si].top);
               inc(SpotRect[si].bottom);
            end;
         end;
      CopyBits(OffScreen,myWindow^.portBits,OffSpot[si],
                              SpotRect[si],srcCopy,nil); {draw the spot}
   end;{for si:=}
End;

procedure DrawSandStuff;{hourglass... GameOver will flag end of level}
Begin
   GameOver := False;
   {set up for drawing on sand trickle}
   If TrickleLeft then begin {draw left trickle in gray}
         PenPat(Gray);
         MoveTo(TrickleTop.h,TrickleTop.v);
         LineTo(TrickleBot.h,TrickleBot.v);{gray left trickle}
         PenPat(White);
         TrickleLeft := False;
      end
   else begin {erase left trickle}
         PenPat(White);
         MoveTo(TrickleTop.h,TrickleTop.v);{white left trickle}
         LineTo(TrickleBot.h,TrickleBot.v);
         PenPat(Gray);
         TrickleLeft := True;
      end;

   {draw right trickle either gray or white (erase) set above}
   MoveTo(TrickTopR.h,TrickleTop.v);{right side line,opposite of left}
   LineTo(TrickBotR.h,TrickleBot.v);
   PenPat(Black);{back to normal penPat}

   If Counter < TimeCount then inc(Counter) {move sand shapes yet?}
   else begin {animate the hour glass}
         dec(OTSand.top);
         dec(OTSand.bottom);{top sand lower means off Rect goes higher}
         inc(OBSand.top);
         inc(OBSand.bottom);{bottom sand higher}
         dec(TrickleBot.v);{shorten trickle}
         CopyBits(OffScreen,myWindow^.portBits,OTSand,
                              TopSand,srcCopy,TopSandRgn);{draw topsand}
         If OTSand.top = OffTopSand.top then begin
               GameOver := True;{flag end of game/hourglass empty!!}
               CopyBits(OffScreen,myWindow^.portBits,OffHour,
                              Hour,srcCopy,nil);{erase all the trickles}
            end;

         CopyBits(OffScreen,myWindow^.portBits,OBSand,
                              BotSand,srcCopy,BotSandRgn);{draw bottom sand}

         Counter := 1;{reset the counter}
   end; {if else}
End;

procedure DoCommonLevelStuff;
Begin
   inc(Level);{next level}
   DrawStatus(1,Level);
   {increase speeds etc.}
   Case Level of
   3: inc(Speed[3]);
   4: begin
         inc(Speed[2]);{increase scroll window speed}
         inc(Speed[3]);
         SpotSpeed[5] := 4;{increase spot speed}
         SpotSpeed[6] := -4;
      end;
   end;{of case level}

   SpotSpeed[5] := abs(SpotSpeed[5]);{a must for each level,positive speed}
   SpotSpeed[6] := -abs(SpotSpeed[6]);{negative speed}

   If LastValid < 6 then inc(LastValid);{increase Valid targets}
   err := PBKillIO(SoundParmBlk,false);{kill sound}
   InitialAnimation;
   FlushEvents(mDownMask,0);
End;

procedure EndThisGame;
var i:integer;
Begin
   {draw hourglass empty}
   OffSetRect(OBSand,0,OffBotSand.bottom-OBSand.bottom);
   OffSetRect(OTSand,0,OffTopSand.top-OTSand.top);

   If PauseStatus = 2 then InvalRect(myWindow^.portRect) {clue, redraw window}
   else begin
         InvalRect(RedrawRect);{force redraw of shade area+gun}
         InvalRect(Hour);{update will draw empty hourglass}
      end;
   PauseStatus := 0;{no pause}

   WhichSound := Silence;{not sound}
   SetCursorMenus(false);{show cursor and menus}
   EnableItem(myMenus[2],1);{enable begin}
   If Score > theHighs^.score[4] then begin {new hiscore}
         UpDateMyWindow;{update/draw window before dialog}
         FlushEvents(upDatemask,0);{we just updated}
         DisplayDialog(Name);{new hiScore dialog,name and sort}
      end;{if score}
End;

procedure AnimateOneLoop;
Begin
   GetMouse(myMouse);
   {limit movement to target area, note: by using a sliding MouseRect with a
   fixed GunLimit we can get the GunRect to respond immediately to a change of
   direction outside the GunLimit Rect.  MouseRect simply moves with the mouse
   when the mouse is outside the GunLimit Rect then we map the mouse to
   MouseRect and GunLimit to get relative move inside GunLimit if there is any}

   If not(PtInRect(myMouse,MouseRect)) then begin
         {a coordinate is outside mouseRect so slide mouseRect to myMouse}
         If myMouse.h < MouseRect.left then begin {slide MouseRect to left}
                  MouseRect.right := MouseRect.right -
                                 (MouseRect.left - myMouse.h);
                  MouseRect.left := myMouse.h;
            end
         else If myMouse.h > MouseRect.right then begin
                  MouseRect.left := MouseRect.left + myMouse.h - MouseRect.right;
                  MouseRect.right := myMouse.h;
            end;
         If myMouse.v < MouseRect.top then begin
                  MouseRect.bottom := MouseRect.bottom -
                                 (MouseRect.top - myMouse.v);
                  MouseRect.top := myMouse.v;
            end
         else If myMouse.v > MouseRect.bottom then begin
                  MouseRect.top := MouseRect.top + myMouse.v - MouseRect.bottom;
                  MouseRect.bottom := myMouse.v;
            end;
      end;{if not(ptinRect)}

   {myMouse is to Mouse as site is to GunLimit,myMouse becomes Site coordinates}
   MapPt(myMouse,MouseRect,GunLimit);

   If myMouse.h < GunRect.left-2 then begin {slide gun and site to left or right}
         GunRect.left := GunRect.left - 3;
         GunRect.right := GunRect.right - 3;{gun/site rect.top/bottom are constant}
         SiteRect.left := SiteRect.left - 3;
         SiteRect.right := SiteRect.right - 3;
      end
   Else If myMouse.h > GunRect.left+2 then  begin
         GunRect.left := GunRect.left + 3;
         GunRect.right := GunRect.right + 3;
         SiteRect.left := SiteRect.left + 3;
         SiteRect.right := SiteRect.right + 3;
      end;
   {horizontal site always points to area directly above the gun}
   {vertical siteRect moves with mouse,whatever user requests}
   SiteRect.top := myMouse.v;
   SiteRect.bottom :=   myMouse.v + 25;{25 is Site bottom - top}

   {we have two OffGuns in OffScreen, one is offset over gray by one pixel}
   WhichGun := GunRect.right mod 2;{proper shape to draw over gray background}

   CheckSpotStatus;{move and draw the spot targets}

   {do all the scrolling window stuff}
   For i := 1 to 3 do begin
      ScrollRect(TarWindow[i],Vector[i],0,tRgn);{scroll the 3 windows}
      If (OffPiece[i].left < 0) then StartOne(i) {scrolling right}
      else {scrolling left}
         If (OffPiece[i].right > Wings[i].bounds.right) then StartOne(i);

      CopyBits(Wings[i],myWindow^.portBits,OffPiece[i],Piece[i],srcCopy,nil);
      OffPiece[i].left := OffPiece[i].left - Vector[i];{move OffPiece}
      OffPiece[i].right := OffPiece[i].right - Vector[i];{Direction[i] * Speed[i]}
   end;{for i := 1 to 3}

   {delay either 2 or 3 ticks, in our tests Delay returned 0.4 ticks sooner
   than speedFactor requested}
   If SpeedTrapOn then Delay(SpeedFactor,aTick);

   If BonusUnderWay then begin {draw all the BonusRect target stuff}
      dec(BonusLoops);
      If BonusLoops = 0 then begin  {find new speed/loop count}
         If BonusSpeed < 0 then begin {moving left so double to right}
               BonusSpeed := abs(BonusSpeed);
               BonusLoops := PrevBonusLoops * 2;{multiply is faster than add}
            end
         else begin  {moving right.. pick a new at random..left or right}
               BonusSpeed := Random div 6554;{-4 to +4}
               BonusLoops := abs(Random div 1639) + 8;
               PrevBonusLoops := BonusLoops;{Prev.. needed later if moving left}
         end;
      end;{If BonusLoops}

      {is new Rect.left to right side of window yet?}
      If BonusRect.left + BonusSpeed > TarWindow[4].right then begin
            WhichSound := Silence;{will kill the bonussnd}
            BonusUnderWay := false;
         end
      else begin {draw the bonus shape}
            {change shapes..ie.each of two faces every 8 loops}
            Case BonusShape of
            1: If ((Counter Mod 8) = 0) then inc(BonusShape);
            2: If ((Counter Mod 8) = 0) then dec(BonusShape);
            end;{case BonusShape}

            {draw the BonusRect...}
            BonusRect.left := BonusRect.left + BonusSpeed;{move rect}
            BonusRect.right := BonusRect.right + BonusSpeed;{offset BonusRect rect}
            CopyBits(BonusMap,myWindow^.portBits,
                     OffBonus[BonusNdx,BonusShape],
                                    BonusRect,srcCopy,TarWindRgn);{draw it}
         end;
   end;{If BonusUnderWay}

   If ShotFired = True then begin {ShotFired is set by mouseDown event}
         {draw bullet trace and explode, use PatXOr mode so we can reverse it}
         PenMode(PatXOr);{invert}
         TargetCenter.h := GunRect.left+ 16;
         TargetCenter.v := myMouse.v + 14;
         MoveTo(TargetCenter.h,GunRect.top);
         LineTo(TargetCenter.h,TargetCenter.v);{line from gun to explode}

         {locate Explode shape}
         ExplodeRect.right := GunRect.left+(ExplodeRect.right-ExplodeRect.left);
         ExplodeRect.left := GunRect.left;
         ExplodeRect.bottom := myMouse.v+(ExplodeRect.bottom-ExplodeRect.top);
         ExplodeRect.top := myMouse.v;
         CopyBits(OffScreen,myWindow^.portBits,OffExplode,
                                             ExplodeRect,srcXor,nil);{draw it}

         {detect a hit here....sound and such....}
         DetectAHit;{we'll process the hit later, after erasing line/explode}

         {draw Site (from screen) to OffGun then OffGun to Screen, do it
         here so explode is shown in site!}
         CopyBits(myWindow^.portBits,OffScreen,SiteRect,
                  OffSite[WhichGun],srcCopy,SiteRgn[WhichGun]);
         CopyBits(OffScreen,myWindow^.portBits,OffGun[WhichGun],
                  GunRect,srcCopy,nil);

         aTick := TickCount;{delay abit...so we can see line/explode}
         inc(aTick);
         Repeat Until(TickCount > aTick);

         ShotFired := False;{reset gun,ready for next mousedown}

         {erase the bullet line & explode, just invert the inversion!}
         MoveTo(TargetCenter.h,GunRect.top);
         LineTo(TargetCenter.h,TargetCenter.v);{inverse is still in effect}
         CopyBits(OffScreen,myWindow^.portBits,OffExplode,
                                 ExplodeRect,SrcXor,nil);{inverse mode}
         PenMode(PatCopy);{set back to normal}

         {window is back to normal (no lines/explode) so do hit stuff}
         {would have a mess if we erased targets before erasing explode}
         If Hit = True then HandleAHit;

      end
   Else begin {no shot fired... just draw the site/gun}
         CopyBits(myWindow^.portBits,OffScreen,SiteRect,
                  OffSite[WhichGun],srcCopy,SiteRgn[WhichGun]);{site into OffGun}
         CopyBits(OffScreen,myWindow^.portBits,OffGun[WhichGun],
                                             GunRect,srcCopy,nil);{offGun into window}
      end;

   PixOff[1] := PixOff[1] + Speed[1];{distance (in pixels) targets have moved}
   PixOff[2] := PixOff[2] + Speed[2];
   PixOff[3] := PixOff[3] + Speed[3];

   If ValidDone then {all score targets finished, check for end of this level}
      If (MissCount = 0) and not(BonusUnderWay) then begin {do new levelstuff}
            FlushEvents(mDownMask,0);{flush the mouseDown events}
            DrawPicture(TarWindPic,TarWindPic^^.picFrame);{erase old targets}
            ClipRect(GunRect);{erase the gun area only}
            EraseRect(GunRect);{will erase in clipped area only}
            DrawPicture(BackSide,BackSide^^.picframe);{will draw over gun}
            ClipRect(myWindow^.portRect);{reset to whole window}

            {display the timebonus frame stuff and animate}
            EraseRect(Hour);{erase current hourglass}
            MoveHourGlass(TBone.hourMove.h,TBone.hourMove.v);{move hourglass to new}
            EraseRect(TBone.frame);
            tRect := TBone.frame;
            PenSize(2,2);
            FrameRect(tRect);
            PenSize(1,1);
            InsetRect(tRect,3,3);
            FrameRect(tRect);{erase and frame area for timebonus}
            DrawHourGlass;{draw hourglass in new location}
            Copybits(FontMap,myWindow^.portbits,TBone.arrowSource,
                        TBone.arrowDest,srcCopy,nil);{draw the arrow}
            FrameRect(TBone.numBox);{draw box to frame numbers}
            tRect := TBone.numBox;
            InsetRect(tRect,4,4);{for moveTo and erase}

            aTick := 0;{will use to accumulate/display time score}
            If SoundOn then begin
                  If odd(Level) then begin
                        whichSound := SnakeCharmer; {designate which of FourTone}
                        i := mySongPtr^.noteCount;
                     end
                  else begin
                        whichSound := Walk;
                        i := myWSongPtr^.noteCount;{walk noteCount for loop}
                     end;
                  InitialSnakeSong(1);{Start the Song}
               end;{if sound}

            {now animate hourglass and score until sand is gone (GameOver)}
            Repeat
               SystemTask;
               {check song note to see if we need to start another note}
               If (TickCount > ToneDelay) then begin {get another songnote}
                     {if last note then reset to beginning}
                     If NoteCount < i then inc(NoteCount) else NoteCount := 1;
                     SetSnakeSoundStuff;{get next sound,etc.}
                  end; {if TickCount}
               If SpeedTrapOn then Delay(Speedticks,BuffSize);{slow down 1 tick}
               DrawSandStuff; {will return GameOver true if done}
               {use aTick to accumulate the Time Score}
               aTick := aTick + (Level div 2) + 1;{timebonus score}
               NumToString(aTick,tStr);
               MoveTo(tRect.right-StringWidth(tStr)-1,tRect.bottom);
               EraseRect(tRect);
               DrawString(tStr);{draw the new score}
            Until(GameOver = True);{true when all the sand is gone}

            Score := Score + aTick;{update score}
            DrawStatus(2,Score);
            NewHiScore;
            MoveHourGlass(-TBone.hourMove.h,-TBone.hourMove.v);{back to original}
            DrawHourGlass;
            whichSound := Silence;
            err := PBKillIO(SoundParmBlk,false);{kill sound}
            EraseRect(TBone.frame);{get rid of TimeBonus frame}

            If Level <> 4 then begin {handle various levels}
                  Case Level of
                  2:Begin
                        DrawAClue(1);{draw  a clue}
                        PauseThisGame(2);{2 indicates a clue pause}
                     end;
                  10:Begin {display the clue dialog, get user input}
                        ShowCursor;{for dialog input}
                        DisplayDialog(ClueDial);{will cause update for myWindow}
                        HideCursor;{continue with game}

                        If PauseStatus = 3 then begin {3 if tomb,0 if not}
                              ShowCursor;
                              DisplayDialog(Tomb);{display the tomb dialog}
                              HideCursor;
                              PauseStatus := 0;{enable normal redrawing}
                              Score := Score + 10000;{tomb bonus = 10000}
                              DrawStatus(2,Score);
                              NewHiScore;
                           end;

                        InvalRect(myWindow^.portRect);{whole window}
                        UpdateMyWindow;
                        FlushEvents(updateMask,0);

                        DrawPicture(TarWindPic,TarWindPic^^.picFrame);{continue}
                        DoCommonLevelStuff;
                     end;{case 5}
                  OtherWise begin
                        {draw the empty TarWindows and start another level}
                        DrawPicture(TarWindPic,TarWindPic^^.picFrame);
                        DoCommonLevelStuff;{do here for no clue, controls for clues}
                     end;{otherwise}
                  end;{case level}
               end{if level <> 4}
            Else begin {game is locked...let user know}
                  ShowCursor;
                  DisplayDialog(Unlock);{text about unlocking the game}
                  HideCursor;
                  EndThisGame;
               end;
            FlushEvents(mDownMask,0);
      end;{if (MissCount}

   {draw the hourglass stuff, end game if out of sand}
   If PauseStatus = 0 then begin    {if no pause, watch out for clue level pause}
         DrawSandStuff;    {SandStuff will return GameOver = true if sand empty}
         If GameOver then EndThisGame;
      end;{if pauseStatus}
End;


PROCEDURE InitThings;
Begin
   InitGraf(@thePort);     {create a grafport for the screen}

   MoreMasters;   {extra pointer blocks at the bottom of the heap}
   MoreMasters;   {this is 5 X 64 master pointers}
   MoreMasters;
   MoreMasters;
   MoreMasters;
   MoreMasters;

   {get the cursors we use and lock them down - no clutter}
   ClockCursor := GetCursor(watchCursor);
   {HLock(Handle(ClockCursor));locked in resource}

   For i := 1 to 3 do begin
         myCursor[i] := GetCursor(129 + i);
         {HLock(Handle(myCursor[i]));locked in resource}
      end;

   {show the watch while we wait for inits & setups to finish}
   SetCursor(ClockCursor^^);

   {init everything in case the app is the Startup App}
   InitFonts;                 {startup the fonts manager}
   InitWindows;               {startup the window manager}
   InitMenus;                 {startup the menu manager}
   TEInit;                    {startup the text edit manager}
   InitDialogs(Nil);       {startup the dialog manager}

   Finished := False;             {set program terminator to false}
   FlushEvents(everyEvent,0);     {clear events from previous program}
   { set up screen size stuff }
   Screen := ScreenBits.Bounds;  { Get screen dimensions from thePort }
   with Screen do SetRect(DragArea,Left+4,Top+24,Right-4,Bottom-4);

   ResRefNum := CurResFile;{i-116}
End;

procedure CreateWindow;{windows,dialogs}
var
   tRect: Rect;
Begin
   {get window. template will use our WDEF 128 resource. set PROCId field}
   myWindow := GetNewWindow(WindResId,@wRecord,Pointer(-1));
   SetRect(tRect,0,-10,600,400);{this will clip OffScreen bitMaps as well!!}

   ResumeButton := GetNewControl(pressResume,myWindow);
   EndButton := GetNewControl(pressEnd,myWindow);

   {remember: Dialog itemlists should be purgable, dialogs invisible}
   For DialNdx := Help to PrintDial do begin {read all the dialogs into array}
         myDialog[DialNdx] :=
               GetNewDialog(ord(DialNdx)+129,@myDialogRec[DialNdx],myWindow);
         SetPort(myDialog[DialNdx]);
         ClipRect(tRect);{set clip to smaller size..}
      end;

   Environs(i,j);{peek to see what hardware, i is rom, j is machine
                                       1 = 128k thru Plus,2 = Mac II,3 = SE}
   If j = 2 then SetControlValue(4) {must be a Mac II speedwise}
   else SetControlValue(2);{set NORMAL button in Speed dialog}

   ShowWindow(myWindow);{done so back to myWindow...}
   SetPort(myWindow);
   ClipRect(tRect); {i-166, set cliprgn to small rgn}
   TextFont(3);{Geneva font, installed in System resource file}
   TextSize(12);

   ScoreHandle := GetResource('HSCR',128);{we're keeping Scores in Resource}
   {HLock(ScoreHandle);lock it permanently in resource}
   theHighs := ScorePtr(ScoreHandle^);
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
      fileMenu:
         Case theItem of
         1:Begin
               HiliteMenu(0);
               BeginTheGame;{rem draws a new menu bar}
            end;
         2:Finished := True;  {quit this program}
         end;{of case}
      optionMenu:
         Case theItem of
         1:DisplayDialog(Guard);{protection dialog}
         2:DisplayDialog(Help);
         3:DisplayDialog(Scores);{hiscore stuff}
         4:Begin           {toggle sound on or off}
               If SoundOn then SoundOn := false else SoundOn := true;
               CheckItem(myMenus[3],theItem,SoundOn);{check if true,none if false}
            end;
         5:DisplayDialog(SetSpeed);{for hardware}
         end; { case theItem}
      worksMenu:
         Case theItem of
         1:DisplayDialog(BMap);{two of our Offscreen bitmaps}
         2:DisplayDialog(Source);{our source code offer}
         end;{case theItem}
   End;{case theMenu of}
   HiliteMenu(0);
End;

procedure TakeCareKeyDown(Event:EventRecord);
Var
   CharCode: char;
Begin
   CharCode := chr(LoWord(BitAnd(Event.message,CharCodeMask)));

   If BitAnd(Event.modifiers,CmdKey) = CmdKey then
            DoMenuCommand(MenuKey(CharCode))
   Else If GameUnderWay then PauseThisGame(1);{pause with any other key press}
End;

procedure TakeCareControls(whichControl:ControlHandle;localMouse:point);
var
   ControlHit,i: integer;
Begin
   ControlHit := TrackControl(whichControl,localMouse,nil); { Find out which}
   If ControlHit > 0 then  {i-417}
      Begin
         If whichControl = ResumeButton then {RESUME the game..}
            Begin
               HideControl(ResumeButton);{watch out for update event}
               HideControl(EndButton);
               If (PauseStatus = 2) then InvalRect(myWindow^.portRect);{erase clue}

               BeginUpdate(myWindow);{clear Update stuff...buttons}
               EraseRect(myWindow^.portRect);
               Case PauseStatus of
               2:Begin {clue is being draw over}
                     PauseStatus := 0;{so Draw will redraw properly}
                     GameUnderWay := True;
                     DrawWindowContents(myWindow);
                     PauseStatus := 2;{so we can DoCommon... below}
                  end;
               OtherWise DrawWindowContents(myWindow) {just the hidden control area}
               end;{case PauseStatus}
               EndUpDate(myWindow);

               FlushEvents(updateMask,0);{clear Update caused by HideControl}
               If PauseStatus = 2 then DoCommonLevelStuff;{start next level}
               SetCursorMenus(True);
               PauseStatus := 0;
            End;
         If whichControl = EndButton then {END this current game...}
            Begin
               HideControl(ResumeButton);{hide the resume and end}
               HideControl(EndButton);
               EndThisGame;
            End;
   End; {of If ControlHit}
End; { of procedure}

procedure TakeCareMouseDown(myEvent:EventRecord);
var
   Location: integer;
   WhichWindow: WindowPtr;
   WhichControl: ControlHandle;
   MouseLoc: Point;
   WindowLoc: integer;
   ControlHit: integer;
   GlobalMouse:Point;
Begin
   If GameUnderWay = True then begin {handle a game click}
         ShotFired := True;{flag a shot, will be checked in AnimateOneLoop}
         If SoundOn then begin {write/start a Gunshot sound}
               {leave whichsound = to whatever it is}
               err := PBKillIO(SoundParmBlk,false);{kill current sound}
               WriteASoundBlock(ptr(Sound[GunShot]),Buff[GunShot],TickCount);
            end;{if soundOn}
      end
   Else begin     {Mouse is normal...handle normal functions}
      MouseLoc := myEvent.Where;  {Global coordinates}
      WindowLoc := FindWindow(MouseLoc,WhichWindow);  {I-287}
      case WindowLoc of
         inMenuBar:
            DoMenuCommand(MenuSelect(MouseLoc));
         inSysWindow:
            SystemClick(myEvent,WhichWindow);  {I-441}
         inDrag:
            DragWindow(WhichWindow,MouseLoc,DragArea);
         inContent:
            If WhichWindow <> FrontWindow then SelectWindow(WhichWindow)
            else Begin
                  GlobaltoLocal(MouseLoc);
                  {check to see if our Continue/End buttons were clicked}
                  ControlHit := FindControl(MouseLoc,whichWindow,whichControl);
                  If ControlHit > 0 then TakeCareControls(whichControl,Mouseloc)
                  {check to see if click on hourglass, begin the game}
                  Else  If (PtInRect(MouseLoc,Hour)) and (PauseStatus = 0)
                                       then BeginTheGame;{start the game}
               end;{else}
      end; {case of}
    end;{Else}
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
   EraseRect(UpDateWindow^.portRect);
   DrawWindowContents(UpDateWindow);{we only have one window!}
   EndUpDate(UpDateWindow);
   SetPort(TempPort);
End;

procedure TakeCareSoundStuff;{called from MainEvent}
{the current sound is complete if ioResult < 0.  Some of our sounds only play
thru once so we leave WhichSound = Silence so that the sound is not restarted.
BonusSnd is played over and over while a Bonus (bottom target) is displayed so
we set WhichSound = BonusSnd.. and each time it is finished this procedure
starts another BonusSnd.  In the case of our two 'songs' we are changing the
notes before the sound is complete (before ioResult < 1 or duration = 0).
We check the current TickCount against a variable ToneDelay which equals the
TickCount when the note started plus the ticks the note should play... so
if TickCount > ToneDelay we need to start another note.. we just change the
pitches and reset the Duration field and keep going!  Note: the sound i/o
decrements the duration field so it must be reset each time!}
Begin
   If SoundParmBlk^.ioResult < 1 then {sound is finished find another/play it}
         Case WhichSound of
         BonusSnd:{start another BonusSnd}
               WriteASoundBlock(ptr(Sound[BonusSnd]),Buff[BonusSnd],TickCount);
         end; {case whichsound}

   {we don't use Songs from MainEvent loop but if we did we'd need this Else.
   All our 'song's are played from closed loops in the AnimateOneLoop}
   (*  Else {sound is still underway if Snake or Walk check for next note}
         Case WhichSound of
         SnakeCharmer:begin {snakeCharmer song is underway check for new note}
            If (TickCount > ToneDelay) then begin {then get next note}
                  inc(NoteCount);
                  SetSnakeSoundStuff;
                  {check to see if this is the last note}
                  If mySongPtr^.noteCount = NoteCount then WhichSound := Silence;
               end;{if}
            end;{snake}
         Walk:begin {Walk song is underway check for new note}
            If (TickCount > ToneDelay) then begin {need new note}
                  inc(NoteCount);
                  SetSnakeSoundStuff;
                  If myWSongPtr^.noteCount = NoteCount then WhichSound := Silence;
               end;{if}
            end;{walk}
         end;{case & else}  *)
End;{of procedure}

procedure MainEventLoop;
var
   myEvent: EventRecord;
   i: integer;
Begin
   InitCursor;
   SetCursor(myCursor[1]^^);{one of 3 custom cursors}
   Repeat
      SystemTask;
      If GetNextEvent(EveryEvent,myEvent) then {handle the event}
            Case myEvent.What of
            mouseDown:     TakeCareMouseDown(myEvent);
            KeyDown:    TakeCareKeyDown(myEvent);
            ActivateEvt:   TakeCareActivates(myEvent);
            UpdateEvt:     TakeCareUpdates(myEvent);
            End {of Case}
      Else {no event pending so lets do some game stuff}
         If GameUnderWay then begin
               AnimateOneLoop;
               If SoundOn then TakeCareSoundStuff;
            end;{ if GameUnderWay}
   Until Finished;
End;

procedure SetUpMenus;
var
   i: integer;
Begin
   myMenus[1] := GetMenu(appleMenu);   {get menu info from resources}
   AddResMenu(myMenus[1],'DRVR');      {add in all the DA's}
   myMenus[2] := GetMenu(fileMenu);
   myMenus[3] := GetMenu(optionMenu);
   myMenus[4] := GetMenu(worksMenu);
   myMenus[5] := GetMenu(MessageMenu); {this is the backspace message}
   CheckItem(myMenus[3],4,True); {check the Sound item}
   SoundOn := True;  {sound will start on first begin}
   For i := 1 to 4 do InsertMenu(myMenus[i],0);
   DrawMenuBar;
End;

procedure CloseStuff;
Begin
   ShowCursor;
   err := PBKillIO(SoundParmBlk,false);{always kill sound before quitting}
   WriteResource(ScoreHandle);{write out if changes were flagged..HiScore}
End;

{Main Program begins here}
BEGIN
   InitThings;
   SetUpMenus;       {load the menus from resources}
   CreateWindow;        {load game window and dialogs from resources}
   CreateSound;         {load songs and create sound stuff}
   CreateCairoStuff; {load Cairo font bitimage and locate table}
   CreatePictures;      {load Pictures from resources}
   CreateOffScreenBitMap;  {load Bitmap from resources}
   CreateStrings;    {load strings from resources}
   OneTimeGameStuff; {locate all our rects, etc. in game window}
   MainEventLoop;    {let's play a game! get user input}
   CloseStuff;       {done so close}
END.
