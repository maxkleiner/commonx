unit UnitTest_Commands;
{$D+}


interface


uses managedthread, commandprocessor, windows, stringx,  classes, sysutils, commands_system, commandtypes, faststrings, stringx.fast, tickcount;

const
  STRING_SPLIT_TEST_SIZE = 6000;
type
  Tcmd_RandomStringSplit = class(TFunctionCommand<ansistring>)
  public
    divisor: nativeint;
    procedure DoExecute;override;
    procedure InitExpense;override;
  end;

  Tcmd_RandomFastStringSplit = class(TFunctionCommand<ansistring>)
  public
    procedure DoExecute;override;
    procedure InitExpense;override;
  end;

  Tcmd_RandomAllocations = class(TFunctionCommand<ansistring>)
  public
    testcount: int64;
    sizelimit: int64;
    ops: int64;
    TIME_LIMIT: int64;
    procedure DoExecute;override;
    procedure InitExpense;override;
  end;

  Tcmd_NthPrime = class(TFunctionCommand<integer>)
  private
    FNth: int64;
//    FResult: integer;
  public
    property Nth: int64 read FNth write FNth;
    procedure DoExecute;override;
    function IsPrime(i: int64): boolean;
//    property Result: integer read FResult write FResult;
  end;

  TCmd_IsPrimeMP = class(TfunctionCommand<integer>)
  private
    FSubject: integer;
  public
    property Subject: integer read FSubject write FSubject;
    procedure DoExecute;override;
  end;

  TCmd_IsFactorOf = class(TfunctionCommand<boolean>)
  private
    FSubject: int64;
  public
    property Subject: int64 read FSubject write FSubject;
    property Divisor: int64 read FSubject write Fsubject;
    procedure DoExecute;override;
  end;

  Tcmd_IsPrime = class(TFunctionCommand<boolean>)
  private
    FSubject: int64;
    FUseLessProperty: integer;
    procedure SetUseLessProperty(const Value: integer);
//    FResult: boolean;
  public
    property Subject: int64 read FSubject write FSubject;
    procedure DoExecute;override;
    property UseLessProperty: integer read FUseLessProperty write SetUseLessProperty;
//    property Result: boolean read FResult write FResult;
  end;

  Tthr_IsPrime = class(TMAnagedThread)
  private
    FSubject: int64;
    FResult: boolean;
  public
    property Result: boolean read FResult write FResult;
    property Subject: int64 read FSubject write FSubject;
    procedure DoExecute;override;
  end;

implementation

{ TPrimeCommand }

procedure Tcmd_NthPrime.DoExecute;
var
  t: int64;
  iSubject: int64;
  iPrimesFound: int64;

begin
  inherited;
  self.StepCount := Nth;

  iSubject := 999999999;
  iPrimesFound := 0;
  repeat
    inc(iSubject);
    if IsPrime(iSubject) then
      inc(iPrimesFound);




  until not (iPrimesFound < Nth);
  result := iSubject;

end;

{ Tcmd_IsPrime }

procedure Tcmd_IsPrime.DoExecute;
var
  t: int64;
  x: int64;
  s: int64;
begin
  inherited;

  t := 2;
  s := self.Subject;
  x := s div 2;

  while (t < x) do begin
    if (s mod t) = 0 then begin
      result := false;
      exit;
    end;
    inc(t);
  end;
    result := true;


end;

function Tcmd_NthPrime.IsPrime(i: int64): boolean;
var
  c: Tcmd_IsPrime;
begin
  c := Tcmd_isPrime.create();
  try
    c.Subject := i;
    self.ProcessLater;
    c.Start;
    c.WaitFor;
    result := c.result;

  finally
    c.free;
  end;

end;
(*var
  t: integer;
begin
  inherited;

  for t:= 2 to i div 2 do begin
    if (i mod t) = 0 then begin
      result := false;
      exit;
    end;
  end;

  result := true;


end;*)

{ TCmd_NthPrimeMP }

procedure TCmd_IsPrimeMP.DoExecute;
var
  c: Tcmd_IsFactorOf;
  t: integer;
begin
  inherited;
  //create all commands
  for t:= 1 to self.Subject div 2 do begin
    c := Tcmd_IsFactorOf.create();
    c.Subject := self.Subject;
    c.Divisor := t;
    c.Start;


  end;

end;

procedure Tcmd_IsPrime.SetUseLessProperty(const Value: integer);
begin
  FUseLessProperty := Value;
end;

{ TCmd_IsFactorOf }

procedure TCmd_IsFactorOf.DoExecute;
begin
  inherited;
  result := (self.Subject mod self.Divisor) = 0;
end;

{ Tcmd_RandomStringSplit }

procedure Tcmd_RandomStringSplit.DoExecute;
var
  s: string;
  t: integer;
  s1, s2, s3: string;
  sl: TStringlist;
begin

  inherited;
  sl := Tstringlist.create;

  var tests := 50000 div divisor;

  stepcount := tests;

  for var x := 1 to tests do begin
    sl.Clear;
    step := x;

    setlength(s, STRING_SPLIT_TEST_SIZE);
    for t:= low(s) to high(s) do begin
      s[t] := char(ansichar(ord('a')+random(72)));
    end;


    s3 := s;
//    stepcount := length(s);


    while splitString(s3, 'a', s1,s3) do begin
//      step := length(s)-length(s3);
      sl.Add(s1);

    end;
    result := sl.Text;

  end;
  sl.Free;

end;

procedure Tcmd_RandomStringSplit.InitExpense;
begin
  CPuExpense := 0;
end;

{ Tcmd_RandomAllocations }

procedure Tcmd_RandomAllocations.DoExecute;
var
//l:TList;
  a: array [0..255] of pointer;
  t: integer;
  p: pointer;
  r: integer;
  mm: TMemoryManager;
begin
  inherited;
//  l := Tlist.create;
  var sz := sizelimit;
  try
    FillMemory(@a[0], length(a)*sizeof(pointer),0);

    GetMemoryManager(mm);

    stepcount := TIME_LIMIT;
    var tmStart := GEtticker;
    var tmDif := gettimesince(tmStart);
    t := 0;
    repeat
      tmDif := gettimesince(tmStart);
      step := tmDif;
      r := t and 255;


      if a[r] = nil then begin
        a[r] := mm.GetMem(random(sz)+1);
      end else
      begin
        mm.FreeMem(a[r]);
        a[r] := nil;
      end;
      inc(ops);
      inc(t);
    until tmDif > TIME_LIMIT;


    for t := 0 to high(a) do begin
      if a[t] <> nil then
        mm.freemem(a[t]);
    end;


  finally
//    l.free;
  end;

end;

procedure Tcmd_RandomAllocations.InitExpense;
begin
  inherited;
  CPUExpense := 0;
end;

{ Tcmd_RandomFastStringSplit }

procedure Tcmd_RandomFastStringSplit.DoExecute;
var
  s: faststring;
  t: integer;
  s1, s2, s3: faststring;
  sl: TStringlist;
  sSplitter: faststring;
begin

  inherited;
  sl := Tstringlist.create;

  s.Length := STRING_SPLIT_TEST_SIZE;
  //setlength(s, 1000000);
  for t:= 1 to length(s) do begin
    s[t] := char(ansichar(ord('a')+random(26)));
  end;


  s3 := s;
  stepcount := length(s);

  sSplitter := 'a';
  while splitString(s3, sSplitter, s1,s3) do begin
    //step := length(s)-length(s3);
    //sl.Add(s1);

  end;
  result := sl.Text;
  sl.Free;

end;

procedure Tcmd_RandomFastStringSplit.InitExpense;
begin
  inherited;

end;

{ Tthr_IsPrime }

procedure Tthr_IsPrime.DoExecute;
var
  t: int64;
begin
  inherited;

  //sleep(random(3));
  t := 2;
  StepCount := (self.Subject div 2);
  while (t < (self.Subject div 2)) do begin
    if (t mod 10000) = 0 then begin
      Status := 'Checking if '+inttostr(subject)+' is prime.  Factor:'+inttostr(t);
      Step := t;

    end;
    if (self.Subject mod t) = 0 then begin
      result := false;
      exit;
    end;
    inc(t);
  end;

  result := true;
end;

end.
