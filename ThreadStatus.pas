unit ThreadStatus;

interface
{$IFNDEF NOAP}
uses
  OrderlyInit;
{$ELSE}
{x$DEFINE ALLOW_TSM_HIJACK}
{x$DEFINE DISALLOW_FREE_MEMORY}

uses
  typex, stringx, systemx, tickcount, numbers, betterobject, generics.collections, orderlyinit;


type
  TManagedThreadInfo = record
    spin: boolean;
    autospin: boolean;
    Fname: array[0..1024] of char;
    Fstatus: array[0..1024] of char;
    iterations: int64;
    progress: TProgress;
    Ferror: array[0..1024] of char;
    lastused: ticker;
    pooled: boolean;//requires refresh on extract
    Blocked: boolean;
    threadid: int64;//copied when real thread assigned
    signaldebug: string;
    coldruninterval: nativeint;
    tt: TThreadTimes;
    handle: THandle;
    totalActiveTime: int64;
    activeStartTime: int64;
    activenow: boolean;
    becameStaleAt: ticker;
  private
    function GetAge: ticker;
    function GetError: string;
    function GetName: string;
    function GetStatus: string;
    procedure SetError(const Value: string);
    procedure SetNAme(const Value: string);
    procedure SetStatus(const Value: string);
  public
    procedure StartActiveTime;
    procedure EndActiveTime;

    property Age: ticker read GetAge;
    function GetPercentActiveTime(var previoustotal,
      previoussampletime: int64): single;
    procedure Init;
    property Name: string read GetName write SetNAme;
    property Status: string read GetStatus write SetStatus;
    property Error: string read GetError write SetError;

  end;
  PManagedThreadInfo = ^TManagedThreadInfo;

type
  TThreadStatusManager = class(TSharedObject)
  private
    data: TList<PManagedThreadInfo>;
    procedure Remember(stat: PManagedThreadInfo);
    procedure Forget(stat: PManagedThreadInfo);
  public
    procedure Init;override;
    procedure Detach;override;
    function AllocateStatus: PManagedThreadInfo;
    procedure ReleaseStatus(ifo: PManagedThreadInfo);
    procedure CleanupStaleStatuses(dont_free_pointer_optional: PManagedThreadInfo);
    function GetInfoList: TArray<TManagedThreadInfo>;
    procedure Inject(stat: PManagedthreadInfo);
    procedure GiveToExternalTSM(tsm: TThreadStatusManager);

  end;


var
  TSM: TThreadStatusManager = nil;


function CurrenTManagedThreadInfo: PManagedThreadInfo;


procedure TVSetThreadStatus(s: string);
procedure TVSetThreadName(s: string);
procedure TVSetThreadProgress(const iPos: ni; const iMax: ni = -1);
{$IFDEF ALLOW_TSM_HIJACK}
procedure UseExternalThreadStatusManager(extsm: TThreadStatusManager);
{$ENDIF}


threadvar
  TV_CurrenTManagedThreadInfo: PManagedThreadInfo;//YES Threadvars are initialized to 0 automatically


{$IFDEF ALLOW_TSM_HIJACK}
exports
  UseExternalThreadStatusManager;
{$ENDIF}

{$ENDIF}

implementation


{$IFDEF NOAP}
uses
  BackgroundThreads;

{$IFDEF ALLOW_TSM_HIJACK}
 procedure UseExternalThreadStatusManager(extsm: TThreadStatusManager);
//when this module is loaded by another module, you might want
//all the thread statuses to be monitored by the loading module
//so call.. this...
//it cannot be undone!!!
//unloading the module may leak a couple bytes of memory (will have to think about it)
begin
{$IFDEF ALLOW_ANON_TS}
xxx
  if TSM = nil then begin
    TSM := extsm;
    exit;
  end;

  TSM.Lock;
  try
    TSM.GiveToExternalTSM(extsm);
    TSM := extsm;
  finally
    TSM.Unlock;
  end;
{$ENDIF}

end;
{$ENDIF}


function CurrenTManagedThreadInfo: PManagedThreadInfo;
begin
{$IFDEF ALLOW_ANON_TS}
  if TV_CurrenTManagedThreadInfo = nil then
    TV_CurrenTManagedThreadInfo := TSM.AllocateStatus;

  result := TV_CurrenTManagedThreadInfo;
{$ELSE}
  result := nil;
{$ENDIF}
end;


procedure TVSetThreadStatus(s: string);
begin
{$IFDEF ALLOW_ANON_TS}
  CurrenTManagedThreadInfo.status := s;
{$ENDIF}
end;

procedure TVSetThreadName(s: string);
begin
{$IFDEF ALLOW_ANON_TS}
  CurrenTManagedThreadInfo.name := s;
{$ENDIF}
end;


procedure TVSetThreadProgress(const iPos: ni; const iMax: ni = -1);
begin
{$IFDEF ALLOW_ANON_TS}
  if iMax > 0 then
    CurrenTManagedThreadInfo.progress.step := iMax;
  CurrenTManagedThreadInfo.progress.step := iPos;
{$ENDIF}

end;


function TManagedThreadInfo.GetAge: ticker;
begin
  result := getticker-lastused;
end;

function TManagedThreadInfo.GetError: string;
begin
  setlength(result, length(FError));
  movemem32(@result[STRZ], @FError[0], length(FError));
  result := FindZeroEnd(result);
end;

function TManagedThreadInfo.GetName: string;
begin
  setlength(result, length(FName));
  movemem32(@result[STRZ], @FName[0], length(FName));
  result := FindZeroEnd(result);

end;

function TManagedThreadInfo.GetPercentActiveTime(
  var previoustotal, previoussampletime: int64): single;
var
  tmNow, newstart, tat, tot: int64;
begin
  tmNow := gethighResTicker;
  tat := TotalActiveTime;
  if ActiveNow then
    tat := tat + GetTimeSince(tmNow, activestartTime);

  newstart := tat;
  tat := tat - previoustotal;
  if tat < 0 then tat := 0;
  previoustotal := newstart;

  //ACTIVETIME/TOTAL_TIME
  tot := GetTimeSince(tmNow, previoussampletime);
  previoussampletime := tmNow;
  if tot = 0 then
    exit(0.0)
  else
    result := lesserof(1.0,tat/tot);

end;

function TManagedThreadInfo.GetStatus: string;
begin
  setlength(result, length(FStatus));
  movemem32(@result[STRZ], @FStatus[0], length(FStatus));
  result := FindZeroEnd(result);
end;

procedure TManagedThreadInfo.Init;
begin
  threadid := 0;
  name := '';
  status := '';
  error := '';
//  name := 'blocked';
//  status := 'blocked';
end;

procedure TManagedThreadInfo.SetError(const Value: string);
begin
  movemem32(@Ferror[0], @Value[STRZ], lesserof(length(value), length(Ferror))*sizeof(char));
  Fstatus[lesserof(high(FStatus),length(Ferror))] := #0;
end;

procedure TManagedThreadInfo.SetNAme(const Value: string);
begin
  movemem32(@FName[0], @Value[STRZ], lesserof(length(value), length(FName))*sizeof(char));
  Fstatus[lesserof(high(FStatus),length(FName))] := #0;
end;

procedure TManagedThreadInfo.SetStatus(const Value: string);
begin
  movemem32(@FStatus[0], @Value[STRZ], lesserof(length(value), length(FStatus))*sizeof(char));
  Fstatus[lesserof(high(FStatus),length(FStatus))] := #0;
end;

procedure TManagedThreadInfo.StartActiveTime;
begin
  activestartTime := tickcount.GetHighResTicker;
  ActiveNow := true;
end;


procedure TManagedThreadInfo.EndActiveTime;
var
  nao: int64;

begin
  nao := GetHighREsticker;
  totalActiveTime := totalActiveTime + GetTimeSince(nao, activestarttime);
  ActiveNow := false;
end;


{ TThreadStatusManager }

function TThreadStatusManager.AllocateStatus: PManagedThreadInfo;
begin
{$IFDEF ALLOW_TSM_HIJACK}
  Lock;//lock is only required if we're allowing TSM to be highjacked by loading module
{$ENDIF}
  try

{$IFDEF ALLOW_TSM_HIJACK}
    if self <> TSM then begin
      result := TSM.AllocateStatus;
      exit;
    end;
{$ENDIF}

    result := GetZeroMemory(sizeof(TManagedThreadInfo));
    Remember(result);
  finally
{$IFDEF ALLOW_TSM_HIJACK}
    Unlock;
{$ENDIF}
  end;
end;

procedure TThreadStatusManager.CleanupStaleStatuses(dont_free_pointer_optional: PManagedThreadInfo);
var
  ifos: TArray<TManagedThreadInfo>;
  function HasIfo(threadid: cardinal): boolean;
  begin
    for var t := 0 to high(ifos) do begin
      if ifos[t].threadid = threadid then
        exit(true);
    end;
    exit(false);
  end;
begin
  Lock;
  try
  ifos := BackgroundthreadMan.GetInfoList;
  for var t := data.count-1 downto 0 do begin
    if not HasIfo(data[t].ThreadID) then begin
      var dat: PManagedThreadInfo := data[t];
      if dat.becameStaleAt = 0 then begin
        dat.becameStaleAt := getticker;
      end;
      if (dat.becameStaleAt > 0) and (getTimeSince(dat.becameStaleAt) > 10000) then begin
  {$IFNDEF DISALLOW_FREE_MEMORY}

        if data[t] <> dont_free_pointer_optional then
          FreeMemory(data[t]);
  {$ENDIF}
        data.delete(t);
      end;
    end else begin
      data[t].becameStaleAt := 0;
    end;
  end;
  finally
    unlock;
  end;
end;

function TThreadStatusManager.GetInfoList: TArray<TManagedThreadInfo>;
begin
  Lock;
  try
    setlength(result, data.Count);
    for var t:= 0 to data.count-1 do begin
      result[t] := data[t]^;
    end;
  finally
    Unlock;
  end;

end;


procedure TThreadStatusManager.GiveToExternalTSM(tsm: TThreadStatusManager);
begin
  exit;
  for var t:= 0 to data.count-1 do begin
    tsm.inject(data[t]);
  end;
  data.clear;

end;

procedure TThreadStatusManager.Remember(stat: PManagedThreadInfo);
begin
  Lock;
  try
    data.add(stat);
  finally
    Unlock;
  end;
end;

procedure TThreadStatusManager.Detach;
begin
  if detached then
    exit;
  data.free;
  data := nil;

  inherited;

end;

procedure TThreadStatusManager.Forget(stat: PManagedThreadInfo);
begin
  Lock;
  try
    data.remove(stat);
  finally
    unlock;
  end;
end;

procedure TThreadStatusManager.Init;
begin
  inherited;
  data := TList<PManagedThreadInfo>.create;
end;

procedure TThreadStatusManager.Inject(stat: PManagedthreadInfo);
begin
  lock;
  try
    Remember(stat);
  finally
    unlock;
  end;
end;

procedure TThreadStatusManager.ReleaseStatus(ifo: PManagedThreadInfo);
begin
{$IFDEF ALLOW_TSM_HIJACK}
  Lock;
  try
{$ENDIF}

{$IFDEF ALLOW_TSM_HIJACK}
  if SELF <> TSM then begin
    TSM.ReleaseStatus(ifo);
  end else begin
{$ENDIF}
    Forget(ifo);//has it's own lock
    freememory(ifo);
    CleanupStaleStatuses(ifo);
                        //^passing this optional parameter causes
                        //this function to remove the array entry but not free
                        //the underlying pointer (we already freed it)
                        //besides, this pointer should already be removed
                        //by the call to Forget(ifo) above
{$IFDEF ALLOW_TSM_HIJACK}
  end;
{$ENDIF}
{$IFDEF ALLOW_TSM_HIJACK}
  finally
    Unlock;
  end;
{$ENDIF}
end;
{$ENDIF}

procedure oinit;
begin
{$IFDEF NOAP}
  if TSM = nil then
    TSM := TThreadStatusManager.create;
{$ENDIF NOAP}

end;
procedure ofinal;
begin
{$IFDEF NOAP}
  if assigned(TSM) then
    TSM.free;
  TSM := nil;
{$ENDIF NOAP}
end;




initialization

  init.RegisterProcs('ThreadStatus', oinit, nil, ofinal, nil, 'systemx');



end.
