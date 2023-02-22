unit PerfMessageClient;
//!!!NOTE Don't call AddTarget before PeriodicEvents have been initialized

interface

uses
  betterobject, PerfMessage, typex, orderlyinit, numbers, idsockethandle,
  IdGlobal,IdBaseComponent, IdComponent, IdUDPBase, idudpclient, systemx, herro, managedthread,
  tickcount, debug, sysutils, generics.collections,  better_collections, skill;

type
  TPerfMessageClient = class;//forward

  Tthr_SendPerformanceData = class(TManagedThread)
  protected
    procedure DoExecute; override;
  public
    Interval: ticker;
    mypmc: TPerfMessageClient;
  end;

  THostAndEndpoint = record
  public
    host: string;
    port: ni;
    lastSeen: ticker;
    noexpire: boolean;
    class operator equal(a,b: ThostandEndpoint): boolean;
    procedure FromSkill(sk: TSkillinfo);
    procedure Seen;
  end;

  TPerfMessageClient = class(TSharedObject)
  private
    NewNodeIndex: ni;
    NewNodeId: ni;
    data: array[0..65535] of TPerfNode;
    desc: array[0..65535] of TPerfDescriptor;
    pe: Tthr_SendPerformanceData;
    udpc: TIdUdpclient;
    csTargets: TCLXCriticalSection;
    FTargets: TList<THostAndEndpoint>;
    tmSkillsChecked, tmDescriptors: ticker;
    procedure StartPE;
    procedure StopPE;
    procedure Go;//<----------------------------
    procedure SendPerformanceData;
    procedure SendDescriptorData;
    procedure InitClient;
    procedure CleanupClient;
    procedure initData;
    procedure SendToAllTargets(idb: TIDBytes);

    function IndexOfTarget(hap: THostAndEndpoint): ni;
    procedure ScrubTargets;
  public
    procedure ForwardToAllTargets(idb: TIDBytes; binding: TIDSocketHandle);
    function GetPerfHandle: TPerfHandle;
    procedure ReleasePerfHandle(var ph: TPerfHandle);
    procedure AddTarget(host: string; endpoint:ni; noexpire: boolean=false);//!!!NOTE Don't call AddTarget before PeriodicEvents have been initialized
    procedure RemoveTarget(host: string; endpoint:ni);
    procedure Shutdown;
    constructor Create; override;
    destructor Destroy; override;
    procedure AddTargetsFromSkills;

  end;

var
  _PMC: TPerfmessageClient = nil;

function PMC: TPerfMEssageClient;




implementation

{ TPerfMessageClient }

function PMC: TPerfMEssageClient;
begin
  if _PMC = nil then
    _PMC := TPerfMessageClient.create;

  result := _PMC;
end;

procedure TPerfMessageClient.AddTarget(host: string; endpoint: ni; noexpire: boolean=false);
var
  hap:THostAndEndpoint;
begin
  hap.seen;
  hap.host :=host;
  hap.port := endpoint;
  hap.noexpire := noexpire;
  ecs(csTargets);
  try
    if FTArgets.IndexOf(hap) < 0 then
      FTargets.Add(hap);
  finally
    lcs(csTargets);
  end;
end;

procedure TPerfMessageClient.AddTargetsFromSkills;
var
  sks: TArray<TSkillInfo>;
  hap: THostAndEndpoint;
begin
  ecs(csTargets);
  try
    sks := skill.Skills.FindAll('PerfNodeViewer');
    ScrubTargets;
    for var t:= 0 to high(sks) do begin
      hap.FromSkill(sks[t]);
      if IndexOfTarget(hap) <0 then
        AddTarget(hap.host, hap.port)
      else
        FTargets[indexofTarget(hap)].Seen;

    end;
    tmSkillsChecked := getticker;
  finally
    lcs(csTargets);
  end;
end;

procedure TPerfMessageClient.CleanupClient;
begin
  if udpc = nil then
    exit;
  udpc.free;
  udpc := nil;

end;

constructor TPerfMessageClient.Create;
begin
  inherited;
  ics(csTargets, classname+'-targets');
  FTargets := TList<THostAndEndpoint>.create;
  InitData;
  StartPE;
end;

destructor TPerfMessageClient.Destroy;
begin
  StopPE;
  FTargets.free;
  FTargets := nil;

  dcs(csTargets);

  inherited;
end;

procedure TPerfMessageClient.ForwardToAllTargets(idb: TIDBytes;
  binding: TIDSocketHandle);
begin
  SendToAllTargets(idb);
end;

function TPerfMessageClient.GetPerfHandle: TPerfHandle;
begin
  Lock;
  try
    result.node := nil;
    result.desc := nil;
    for var t := 0 to High(self.data) do begin
      if data[t].id = -1 then begin
        result.node := @data[t];
        result.desc := @desc[t];
        result.node.Init;
        result.desc.Init;
        result.id := t;
        NewNodeIndex := greaterof(NewNodeindex, t+1);
        break;
      end;
    end;
  finally
    unlock;
  end;
end;

procedure TPerfMessageClient.Go;
begin
  if gettimeSince(tmSkillsChecked) > 10000 then
    AddTargetsFromSkills;

  if gettimesince(tmDescriptors) > 1000 then
    SendDescriptorData;

  SendPerformanceData;

end;

function TPerfMessageClient.IndexOfTarget(hap: THostAndEndpoint): ni;
begin
  result := -1;
  Lock;
  try
    for var t:= 0 to FTargets.count-1 do begin
      if FTargets[t] = hap then
        exit(t);
    end;
  finally
    Unlock;
  end;
end;

procedure TPerfMessageClient.InitClient;
begin
  if udpc <> nil then exit;
  udpc := TIdUDPClient.Create(nil);
  udpc.BufferSize := 65535;
  udpc.BroadcastEnabled := true;
end;

procedure TPerfMessageClient.initData;
begin
  for var t:=0 to high(desc) do begin
    desc[t].init;
    data[t].Init;
  end;
end;

procedure TPerfMessageClient.ReleasePerfHandle(var ph: TPerfHandle);
begin
  Lock;
  try
    var ClearParentHandlesOf := ph.id;
    for var t:= 0 to high(Self.desc) do begin
      if desc[t].left = ClearParentHandlesOf then
        desc[t].left := -1;
      if desc[t].above = ClearParentHandlesOf then
        desc[t].above := -1;

    end;

    if ph.node <> nil then
      ph.node.Init;
    if ph.desc <> nil then
      ph.desc.Init;
    ph.node := nil;
    ph.desc := nil;
  finally
    Unlock;
  end;
end;

procedure TPerfMessageClient.RemoveTarget(host: string; endpoint: ni);
var
  hap:THostAndEndpoint;
begin
  hap.seen;
  hap.host :=host;
  hap.port := endpoint;
//  hap.noexpire := noexpire;
  ecs(csTargets);
  try
    if FTArgets.IndexOf(hap) >= 0 then
      FTargets.Remove(hap);
  finally
    lcs(csTargets);
  end;
end;

procedure TPerfMessageClient.ScrubTargets;
begin
  for var t:= FTargets.count-1 downto 0 do begin
    if FTargets[t].lastSeen > 600000 then begin
      FTargets.delete(t);
    end;
  end;

end;

procedure TPerfMessageClient.SendDescriptorData;
var
  idb: TIdBytes;
  hed: TPerfMessageHeader;
  haps: TArray<ThostAndEndpoint>;
  hap : THostAndEndpoint;
begin
  if udpc = nil then exit;
  hed.init;
  hed.ComputerName := systemx.GetComputerName;
  hed.processid := GetCurrentProcessID_XPLatform;
  var cx := NewNodeIndex;
  var fx :=0;
  while cx > 0 do begin
    hed.startnode := fx;
    hed.mtyp := MT_DESCRIPTORS;
    hed.nodesinmessage := lesserof(cx, 20);
    hed.totalnodes := NewNodeIndex;
    if hed.totalnodes = 0 then begin
//      debug.log('no nodes');
      exit;
    end;
    hed.ticker := getticker;
    var calculatedLength := sizeof(TPerfMessageHeader);
    calculatedLength := calculatedLength + (hed.nodesinmessage * SizeOf(TPerfDescriptor));
    setlength(idb, calculatedLength);
    MoveMem32(@idb[0],@hed, sizeof(hed));
    MoveMem32(@idb[sizeof(hed)], @self.desc[fx], hed.nodesinmessage * SizeOf(TPerfDescriptor));
    SendToAllTargets(idb);
    dec(cx, hed.nodesinmessage);
    inc(fx, hed.nodesinmessage);
  end;
  tmDescriptors := getticker;

end;


procedure TPerfMessageClient.SendPerformanceData;
var
  idb: TIdBytes;
  hed: TPerfMessageHeader;
begin
  if udpc = nil then exit;

  var calculatedLength := sizeof(TPerfMessageHeader);
  calculatedLength := calculatedLength + (NewNodeIndex * SizeOf(TPerfNode));
  setlength(idb, calculatedLength);
  hed.Init;
  hed.ComputerName := systemx.GetComputerName;
  hed.processid := GetCurrentProcessID_XPLatform;
  hed.mtyp := MT_PERFORMANCE_DATA;
  hed.startnode := 0;
  hed.nodesinmessage := NewNodeIndex;
  hed.totalnodes := NewNodeIndex;
  if hed.totalnodes = 0 then begin
//    debug.log('no nodes');
    exit;
  end;
  hed.ticker := getticker;
  MoveMem32(@idb[0],@hed, sizeof(hed));
  MoveMem32(@idb[sizeof(hed)], @self.data[0], NewNodeIndex * SizeOf(TPerfNode));
//  debug.log('perf package size:'+inttostr(length(idb)));
  SendToAllTargets(idb);

end;

procedure TPerfMessageClient.SendToAllTargets(idb: TIDBytes);
var
  haps: Tarray<THostAndEndpoint>;
  hap: ThostAndEndpoint;
begin
  ecs(csTargets);
  try
    haps := FTargets.ToArray;
  finally
    lcs(csTargets);
  end;
  for var t := 0 to high(haps) do begin
    hap := haps[t];
    udpc.SendBuffer(hap.Host, hap.port, idb);

  end;
end;

procedure TPerfMessageClient.Shutdown;
begin
  StopPe;
end;

procedure TPerfMessageClient.StartPE;
begin
  InitClient;
{$IFDEF ENABLE_PMC}
  pe :=tpm.Needthread<Tthr_SendPerformanceData>(nil);
{$IFDEF SLOW_PMC}
  pe.interval:= 1000;
{$ELSE}
  pe.interval:= 100;
{$ENDIF}
  pe.mypmc := self;
  pe.Loop := true;
  pe.start;
//  PEA.add(pe);
{$ENDIF}
end;

procedure TPerfMessageClient.StopPE;
begin
  try
    CleanUpClient;
    if assigned(pe) then begin
//      PEA.Remove(pe);
      pe.stop;
      pe.WaitFor;
      tpm.NoNeedthread(pe)
//      pe.free;
    end;
  finally
    pe := nil;
  end;

end;

procedure oinit;
begin
  PMC();
end;


procedure ofinal;
begin
  if assigned(_PMC) then begin
    PMC.shutdown; // LEAK the rest
{$IFNDEF LINUX}
    RegisterExpectedMemoryLeak(PMC);
{$ENDIF}
  end;
end;

{ Tthr_SendPerformanceData }

procedure Tthr_SendPerformanceData.DoExecute;
begin
  inherited;
  try
//    Debug.Log('go');
    var tmStart: ticker := GetTicker;
    mypmc.Go;
    var tmDif: ticker := gettimesince(tmStart);
    runhot := false;
    coldruninterval := interval;
  except
  end;
end;

{ THostAndEndpoint }

class operator THostAndEndpoint.equal(a, b: ThostandEndpoint): boolean;
begin
  result :=
    (compareText(a.host,b.host)=0)
    and (a.port = b.port);

end;

procedure THostAndEndpoint.FromSkill(sk: TSkillinfo);
begin
  seen;//sets ticker
  host := sk.Host;
  port := strtoint64(sk.endpoint);
end;

procedure THostAndEndpoint.Seen;
begin
  lastSeen := getticker;
end;

initialization

init.RegisterProcs('PerfMessageClient', oinit, ofinal, 'ManagedThread');


end.
