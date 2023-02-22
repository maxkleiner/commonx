unit typex;
{$I DelphiDefs.inc}
interface

uses
{$IFDEF NEED_FAKE_ANSISTRING}
  ios.stringx.iosansi,
{$ENDIF}
  sysutils, variants, types, math;



const
  SIMPLE_BATCH_SIZE = 16384;
  CALENDAR_GRID_COUNT = 42;
  SUNDAY='Sunday';
  MONDAY='Monday';
  TUESDAY='Tuesday';
  WEDNESDAY='Wednesday';
  THURSDAY='Thursday';
  FRIDAY='Friday';
  SATURDAY='Saturday';
  day_list:array of string= [
                             'n/a',
                             'Sunday',
                             'Monday',
                             'Tuesday',
                             'Wednesday',
                             'Thursday',
                             'Friday',
                             'Saturday',
                             'Sunday',
                             'Monday',
                             'Tuesday',
                             'Wednesday',
                             'Thursday',
                             'Friday',
                             'Saturday'
                            ];
  month_list: array of string =
                            [
                              'n/a',
                              'January',
                              'February',
                              'March',
                              'April',
                              'May',
                              'June',
                              'July',
                              'August',
                              'September',
                              'October',
                              'November',
                              'December'
                            ];



  DT_MINUTES = 1/(24*60);
  DT_HOURS = 1/24;
  DT_DAYS = 1.0;
  DT_SECONDS = 1/(24*60*60);
  ESCIRC = #26;
  ESCIRC_CON = #05;
  ESCIRC_CMD = #04;
  IRCCR = #27;
  IRCCONT = #25;


  ESCX = #26;
  CLR0 = ESCX+'c0'+ESCX;
  CLR1 = ESCX+'c1'+ESCX;
  CLR2 = ESCX+'c2'+ESCX;
  CLR3 = ESCX+'c3'+ESCX;
  CLR4 = ESCX+'c4'+ESCX;
  CLR5 = ESCX+'c5'+ESCX;
  CLR6 = ESCX+'c6'+ESCX;
  CLR7 = ESCX+'c7'+ESCX;
  CLR8 = ESCX+'c8'+ESCX;
  CLR9 = ESCX+'c9'+ESCX;
  CLRA = ESCX+'cA'+ESCX;
  CLRB = ESCX+'cB'+ESCX;
  CLRC = ESCX+'cC'+ESCX;
  CLRD = ESCX+'cD'+ESCX;
  CLRE = ESCX+'cE'+ESCX;
  CLR_F = ESCX+'cF'+ESCX;
  CLR_UI = CLRE;
  CLR_QUERY = CLRA;
  CLR_QUERY_WRITE = CLRB;
  CLR_ERR = CLRC;
  ESC_BLUE = CLRE;
  CLRBLK = CLR_F;
  CLRWHITE = CLR_F;
  ANSICOLORS: array of cardinal = [
    $000000,//0
    $800000,//1
    $008000,//2
    $808000,//3
    $000080,//4
    $800080,//5
    $008080,//6
    $D0D0D0,//7
    $3F3F3F,//8
    $FF0000,//9
    $00FF00,//A
    $FFFF00,//B
    $0000FF,//C
    $FF00FF,//D
    $00FFFF,//E
    $FFFFFF];//F

   TERMINALCOLORS: array of CARDINAL = [
    $000000,//0
    $000080,//1
    $008000,//2
    $008080,//3
    $800000,//4
    $800080,//5
    $808000,//6
    $D0D0D0,//7
    $3F3F3F,//8
    $0000FF,//9
    $00FF00,//A
    $00FFFF,//B
    $FF0000,//C
    $FF00FF,//D
    $FFFF00,//E
    $FFFFFF];//F
{$IFDEF WINDOWS}
  NEWLINE = #13#10;
{$ELSE}
  NEWLINE = #10;
{$ENDIF}
  CR = #13;
  LF = #10;
  THOUSAND:int64 = 1000;
  MILLION:int64 = 1000000;
  BILLION:int64 = 1000000000;
  TRILLION:int64 =    1000000000000;
  QUADRILLION:int64 = 1000000000000000;
  PENTILLION:int64 = 1000000000000000000;
  BIT_THOUSAND:int64 = 1024;
  BIT_MILLION:int64 = 1024*1024;
  BIT_BILLION:int64 = 1024*1024*1024;
  BIT_TRILLION:int64 = 1099511627776;
  KILO:int64 = 1024;
  MEGA:int64 = 1024*1024;
  GIGA:int64 = 1024*1024*1024;
  TERA:int64 = 1099511627776;
{$IF sizeof(pointer)=8}
  POINTER_SHIFT = 3;
{$ELSE}
  POINTER_SHIFT_ = 2;
{$ENDIF}

type
  void = record
  end;
{$IFDEF CPUx64}
  TSize = uint64;
{$ELSE}
  TSize = cardinal;
{$ENDIF}
  ESocketsDisabled = class(Exception);
  TriBool = (tbNull, tbFalse, tbTrue);
  EClassException = class(Exception);
  EBetterException = class(Exception);
  ENotImplemented = class(Exception);
  EDeprecated = class(Exception);
  ECritical = class(Exception);
  ENetworkError = class(Exception);
  EUserError = class(Exception);
  EValidationError = class(Exception);
  EScriptVarError = class(Exception);
{$IFDEF IS_64BIT}
  nativeQfloat = double;
{$ELSE}
  nativefloat = single;
{$ENDIF}
  DWORD = cardinal;
  PDWORD = ^DWORD;
  BOOL = wordbool;
  ni = nativeint;
  nint = nativeint;
{$IFDEF FINT_IS_32}
  xxfi = integer;
  fint = integer;
{$ELSE}
  fi = nativeint;
  fint = nativeint;
{$ENDIF}


  TDynVariantArray = array of variant;
  TDynByteArray = TArray<byte>;
  TDynInt64Array = array of Int64;
  PInt16 = ^smallint;
  PInt32 = ^integer;
  tinyint = shortint;
  signedchar = shortint;
  signedbyte = shortint;

  TRegionI = record
    startpoint: int64;
    endpoint: int64;
    function Dif: int64;
    function Center: int64;
  end;

  TRegionS = record
    startpoint: single;
    endpoint: single;
    function Dif: single;
    function Center: single;
  end;
  TRunningAverage = record
    total: double;
    count: double;
    function Avg: double;

  end;

  TRegionD = record
    startpoint: double;
    endpoint: double;
    function Dif: double;
    function Center: double;
    class operator Add(a: TRegionD; b: double): TRegionD;
    class operator Subtract(a: TRegionD; b: double): TRegionD;
  end;

  TTightFlags = record
  strict private
    F: array of byte;
    FFlagCount: ni;
    procedure SetFlagCount(const v: ni);
    function GetFlag(idx: ni): boolean;
    procedure SetFlag(idx: ni; val: boolean);
  public
    property FlagCount: ni read FFlagCount write SetFlagCount;
    property Flags[idx: ni]: boolean read GetFlag write SetFlag;default;
    procedure Reset;

  end;






{$IFNDEF ONESTR}
const STRZERO = 0;
{$ELSE}
const STRZERO = 1;
{$ENDIF}



{$IFDEF GT_XE3}
type
  TForXoption = (fxRaiseExceptions,fxNoCPUExpense, fxEndInclusive, fxLimit1Thread, fxLimit2Threads,fxLimit4Threads,fxLimit8Threads,fxLimit16Threads,fxLimit32Threads,fxLimit64Threads,fxLimit256Threads,fxLimit1024Threads);
  TForXOptions = set of TForXOption;

  TVolatileProgression = record
    StepsCompleted: nativeint;
    TotalSteps: nativeint;
    Complete: boolean;
    procedure Reset;
  end;
  PVolatileProgression = ^TVolatileProgression;

  TStringHelperEx = record {$IFDEF SUPPORTS_RECORD_HELPERS}helper for string{$ENDIF}
    function ZeroBased: boolean;
    function FirstIndex: nativeint;
  end;
{$ELSE}
  {$Message Error 'we don''t support this compiler anymore'}
{$ENDIF}


{$IFDEF NEED_FAKE_ANSISTRING}
type
  ansistring = ios.stringx.iosansi.ansistring;
{$ENDIF}
  nf = nativefloat;

  ASingleArray = array[0..0] of system.Single;
  PSingleArray = ^ASingleArray;
  ADoubleArray = array[0..0] of system.Double;
  PDoubleArray = ^ADoubleArray;
  ASmallintArray = array[0..0] of smallint;
  PSmallintArray = ^ASmallintArray;

  ByteArray = array[0..0] of byte;
  PByteArray = ^ByteArray;


  complex = packed record
    re: double;
    im: double;
    property r: double read re write re;
    property i: double read im write im;
  end;
  complexSingle = packed record
    re: single;
    im: single;
  end;

  TNativeFloatRect = record
    x1,y1,x2,y2: nativefloat;
  end;

  PComplex = ^complex;




  TProgress = record
    step, stepcount: int64;
    function close: boolean;
    function PercentComplete: single;
{$IFDEF ALLOW_TPROGRESS_NEW}//triggered internal errors in JSONhelpers.pas
    class function New(step, stepcount:int64): TProgress;static;
{$ENDIF}
  end;
  TProgressAndStatus = record
    status: string;
    prog: TProgress;
  end;

  TProgressStatuses = Tarray<TProgressAndStatus>;



  TProgressF = record
    step, stepcount: double;
    function close: boolean;
    function PercentComplete: single;
  end;


  PProgress = ^TProgress;

  TProgMethod = procedure (prog: TProgress) of object;

  TPixelRect = record
    //this rect behaves more like you'd expect TRect to behave in the Pixel context
    //if you make a rect from (0,0)-(1,1) the width is 2 and height is 2
  private
    function GetRight: nativeint;
    procedure SetRight(const value: nativeint);
    function GetBottom: nativeint;
    procedure SetBottom(const value: nativeint);

  public
    Left, Top, Width, Height: nativeint;
    property Right: nativeint read GetRight write SetRight;
    property Bottom: nativeint read GetBottom write SetBottom;
    function ToRect: TRect;

  end;






  AComplexArray = array[0..0] of complex;
  PComplexArray = ^AComplexArray;
  AComplexSingleArray = array[0..0] of complexSingle;
  PComplexSingleArray = ^AComplexSingleArray;
  fftw_complex = complex;
  Pfftw_complex = PComplex;
  PAfftw_complex = PComplexArray;
  fftw_float = system.double;
  Pfftw_float = system.Pdouble;
  PAfftw_float = PDoubleArray;

  uint24 = packed record
    first16: cardinal;
    next8: byte;
    function toint64: int64;
    procedure fromint64(i: int64);
  end;

function PointToStr(pt:TPoint): string;
function STRZ(): nativeint;inline;
function BoolToTriBool(b: boolean): TriBool;inline;
function TriBoolToBool(tb: TriBool): boolean;inline;
function BoolToint(b: boolean): integer;
function InttoBool(i: integer): boolean;
function DynByteArrayToInt64Array(a: TDynByteArray): TDynInt64Array;
function DynInt64ArrayToByteArray(a: TDynInt64Array): TDynByteArray;
function StringToTypedVariant(s: string): variant;
function JavaScriptStringToTypedVariant(s: string): variant;
function VartoStrEx(v: variant): string;
function VarTypeDesc(v: variant): string;
function IsVarString(v: variant): boolean;
function StringArrayToInt64Array(a: TArray<string>): TArray<int64>;
function Int64ArrayToStringArray(a: TArray<int64>): TArray<string>;

function rect_notdumb(x1,y1,x2,y2: int64): TRect;
function PixelRect(x1,y1,x2,y2: int64): TPixelRect;
procedure Deprecate;
procedure NotImplemented;
function Null20(v: variant): variant;
function EscSeq(s: string): string;
function objaddr(o: TObject): string;
function DayToMs(d: double): int64;
function RoundRectF(rf: TRectF): TRect;

procedure NoFPUExceptions;


implementation

uses
  systemx, numbers;


procedure NoFPUExceptions;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                   exOverflow, exUnderflow, exPrecision]);

end;

function TTightFlags.GetFlag(idx: ni): boolean;
begin
  var i := idx shr 3;
  var b := idx and 7;
  result := 0<>(F[i] and (1 shl b));
end;


procedure TTightFlags.Reset;
begin
  for var t:= 0 to high(F) do
    F[t] := 0;

end;

procedure TTightFlags.SetFlag(idx: ni; val: boolean);
begin
  var i := idx shr 3;
  var b := idx and 7;
  if val then
    F[i] := F[i] or (1 shl b)
  else
    F[i] := F[i] and (not (1 shl b));

end;

procedure TTightFlags.SetFlagCount(const v: ni);
begin
  if flagcount = v then
    exit;
  setlength(F, 1+(v shr 3));
  Fflagcount := v;
end;

function objaddr(o: TObject): string;
begin
  result := '@'+inttohex(nativeint(pointer(o)),1);
end;

function EscSeq(s: string): string;
begin
  result := ESCX+s;
end;

function Null20(v: variant): variant;
begin
  if varisnull(v) then
    exit(0);

  if VarIsStr(v) then
    if v = '' then
      exit(0);

  exit(v);
end;


function STRZ(): nativeint;
//Returns the index of the first element of a string based on current configuration
begin
  result := strZERO;

end;

{ TStringHelperEx }

{$IFDEF GT_XE3}
function TStringHelperEx.FirstIndex: nativeint;
begin
  result := STRZ;
end;
{$ENDIF}

{$IFDEF GT_XE3}
function TStringHelperEx.ZeroBased: boolean;
begin
  result := STRZ=0;
end;
{$ENDIF}

function BoolToTriBool(b: boolean): TriBool;inline;
begin
  if b then
    result := tbTrue
  else
    result := tbFalse;
end;
function TriBoolToBool(tb: TriBool): boolean;inline;
begin
  result := tb = tbTrue;
end;

function BoolToint(b: boolean): integer;
begin
  if b then
    result := 1
  else
    result := 0;

end;

function InttoBool(i: integer): boolean;
begin
  result := i <> 0;
end;


function DynInt64ArrayToByteArray(a: TDynInt64Array): TDynByteArray;
begin
  SetLength(result, length(a) * 8);
  movemem32(@result[0], @a[0], length(result));
end;

function DynByteArrayToInt64Array(a: TDynByteArray): TDynInt64Array;
begin
  SEtLength(result, length(a) shr 3);
  movemem32(@result[0], @a[0], length(a));
end;

function JavaScriptStringToTypedVariant(s: string): variant;
begin
  result := StringToTypedVariant(s);
  if varType(s) = varString then
    result := StringReplace(result, '\\','\', [rfReplaceall]);
end;

function StringToTypedVariant(s: string): variant;
var
  c: char;
  bCanInt: boolean;
  bCanFloat: boolean;
begin
  s := lowercase(s);
  if s = '' then
    exit('');
  if s = 'null' then
    exit(null);
  if s = 'true' then
    exit(true);
  if s = 'false' then
    exit(false);

  bcanInt := true;
  bCanFloat := true;
  for c in s do begin
    if not charinset(c, ['-','0','1','2','3','4','5','6','7','8','9']) then
      bCanInt := false;
    if not charinset(c, ['-','.','E','0','1','2','3','4','5','6','7','8','9']) then
      bCanFloat := false;
    if not (bCanInt or bCanFloat) then
      break;
  end;

  if bCanInt then begin
    try
      if IsNumber(s) then
        exit(strtoint64(s))
      else
        exit(s);
    except
      exit(s);
    end;
  end;

  if bCanFloat then begin
    try
      exit(strtofloat(s));
    except
      exit(s);
    end;
  end;


  exit(s);





end;
function Int64ArrayToStringArray(a: TArray<int64>): TArray<string>;
begin
  setlength(result,length(a));
  for var t:= 0 to high(a) do begin
    result[t] := inttostr(a[t]);
  end;
end;

function StringArrayToInt64Array(a: TArray<string>): TArray<int64>;
begin
  setlength(result,length(a));
  for var t:= 0 to high(a) do begin
    result[t] := strtoint64(a[t]);
  end;
end;

function IsVarString(v: variant): boolean;
begin
  result := (vartype(v) = varString) or (vartype(v) = varUString) or (vartype(v) = varOleStr) or (varType(v) = 0 (*null string*));// or (varType(v) = v);
end;

function VartoStrEx(v: variant): string;
begin
  if vartype(v) = varNull then
    exit('');
  exit(vartostr(v));
end;

function TProgress.PercentComplete: single;
begin
  if StepCount = 0 then
    result := 0
  else
    result := Step/StepCount;
end;

{$IFDEF ALLOW_TPROGRESS_NEW}//triggered internal errors in JSONhelpers.pas
class function Tprogress.New(step, stepcount: int64): TProgress;
begin
  result.step := step;
  result.stepcount := stepcount;

end;
{$ENDIF}

function TProgressF.PercentComplete: single;
begin
  if StepCount = 0 then
    result := 0
  else
    result := Step/StepCount;
end;


function  TProgress.close: boolean;
begin
  result := step < 0;
end;

function  TProgressF.close: boolean;
begin
  result := step < 0;
end;



procedure TVolatileProgression.Reset;
begin
  StepsCompleted := 0;
  Complete := false;
end;

function PointToStr(pt:TPoint): string;
begin
  result := pt.x.tostring+','+pt.y.tostring;
end;

function rect_notdumb(x1,y1,x2,y2: int64): TRect;
begin
  result.Left := x1;
  result.top := y1;
  result.Right := x2+1;
  result.Bottom := y2+1;
end;

function TPixelRect.GetRight: nativeint;
begin
  result := (left+width)-1;
end;

procedure TPixelRect.SetRight(const value: nativeint);
begin
  width := (value-left)+1;
end;

function TPixelRect.GetBottom: nativeint;
begin
  result := (height+top)-1;
end;

procedure TPixelRect.SetBottom(const value: nativeint);
begin
  height := (value-top)+1;
end;

function TPixelRect.ToRect: TRect;
begin
  result.LEft := self.left;
  result.Top := self.top;
  result.width := self.width+1;
  result.Height := self.height+1;
end;




function PixelRect(x1,y1,x2,y2: int64): TPixelRect;
begin
  result.Left := x1;
  result.Top := y1;
  result.Width := (x2-x1)+1;
  result.Height := (y2-y1)+1;
end;


procedure Deprecate;
begin
  raise EDeprecated.create('deprecated');
end;

procedure NotImplemented;
begin
  raise EnotImplemented.create('not implemented');
end;


function DayToMs(d: double): int64;
begin
  result := round(d*(24*60*60*1000));
end;

function VarTypeDesc(v: variant): string;
begin
  var typ := VarType(v);

  case typ of
    $0000: exit('varEmpty');
    $0001: exit('varNull');
    $0002: exit('varSmallint');
    $0003: exit('varInteger');
    $0004: exit('varSingle');
    $0005: exit('varDouble');
    $0006: exit('varCurrency');
    $0007: exit('varDate');
    $0008: exit('varOleStr');
    $0009: exit('varDispatch');
    $000A: exit('varError');
    $000B: exit('varBoolean');
    $000C: exit('varVariant');
    $000D: exit('varUnknown');
    $000E: exit('varDecimal');
    $000F: exit('varUndef0F');
    $0010: exit('varShortInt');
    $0011: exit('varByte');
    $0012: exit('varWord');
    $0013: exit('varUInt32');
    $0014: exit('varInt64');
    $0015: exit('varUInt64');
    $0024: exit('varRecord');
    $0048: exit('varStrArg');
    $0049: exit('varObject');
    $004A: exit('varUStrArg');
    $0100: exit('varString');
    $0101: exit('varAny');
    $0102: exit('varUString');
  else
    exit('????');
  end;

end;

function uint24.toint64: int64;
begin
  result := self.first16 + (self.next8 shl 16);
end;

procedure uint24.fromint64(i: int64);
begin
  first16 := i and $FFFF;
  next8 := (i shr 16) and $FF;

end;


function TRegionI.Dif: int64;
begin
  result := endpoint-startpoint;

end;

function TRegionI.Center: int64;
begin
  result := (Dif div 2) +startpoint;
end;


function TRegionS.Dif: single;
begin
  result := endpoint-startpoint;

end;

function TRegionS.Center: single;
begin
  result := (Dif / 2) +startpoint;
end;

function TRegionD.Dif: double;
begin
  result := endpoint-startpoint;

end;

function TRegionD.Center: double;
begin
  result := (Dif / 2) +startpoint;
end;

class operator TRegionD.Add(a: TRegionD; b: double): TRegionD;
begin
  result.startpoint := a.startpoint + b;
  result.endpoint := a.endpoint + b;

end;


class operator TRegionD.Subtract(a: TRegionD; b: double): TRegionD;
begin
  result.startpoint := a.startpoint - b;
  result.endpoint := a.endpoint - b;

end;

function RoundRectF(rf: TRectF): TRect;
begin
  result.Left := round(rf.Left);
  result.Top := round(rf.Top);
  result.Width := round(rf.Width);
  result.Height := round(rf.height);
end;

function TrunningAverage.Avg: double;
begin
  result := 0;
  if Count > 0 then
    result := total/count;
end;

initialization
  NoFPUExceptions;


end.

