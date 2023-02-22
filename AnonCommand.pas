unit AnonCommand;

interface

{x$DEFINE ANON_SYNC_EXEC}

uses
  betterobject, debug, System.Classes, System.SysUtils, System.Generics.Collections, better_collections, typex, systemx, managedthread, commandprocessor, numbers, backgroundcommandprocessor;

type
  EAnonymousThreadException = class(Exception);

  Tcmd_Test = class(TCommand)
  public
    procedure DoExecute;override;
  end;





  TAnonymousCommand<T> = class(TCommand)
  private
    Err: Exception;
    FThreadFunc: TFunc<T>;
    FOnErrorProc: TProc<Exception>;
    FOnFinishedProc: TProc<T>;
    FResult: T;
    FStartSuspended: Boolean;
    FSynchronizeFinish: boolean;
    FSynchronizeExecute: boolean;
  strict private
    procedure SyncFinished;
    procedure SyncExecute;
    procedure SyncError;
  protected
    procedure DoExecute; override;
  public
    vResultEx: variant;
    parenthold: IUnknown;
    property OnErrorProc: TProc<Exception> read FonErrorProc;
    procedure InitExpense; override;
    procedure Detach; override;
    property SynchronizeFinish: boolean read FSynchronizeFinish write FSynchronizeFinish;
    property SynchronizeExecute: boolean read FSynchronizeExecute write FSynchronizeExecute;
    constructor CreateAndTrackX(tracker: TCommandList<TCommand>; AThreadFunc: TFunc<T>; AOnFinishedProc: TProc<T>;AOnErrorProc: TProc<Exception>; ACreateSuspended: Boolean = False);virtual;
    constructor Create(AThreadFunc: TFunc<T>; AOnFinishedProc: TProc<T>;AOnErrorProc: TProc<Exception>; ACreateSuspended: Boolean = False;
      FreeOnComplete: Boolean = True);reintroduce;
    destructor Destroy;override;
//    class constructor Create;
//    class destructor Destroy;
 end;
  TAnonymousGUICommand<T>  = class(TAnonymousCommand<T>)
  //THIS is an ANONYMOUs COMMAND that uses SYNCHRONIZE in OnFinish
  //by default.  You can choose to synchronize Execution and Finish of any anonymous
  //command.  This derivative simply has a different default for SynchronizeFinish
  public
    constructor Create(AThreadFunc: TFunc<T>; AOnFinishedProc: TProc<T>;AOnErrorProc: TProc<Exception>; ACreateSuspended: Boolean = False;
      FreeOnComplete: Boolean = True);reintroduce;
  end;

  TAnonymousIteratorCommand = class(TCommand)
  protected
    procedure DoExecute; override;
  public
    iteration: int64;
    batchcount: int64;
    proc: TProc<int64>;
  end;



  TAnonymousFunctionCommand = class(TAnonymousCommand<boolean>)
  public
    constructor CreateInline(AThreadFunc: TProc; ACreateSuspended: Boolean = False;
      FreeOnComplete: Boolean = false);reintroduce;
    constructor CreateInlineWithGui(AThreadFunc, GuiFunc: TProc; ACreateSuspended: Boolean = False; FreeOnComplete: Boolean = false);reintroduce;
    constructor CreateInlineWithGuiEx(AThreadFunc, GuiFunc: TProc; exProc: TProc<string>; ACreateSuspended: Boolean = False; FreeOnComplete: Boolean = false);reintroduce;
  end;

  TAnonTimerProc = reference to procedure();

  TAnonymousTimer = class(TAnonymousCommand<boolean>)
  public
    timerproc: TAnonTimerProc;
    procedure InitExpense;override;
  end;

  TPromise = record
  private
    cmd: IHolder<TAnonymousCommand<boolean>>;
  public
    parent: ^TPromise;
    function thenDo(p: TProc): TPromise;
    function thenGUI(p: TProc): TPromise;
    function Go: TPromise;
    function WaitFor(iupTo: int64 = -1): boolean;
  end;

function Promise(proc: TProc): TPromise;
function InlineProc(proc: TProc; bStart: boolean = true): TAnonymousCommand<boolean>;
function InlineIteratorProc(idx: ni; proc: TProc<int64>): TAnonymousIteratorCommand;
function InlineIteratorProcNS(idx: ni; proc: TProc<int64>): TAnonymousIteratorCommand;
function InlineIteratorGroupProc(idx: ni; batchcount: ni; proc: TProc<int64>): TAnonymousIteratorCommand;
function InlineProcWithGui(proc, guiproc: TProc): TAnonymousCommand<boolean>;
function InlineProcWithGuiEx(proc, guiproc: TProc; exProc:TProc<string>): TAnonymousCommand<boolean>;
function InlineProcWithGuiExUnstarted(proc, guiproc: TProc; exProc:TProc<string>): TAnonymousCommand<boolean>;
procedure ForXFake(iStart, iEnd_Ignored, iMinBatchSize,iMaxBatchSize: int64; doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);overload;
procedure ForXFake(iStart, iEnd_Ignored, iMinBatchSize: int64; doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);overload;
procedure ForX(iStart, iEnd_Ignored, iMinBatchSize: int64; doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);overload;
procedure ForX(iStart, iEnd_Ignored, iMinBatchSize,iMaxBatchSize: int64; doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);overload;
procedure ForX_NoWait(iStart, iEnd, iMinBatchSize: int64; doproc: TProc<int64>; cp: TCommandProcessor = nil);
//function InlineProc<T>(proc: TProc): TAnonymousCommand<T,boolean>;


function SetTimer(interval: ni; ontimerproc: TAnonTimerProc): TAnonymousTimer;
function SetTimerGUI(interval: ni; ontimerproc: TAnonTimerProc): TAnonymousTimer;



implementation

{$IFDEF MACOS}
uses
{$IFDEF IOS}
  iOSapi.Foundation
{$ELSE}
  MacApi.Foundation
{$ENDIF IOS}
  ;
{$ENDIF MACOS}
procedure ForXFake(iStart, iEnd_Ignored, iMinBatchSize,iMaxBatchSize: int64; doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);overload;
begin
  ForXFake(iStart, iEnd_Ignored, iMinBatchSize, doproc, opts, prog, cp);
end;

procedure ForXFake(iStart, iEnd_Ignored, iMinBatchSize: int64; doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);
var
  p: TProgress;
begin
  var realend := iEnd_Ignored-1;
  if TForXoption.fxEndInclusive in opts then
    realend := realend + 1;

  for var x := iStart to realend do begin
    if assigned(prog) then begin
      p.step := x;
      p.stepcount := realend;
      prog(p);
    end;
    doProc(x);
  end;

end;


procedure ForX(iStart, iEnd_Ignored, iMinBatchSize: int64;
    doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);
begin
//  if IsDebuggerAttached then opts := opts + [fxLimit4Threads];
  ForX(iStart,iEnd_Ignored,iMinBatchSize, 0, doproc, opts, prog,cp);
end;

procedure ForX(iStart, iEnd_Ignored, iMinBatchSize, iMaxBatchSize: int64;
    doproc: TProc<int64>;opts: TForXOptions = []; prog: TProc<TProgress> = nil; cp: TCommandProcessor = nil);
begin
  if fxEndInclusive in opts then begin
    if iEnd_Ignored < iStart then
      exit;
  end else begin
    if iEnd_Ignored <= iStart then
      exit;
  end;
//  if IsDebuggerAttached then opts := opts + [fxLimit4Threads];
  if iMaxBatchSize = 0 then
    iMaxBatchSize := SIMPLE_BATCH_SIZE;

  var cl := TCommandList<TAnonymousIteratorCommand>.create;
  try
    var cpus :=  GetEnabledCPUCount;


    var t := iStart;

    if (iEnd_Ignored >= iStart) then begin
      var totalsz := iEnd_Ignored-iStart;
      if fxNoCPUExpense in opts then
        cpus := greaterof(1,totalsz);
      if fxLimit1Thread in opts then
        cpus := 1;
      if fxLimit2Threads in opts then
        cpus := 2;
      if fxLimit4Threads in opts then
        cpus := 4;
      if fxLimit8Threads in opts then
        cpus := 8;
      if fxLimit16Threads in opts then
        cpus := 16;
      if fxLimit32Threads in opts then
        cpus := 32;
      if fxLimit64Threads in opts then
        cpus := 64;
      if fxLimit256Threads in opts then
        cpus := 256;
      if fxLimit1024Threads in opts then
        cpus := 1024;


      if fxEndInclusive in opts then
        inc(totalsz);
      var cx := totalsz;
      while cx > 0 do begin
        var thissz := lesserof(cx, greaterof(iMinBatchSize, (totalsz div cpus)));

        thissz := lesserof(iMaxBatchSize, thissz);
        var c := TAnonymousIteratorCommand.Create;
        c.iteration := t;
        c.batchcount := thissz;
        c.proc := doProc;
        cl.add(c);
        if fxNoCPUExpense in opts then
          c.CPUExpense := 0.0;
        if fxLimit1Thread in opts then
          c.memoryexpense := 1/2;
        if fxLimit2Threads in opts then
          c.memoryexpense := 1/2;
        if fxLimit4Threads in opts then
          c.memoryexpense := 1/4;
        if fxLimit8Threads in opts then
          c.memoryexpense := 1/8;
        if fxLimit16Threads in opts then
          c.memoryexpense := 1/16;
        if fxLimit32Threads in opts then
          c.memoryexpense := 1/32;
        if fxLimit64Threads in opts then
          c.memoryexpense := 1/64;
        if fxLimit256Threads in opts then
          c.memoryexpense := 1/256;
        if fxLimit1024Threads in opts then
          c.memoryexpense := 1/1024;

        c.RaiseExceptions := fxRaiseExceptions in opts;
        c.FireForget := false;
        if cp = nil then
          c.start(ForXCmd)
        else
          c.start(cp);

        dec(cx, thissz);
        inc(t, thissz);
      end;
    end else begin
      debug.Log('warning, not implemented when end < start');
      exit;
    end;

    cl.WaitForAll_DestroyWhileWaiting(prog);
    if assigned(prog) then begin
      var p: TProgress;
      p.step := -1;
      p.stepcount := 0;
      prog(p);
    end;


  finally
    cl.free;
  end;
end;

procedure ForX_NoWait(iStart, iEnd, iMinBatchSize: int64; doproc: TProc<int64>; cp: TCommandProcessor = nil);
begin
//  var cl := TCommandList<TAnonymousIteratorCommand>.create;
  try
    var cpus :=  GetEnabledCPUCount;
    var t := iStart;

    if (iEnd >= iStart) then begin
      var totalsz := iEnd-iStart;
      var cx := totalsz;
      while cx > 0 do begin
        var thissz := lesserof(cx, greaterof(iMinBatchSize, (totalsz div cpus)));
        var c := TAnonymousIteratorCommand.Create;
        c.iteration := t;
        c.batchcount := thissz;
        c.proc := doProc;
//        cl.add(c);
        c.FireForget := true;
        if cp = nil then
          c.start(ForXCmd)
        else
          c.start(cp);
        dec(cx, thissz);
        inc(t, thissz);
      end;
    end else begin
      raise ECritical.create('not implemented when end < start');
    end;

//    cl.WaitForAll_DestroyWhileWaiting;
  finally
//    cl.free;
  end;
end;
{ TAnonymousCommand }





//class constructor TAnonymousCommand<T>.Create;
//begin
//  inherited;
//end;

//class destructor TAnonymousCommand<T>.Destroy;
//begin
//  inherited;
//end;

procedure TAnonymousCommand<T>.Detach;
begin
//  Debug.log(self, 'Detaching');
  if detached then exit;
  inherited;

end;


function Promise(proc: TProc): TPromise;
begin
  result.cmd := THolder<TAnonymousCommand<boolean>>.create(TAnonymousFunctionCommand.createinline(proc,true,false));
  result.cmd.o.startondestroy := true;
  result.parent := nil;
end;

function InlineProc(proc: TProc; bStart: boolean = true): TAnonymousCommand<boolean>;
var
  res: TAnonymousCommand<boolean>;
begin
  res := TAnonymousFunctionCommand.createinline(proc, not bStart, false);
  res.SynchronizeFinish := false;
  result := res;
end;


function InlineIteratorProc(idx: ni; proc: TProc<int64>): TAnonymousIteratorCommand;
begin
  result := InlineIteratorProcNS(idx, proc);
  result.start;
end;
function InlineIteratorProcNS(idx: ni; proc: TProc<int64>): TAnonymousIteratorCommand;
begin
  result := TAnonymousIteratorCommand.create;
  result.iteration := idx;
  result.BATCHcount := 1;
  result.proc := proc;
//  result.CPUExpense := 1.0;

end;


function InlineIteratorGroupProc(idx: ni; batchcount: ni; proc: TProc<int64>): TAnonymousIteratorCommand;
begin
  result := TAnonymousIteratorCommand.create;
  result.iteration := idx;
  result.batchcount := batchcount;
  result.proc := proc;
//  result.CPUExpense := 1.0;
  result.start;
end;

function InlineProcWithGui(proc, guiproc: TProc): TAnonymousCommand<boolean>;
var
  res: TAnonymousCommand<boolean>;
begin
  res := TAnonymousFunctionCommand.createinlinewithgui(proc, guiproc, false, false);

  result := res;
  result.start;

end;

function InlineProcWithGuiEx(proc, guiproc: TProc; exProc:TProc<string>): TAnonymousCommand<boolean>;
var
  res: TAnonymousCommand<boolean>;
begin
  res := TAnonymousFunctionCommand.createinlinewithguiex(proc, guiproc, exProc, false, false);

  result := res;
  result.start;

end;

function InlineProcWithGuiExUnstarted(proc, guiproc: TProc; exProc:TProc<string>): TAnonymousCommand<boolean>;
var
  res: TAnonymousCommand<boolean>;
begin
  res := TAnonymousFunctionCommand.createinlinewithguiex(proc, guiproc, exProc, false, false);

  result := res;
//  result.start;

end;



constructor TAnonymousCommand<T>.Create(AThreadFunc: TFunc<T>; AOnFinishedProc: TProc<T>;
  AOnErrorProc: TProc<Exception>; ACreateSuspended: Boolean = False; FreeOnComplete: Boolean = True);
begin
//  Debug.Log('Creating '+self.GetObjectDebug);
  FOnFinishedProc := AOnFinishedProc;
  FOnErrorProc := AOnErrorProc;
  FThreadFunc := AThreadFunc;
  FireForget := FreeOnComplete;

  FStartSuspended := ACreateSuspended;
  FSynchronizeFinish := true;
{$IFDEF ANON_SYNC_EXEC}
  FSynchronizeExecute := true;
{$ENDIF}

  inherited Create();

  if not ACreateSuspended then
    Start;
end;


constructor TAnonymousCommand<T>.CreateAndTrackX(tracker: TCommandList<TCommand>;
  AThreadFunc: TFunc<T>; AOnFinishedProc: TProc<T>;
  AOnErrorProc: TProc<Exception>; ACreateSuspended: Boolean);
begin
  Create(AthreadFunc, AonFinishedProc, AOnErrorProc, ACreateSuspended, false);
  tracker.Add(self);
end;

destructor TAnonymousCommand<T>.Destroy;
begin
//  Debug.Log('Destroying Inherited '+self.GetObjectDebug);
  inherited;
//  Debug.Log('Destroying '+self.GetObjectDebug);
end;

procedure TAnonymousCommand<T>.DoExecute;
{$IFDEF MACOS}
var
  lPool: NSAutoreleasePool;
{$ENDIF}
begin
  inherited;
//  Debug.Log(self, 'Executing  '+self.GetObjectDebug);
{$IFDEF MACOS}
  //Need to create an autorelease pool, otherwise any autorelease objects
  //may leak.
  //See https://developer.apple.com/library/ios/#documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html#//apple_ref/doc/uid/20000047-CJBFBEDI
  lPool := TNSAutoreleasePool.Create;
  try
{$ENDIF}
    try
      if assigned(FthreadFunc) then begin
        if FSynchronizeExecute then begin
          TThread.Synchronize(self.Thread.realthread, SyncExecute)
        end else
          FResult := FThreadFunc;
      end;

      if assigned(FonFinishedProc) then begin
        try
          if FSynchronizeFinish and assigned(FOnFinishedProc) then
            TThread.Synchronize(self.Thread.realthread, SyncFinished)
          else
            FOnFinishedProc(FResult);
        except
          on E:Exception do begin
            Debug.Log('Exception during synchronized anon finish: '+e.message);
          end;
        end;
      end;
    except
      on E: Exception do begin
        Err := e;
        ErrorMessage := e.message;
        Error := true;
{$IFNDEF CONSOLE}
        if FSynchronizeFinish then
          TThread.Synchronize(self.Thread.realthread, SyncError)
        else
{$ENDIF}
          if assigned(FOnErrorProc) then
            FOnErrorProc(E);

      end;
    end;
{$IFDEF MACOS}
  finally
    lPool.drain;
  end;
{$ENDIF}
end;


procedure TAnonymousCommand<T>.InitExpense;
begin
  inherited;
//  self.Resources.SetResourceUsage('CTO_Anonymous', 1.0);
  cpuExpense := 0.0;
end;

procedure TAnonymousCommand<T>.SyncError;
begin
  FOnErrorProc(Err);
end;

procedure TAnonymousCommand<T>.SyncExecute;
begin
  FResult := FThreadFunc;
end;

procedure TAnonymousCommand<T>.SyncFinished;
begin
    FOnFinishedProc(fResult);
end;

{ Tcmd_Test }

procedure Tcmd_Test.DoExecute;
begin
  inherited;
  sleep(4000);
end;

procedure TAnonymousTimer.InitExpense;
begin
  inherited;
  CPuExpense := 0;
end;

function SetTimerGUI(interval: ni; ontimerproc: TAnonTimerProc): TAnonymousTimer;
begin
  result := TAnonymousTimer.create(
    function : boolean
    begin
      sleep(interval);
      exit(true);
    end,
    procedure (b: boolean)
    begin
      ontimerproc();
    end,
    procedure (e: exception)
    begin
    end
  );
  result.SynchronizeFinish := true;
  result.FireForget := true;
  result.start;
end;

function SetTimer(interval: ni; ontimerproc: TAnonTimerProc): TAnonymousTimer;
begin
  result := TAnonymousTimer.create(
    function : boolean
    begin
      sleep(interval);
      exit(true);
    end,
    procedure (b: boolean)
    begin
      ontimerproc();
    end,
    procedure (e: exception)
    begin
    end
  );
  result.SynchronizeFinish := false;
  result.FireForget := true;
  result.start;
end;


{ TAnonymousGUICommand<T> }

constructor TAnonymousGUICommand<T>.Create(AThreadFunc: TFunc<T>;
  AOnFinishedProc: TProc<T>; AOnErrorProc: TProc<Exception>; ACreateSuspended,
  FreeOnComplete: Boolean);
begin
  inherited;
  SynchronizeFinish := true;
end;

{ TAnonymousFunctionCommand }

constructor TAnonymousFunctionCommand.CreateInline(AThreadFunc: TProc;
  ACreateSuspended, FreeOnComplete: Boolean);
var
  funct: TFunc<boolean>;
begin
  funct:= function (): boolean
                begin
                  AthreadFunc();
                  result := true;
                end;


  Create(funct, nil, nil, ACreateSuspended, FreeOnComplete);
end;

constructor TAnonymousFunctionCommand.CreateInlineWithGui(AThreadFunc, GuiFunc: TProc;
  ACreateSuspended, FreeOnComplete: Boolean);
var
  func1: TFunc<boolean>;
  func2: TProc<boolean>;
begin
  func1:= function (): boolean
                begin
                  if assigned(AThreadFunc) then
                    AthreadFunc();
                  result := true;
                end;

  func2:= procedure (b: boolean)
                begin
                  if assigned(GuiFunc) then
                    GuiFunc();
                end;


  Create(func1, func2, procedure (e: exception) begin end, true, false);
  SynchronizeFinish := true;
  Start;


end;

constructor TAnonymousFunctionCommand.CreateInlineWithGuiEx(AThreadFunc,
  GuiFunc: TProc; exProc: TProc<string>; ACreateSuspended,
  FreeOnComplete: Boolean);
var
  func1: TFunc<boolean>;
  func2: TProc<boolean>;
  func3: TProc<string>;
begin
  func1:= function (): boolean
                begin
                  AthreadFunc();
                  result := true;
                end;
  func2 := nil;
  if assigned(guifunc) then
  func2:= procedure (b: boolean)
                begin
                  GuiFunc();
                end;
  func3 := nil;
  if assigned(exproc) then
  func3 := procedure (s: string)
          begin
            ExProc(s);
          end;


  Create(func1, func2, procedure (e: exception) begin func3(e.message) end, true, false);
  SynchronizeFinish := true;
  Start;


end;

{ TAnonymousIteratorCommand }

procedure TAnonymousIteratorCommand.DoExecute;
begin
  inherited;
  if batchcount = 0 then
    batchcount := 1;
  for var t:= 0 to batchcount-1 do begin
    proc(iteration+t);
  end;
end;

{ TPromise }

function TPromise.Go: TPromise;
begin
  result := self;
  cmd.o.StartChain;
end;

function TPromise.thenDo(p: TProc): TPromise;
begin
  result := Promise(p);
  result.parent := @self;
  result.cmd.o.FireForget := false;
  result.cmd.o.parenthold := result.cmd;
  result.cmd.o.AddDependency(result.parent.cmd.o);
end;

function TPromise.thenGUI(p: TProc): TPromise;
begin
  result := Promise(p);
  result.parent := @self;
  result.cmd.o.FireForget := false;
  result.cmd.o.AddDependency(result.parent.cmd.o);
  result.cmd.o.parenthold := result.cmd;
  result.cmd.o.SynchronizeExecute := true;


end;

function TPromise.WaitFor(iupTo: int64): boolean;
begin
  result := self.cmd.o.WaitFor(iUpTo);
end;

end.
