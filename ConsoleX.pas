unit ConsoleX;

interface

uses
{$IFDEF MSWINDOWS}
  windows,
{$ENDIF}
  types, commandprocessor, stringx, typex, systemx, sysutils, betterobject, tickcount;

const
  CC_RED = 12;
  CC_YELLOW = 14;
  CC_WHITE = 15;
  CC_SILVER = 7;
  CC_GREY = 8;
  CC_BLUE = 9;
  CC_GREEN = 10;
  NLR = '`cF`'+CRLF;

type
  TConsole = class(TSharedObject)
  private
{$IFDEF MSWINDOWS}
    FHandle: THandle;
{$ENDIF}
    twiddleframe: ni;
    FForeGroundColorNumber: nativeint;
    FBAckGroundColorNumber: nativeint;
    procedure SetBackGroundColorNumber(const Value: nativeint);
    procedure SetForeGroundColorNumber(const Value: nativeint);
  protected
                public
    AutoCRLF: boolean;
    CloseApp: boolean;
{$IFDEF MSWINDOWS}
    property Handle: THandle read FHandle;
{$ENDIF}
    procedure Init;override;
    procedure SetTextAttribute(iAttr: nativeint);
    procedure Write(sString: string);
    procedure WriteLn(sString: string);
    procedure WhiteSpace(linecount: ni = 3);
    procedure Append(sString: string);
    property ForeGroundColorNumber: nativeint read FForeGroundColorNumber write SetForeGroundColorNumber;
    property BackGroundColorNumber: nativeint read FBAckGroundColorNumber write SetBackGroundColorNumber;
    procedure Twiddle;
    procedure WriteEx(sExpression: string; sEsc: char = '`');
    procedure WriteLnEx(sExpression: string; sEsc: char = '`');
    procedure WriteOk(bOk: boolean);
    procedure WatchCommand(c: TCommand);
    procedure WatchCommandProcessor(cp: TCommandProcessor);
    function WatchCommandInConsole(c: TCommand; maxtime: int64 = -1): boolean;
    function GetConsoleWindowSize: TPoint;
    procedure ClearScreen;
    procedure WriteTextBar(pct: single);
  public
    aonConsole: TProc<string>;

  end;


procedure ClearScreen;

function ConToHTML(sExpression: string): string;


function GetTextBar(pct: single): string;


implementation

function GetTextBar(pct: single): string;
const
  barcodes = '▂▃▄▅▆▇█▉▊▋▌▍▎▏▐■▓▒░';
begin


  var cnt := (trunc((pct*100)/10));
  result := '`cF``b0`'+StringRepeat('█',cnt);
  var hundo := pct*100;

  if cnt < 10 then begin
    var off10 := hundo-(trunc(hundo/10)*10);
    const colorwidth = 10;
    const charwidth = colorwidth/3;
    const COLOR_TYPES = 3;
    const ChAR_TYPES = 4;
    var offColor := off10-(trunc(off10/colorwidth)*colorwidth);
    var offChar := offColor-(trunc(offColor/charWidth)*charWidth);

    var part := trunc((offcolor/colorwidth)*COLOR_TYPES);
    var subpart := trunc((offChar/charwidth)*CHAR_TYPES);
//    subpart := 1;

    var csub := '';
    case subpart of
      0:csub := '░';
      1:csub := '▒';
      2:csub := '▓';
      3:csub := '█';
    else
      csub := 'x';
    end;

    case part of
      0:result := result + '`c8``b0`'+csub;
      1:result := result + '`c7``b8`'+csub;
      2:result := result + '`cF``b7`'+csub;
      3:result := result + '`cF`'+csub;
    else
      result := result + '!';
    end;
  end;



  result := result +'`c8``b0`'+StringRepeat('.',10-(cnt+1));
  result := '`cE``b0`['+result+'`cE``b0`]';

end;

function TConsole.WatchCommandInConsole(c: TCommand; maxtime: int64 = -1): boolean;
var
  s: string;
  iPrevWriteSize: ni;
  tmStart: ticker;
begin
  iPrevWriteSize := 0;
  tmStart := Getticker;
  while not c.WaitFor(1000 div 15) do begin
    if assigned(c.Thread) then begin
      c.Lock;
      try
        s := '`c8`'+c.Thread.GetSignalDebug+' `cA`'+floatprecision(c.PercentComplete*100,0)+'% '+GetTextBar(c.PercentComplete)+'`cF`'+c.Status;
        var unesc := getunescapedlength(s);
        repeat
          if unesc >= GetConsoleWindowSize.x-1 then begin
            s := zcopy(s, 0, length(s)-1);
            unesc := getunescapedlength(s);
          end;
        until unesc < GetConsoleWindowSize.x-1;
        s := s +stringx.StringRepeat(' ', GetConsoleWindowSize.x-unesc-1);

        WriteEx('`r`'+s+'`r`');
        iPrevWriteSize := length(s);
      finally
        c.unlock;
      end;
      if (maxtime >=0)
      and (gettimesince(tmStart) > maxtime) then
        exit(false);


    end;

  end;
  Write(stringx.StringRepeat(' ', iPrevWriteSize)+#13);
  s := floatprecision(c.PercentComplete*100,0)+'% '+ zcopy(c.Status,0,GetConsoleWindowSize.x-1)+CR;
  Write(s);


  exit(true);
end;

procedure TConsole.WatchCommandProcessor(cp: TCommandProcessor);
begin
  while cp.CommandCount > 0 do begin
    cp.Lock;
    try
      Write(cp.DebugString+#13);
    finally
      cp.Unlock;
    end;
    sleep(1000);
  end;
end;

procedure TConsole.Append(sString: string);
begin
{$IFDEF CONSOLE}
  system.Write(sString);
{$ENDIF}
end;

procedure TConsole.ClearScreen;
{$IFDEF MSWINDOWS}
var
  bufinfo: _CONSOLE_SCREEN_BUFFER_INFO;
  origin: Tcoord;
  numwritten: DWORD;
begin
  var h :=     CreateFile('CONOUT$', GENERIC_READ or GENERIC_WRITE,
               FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
               OPEN_EXISTING, 0, 0);
  try
    GetConsoleScreenBufferInfo(h, bufinfo);
    var sz := bufinfo.dwSize.x*bufinfo.dwsize.y;
    Win32Check(FillConsoleOutputCharacter(h, ' ', sz, Origin,
      NumWritten));
    Win32Check(FillConsoleOutputAttribute(h, bufinfo.wAttributes, sz, Origin,
      NumWritten));


    Origin.X := 0;
    Origin.Y := 0;
    Win32Check(SetConsoleCursorPosition(h, Origin));


  finally
    CloseHandle(h);
  end;

end;
{$ELSE}
begin
//  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;
{$ENDIF}

function TConsole.GetConsoleWindowSize: TPoint;
{$IFDEF MSWINDOWS}
var
  bufinfo: _CONSOLE_SCREEN_BUFFER_INFO;
begin
  var h :=     CreateFile('CONOUT$', GENERIC_READ or GENERIC_WRITE,
               FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
               OPEN_EXISTING, 0, 0);
  try
    GetConsoleScreenBufferInfo(h, bufinfo);
    result.x:=  bufinfo.dwSize.X;
    result.y:=  bufinfo.dwSize.y;
  finally
    CloseHandle(h);
  end;

end;
{$ELSE}
begin
//  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;
{$ENDIF}

procedure TConsole.Init;
begin
  inherited;
{$IFDEF MSWINDOWS}
  Fhandle := GetStdHandle(STD_OUTPUT_HANDLE);
{$ENDIF}
  AutoCRLF := true;
end;

procedure TConsole.SetBackGroundColorNumber(const Value: nativeint);
begin
{$IFDEF CONSOLE}
  FBAckGroundColorNumber := Value;
{$IFDEF MSWINDOWS}
  SetConsoleTextAttribute(handle, ((FBAckGroundColorNumber and $f) shl 4) or (FForeGroundColorNumber and $f));
{$ENDIF}
{$ENDIF}
end;


procedure TConsole.SetForeGroundColorNumber(const Value: nativeint);
begin
{$IFDEF CONSOLE}
  FForeGroundColorNumber := Value;
{$IFDEF MSWINDOWS}
  SetConsoleTextAttribute(handle, ((FBAckGroundColorNumber and $f) shl 4) or (FForeGroundColorNumber and $f));
{$ENDIF}
{$ENDIF}
end;

procedure TConsole.SetTextAttribute(iAttr: nativeint);
begin
{$IFDEF CONSOLE}
{$IFDEF MSWINDOWS}
  windows.SetConsoleTextAttribute(handle, iAttr);
{$ENDIF}
{$ENDIF}
end;

procedure TConsole.Twiddle;
begin
  twiddleframe := (twiddleframe+1) and 15;
  case twiddleframe of
    0: WriteEx('`cE`[`cF`■`c7`■`c8`■      `cE`]'+CR);
    1: WriteEx('`cE`[`c7`■`cF`■       `cE`]'+CR);
    2: WriteEx('`cE`[`c8`■`c7`■`cF`■      `cE`]'+CR);
    3: WriteEx('`cE`[ `c8`■`c7`■`cF`■     `cE`]'+CR);
    4: WriteEx('`cE`[  `c8`■`c7`■`cF`■    `cE`]'+CR);
    5: WriteEx('`cE`[   `c8`■`c7`■`cF`■   `cE`]'+CR);
    6: WriteEx('`cE`[    `c8`■`c7`■`cF`■  `cE`]'+CR);
    7: WriteEx('`cE`[     `c8`■`c7`■`cF`■ `cE`]'+CR);
    8: WriteEx('`cE`[      `c8`■`c7`■`cF`■`cE`]'+CR);
    9: WriteEx('`cE`[       `cF`■`c7`■`cE`]'+CR);
   10: WriteEx('`cE`[      `cF`■`c7`■`c8`■`cE`]'+CR);
   11: WriteEx('`cE`[     `cF`■`c7`■`c8`■ `cE`]'+CR);
   12: WriteEx('`cE`[    `cF`■`c7`■`c8`■  `cE`]'+CR);
   13: WriteEx('`cE`[   `cF`■`c7`■`c8`■   `cE`]'+CR);
   14: WriteEx('`cE`[  `cF`■`c7`■`c8`■    `cE`]'+CR);
   15: WriteEx('`cE`[ `cF`■`c7`■`c8`■     `cE`]'+CR);
  end;



end;

procedure TConsole.WatchCommand(c: TCommand);
begin
  WAtchCommandInConsole(c);
end;

procedure TConsole.WhiteSpace(linecount: ni);
begin
  for var t := 1 to linecount do
    WriteEx(NLR);
end;

procedure TConsole.Write(sString: string);
begin
{$IFDEF CONSOLE}
  if AutoCRLF then
    system.Writeln(sString)
  else
    system.Write(sString);

{$ENDIF}
end;

procedure TConsole.WriteEx(sExpression: string; sEsc: char = '`');
begin
  var lck : ILock := Self.LockI;
  if assigned(aonConsole) then
    aonConsole(sExpression);
  var slh := ParseStringH(sExpression, sESC);
  for var t := 0 to slh.o.count-1 do begin
    var sSection: string := slh.o[t];
    if (t and 1) = 0 then begin
      Append(slh.o[t]);
    end else begin
      if length(sSection) < 1 then
        Append(sEsc)
      else begin
        var cmd := lowercase(sSection[low(sSection)]);
        if cmd = 'c' then begin
          var clr := lowercase(sSection[high(sSection)]);
          if IsHex(clr) then begin
            var iclr := strtoint('$'+clr);
            SetForegroundColorNumber(iclr);
          end else begin
            Append('`'+clr+'`');
          end;
        end;
        if cmd = 'b' then begin
          var clr := lowercase(sSection[high(sSection)]);
          if IsHex(clr) then begin
            var iclr := strtoint('$'+clr);
            SetBackGroundColorNumber(iclr);
          end else begin
            Append('`'+clr+'`');
          end;
        end;
        if cmd = 'n' then begin
          Append(CRLF);
        end;
        if cmd = 'r' then begin
          Append(CR);
        end;

      end;
    end;
  end;
end;

procedure TConsole.WriteLn(sString: string);
begin
{$IFDEF CONSOLE}
  system.Writeln(sSTring);
{$ENDIF}
end;

procedure TConsole.WriteLnEx(sExpression: string; sEsc: char);
begin
  WriteEx(sExpression+'`n`');
end;

procedure TConsole.WriteOk(bOK: boolean);
begin
  if bOK then
    WriteEx('`cA`Ok!`cF`'+CRLF)
  else
    WriteEx('`cC`FAIL!`cF`'+CRLF);

end;



procedure TConsole.WriteTextBar(pct: single);
begin
  WriteEx(GetTextBar(Pct));
end;

procedure ClearScreen;
{$IFNDEF MSWINDOWS}
begin
//  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;
{$ELSE}
var
  stdout: THandle;
  csbi: TConsoleScreenBufferInfo;
  ConsoleSize: DWORD;
  NumWritten: DWORD;
  Origin: TCoord;
begin
  stdout := GetStdHandle(STD_OUTPUT_HANDLE);
  Win32Check(stdout<>INVALID_HANDLE_VALUE);
  Win32Check(GetConsoleScreenBufferInfo(stdout, csbi));
  ConsoleSize := csbi.dwSize.X * csbi.dwSize.Y;
  Origin.X := 0;
  Origin.Y := 0;
  Win32Check(FillConsoleOutputCharacter(stdout, ' ', ConsoleSize, Origin,
    NumWritten));
  Win32Check(FillConsoleOutputAttribute(stdout, csbi.wAttributes, ConsoleSize, Origin,
    NumWritten));
  Win32Check(SetConsoleCursorPosition(stdout, Origin));
end;
{$ENDIF}

function ConTohTML(sExpression: string): string;
var
  sline: string;
  bColored: boolean;
  fg: char;
  bg:char;
  sPendingColor: string;

  procedure CloseColor();
  begin
    if not bColored then exit;
    sLine := sline + '</span>';
    bColored := false;
  end;
  procedure OpenColor();
  begin
    sline := sLine + sPendingColor;
    sPendingColor := '';
    bColored := true;
  end;
  procedure CheckOpenColor();
  begin
    if sPendingColor <> '' then OpenColor;

  end;
  procedure ChangeColor();
  begin
    if bColored then CloseColor();
    sPendingColor := '<span class="fg'+fg+' bg'+bg+'">';
  end;
  procedure Append(ss: string);
  begin
    CheckOpenColor;
    sLine := sLine + ss;
  end;
  procedure SetBG(c: char);
  begin
    if c <> bg then begin
      bg := c;
      changecolor;
    end;
  end;
  procedure SetFG(c: char);
  begin
    if c <> fg then begin
      fg := c;
      changecolor;
    end;
  end;
begin
  sLine := '';
  bColored := false;
  fg := 'F';
  BG := '0';

  var slh := ParseStringH(sExpression, '`');
  for var t := 0 to slh.o.count-1 do begin
    var sSection: string := slh.o[t];
    if (t and 1) = 0 then begin
      Append(slh.o[t]);
    end else begin
      if length(sSection) < 1 then
        Append('`')
      else begin
        var cmd := lowercase(sSection[low(sSection)]);
        if cmd = 'c' then begin
          var clr := lowercase(sSection[high(sSection)]);
          if IsHex(clr) then begin
            SetFG((uppercase(clr))[STRZ]);
          end else begin
            Append('`'+clr+'`');
          end;
        end;
        if cmd = 'b' then begin
          var clr := lowercase(sSection[high(sSection)]);
          if IsHex(clr) then begin
            SetBG((uppercase(clr))[STRZ]);
          end else begin
            Append('`'+clr+'`');
          end;
        end;
        if cmd = 'n' then begin
          Append('<br/>');
        end;
        if cmd = 'r' then begin
          Append('<br/>');
        end;

      end;
    end;
  end;
  CloseColor();
  result := sline;

end;


end.

