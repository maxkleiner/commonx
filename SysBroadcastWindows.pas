unit SysBroadcastWindows;

interface

uses
  perfmessageclient, orderlyinit,
  PerfMessage, sysutils, stringx,
{$IFDEF MSWINDOWS}
  CPuUsage,
  diskusage,
{$ENDIF}
  consolex, tickcount, managedthread,
  typex, systemx;

type
  TSysBroadcastThread = class(TManagedThread)
  protected
    procedure DoExecute; override;
  public
    con:TConsole;
    lastupdated: ticker;
    procedure InitFromPool; override;


  end;



var
  usage: TCPUUsage;
  usages: TArray<TCPUUsage>;
  nodeh: TPerfHandle;
  cpunodes: TArray<TPerfHandle>;
  disknodes: TArray<TPerfHandle>;

  nicnodes: TArray<TPerfHandle>;
  gpunodes: TArray<TPerfHandle>;



procedure SyncCPUNodes(cnt: nativeint);
procedure SyncDiskNodes(cnt: nativeint);
procedure SyncNodes(var a: TArray<TPerfHandle>; nameprefix: string; typ: ni; cnt: nativeint);


procedure BroadcastSystemPerformance(con: TConsole = nil);


implementation


procedure SyncCPUNodes(cnt: nativeint);
begin

  if length(cpunodes) < cnt then begin
    var st := length(cpunodes);
    setlength(cpunodes,cnt);
    for var t := st to high(cpunodes) do begin
      cpunodes[t] := PMC.GetPerfHandle;
      cpunodes[t].desc.above := nodeh.id;
      cpunodes[t].node.typ := NT_CPU;
      cpunodes[t].desc.Desc := 'cpu#'+inttostr(t);
    end;
  end;

  if length(cpunodes) > cnt then begin
    var st := length(cpunodes);
    for var t := st-1 downto cnt do
      PMC.ReleasePerfHandle(cpunodes[t]);
  end;

end;

procedure SyncDiskNodes(cnt: nativeint);
begin

  if length(disknodes) < cnt then begin
    var st := length(disknodes);
    setlength(disknodes,cnt);
    for var t := st to high(disknodes) do begin
      disknodes[t] := PMC.GetPerfHandle;
      disknodes[t].desc.left := nodeh.id;
      disknodes[t].node.typ := NT_CPU;
      disknodes[t].desc.Desc := 'disk#'+inttostr(t);
    end;
  end;

  if length(disknodes) > cnt then begin
    var st := length(disknodes);
    for var t := st-1 downto cnt do
      PMC.ReleasePerfHandle(disknodes[t]);
  end;

end;

procedure SyncNodes(var a: TArray<TPerfHandle>; nameprefix: string; typ: ni; cnt: nativeint);
begin

  if length(a) < cnt then begin
    var st := length(a);
    setlength(a,cnt);
    for var t := st to cnt-1 do begin
      a[t] := PMC.GetPerfHandle;
      a[t].desc.left := nodeh.id;
      a[t].node.typ := typ;
      a[t].desc.Desc := nameprefix+'#'+inttostr(t);
    end;
  end;

  if length(a) > cnt then begin
    var st := length(a);
    for var t := st-1 downto cnt do
      PMC.ReleasePerfHandle(a[t]);
  end;

end;



var
  oldDisks: Tarray<int64>;

procedure BroadcastSystemPerformance(con: TConsole = nil);
begin
  //if con <> nil then con.clearscreen;

//  var disks := GetPerformanceArray('Win32_PerfFormattedData_PerfDisk_PhysicalDisk',['PercentDiskTime'],'*');
//  var disks := GetPerformanceArray('Win32_PerfFormattedData_PerfDisk_PhysicalDisk',['CurrentDiskQueueLength'],'*');
  var newdisks := GetPerformanceArray('Win32_PerfRawData_PerfDisk_PhysicalDisk',['AvgDiskQueueLength'],'*');
  var deltaDisks := CalculateArrayDeltas(olddisks, newdisks,1000);
  olddisks := newdisks;

{$IFDEF GPU_PERF}
  var gpus := GetPerformanceArray('Win32_VideoController',['BytesReceivedPersec','BytesSentPersec'],'*');
  if con <> nil then con.WriteLn(length(nics).tostring+' nics found');
  syncnodes(nicnodes, 'nic',NT_NIC,length(nics) shr 1);
  for var t:= 0 dto (high(nics)) do begin
    if con <> nil then con.WriteLn('Nic #'+inttostr(t)+': '+inttostr(nics[t]));
    if (t and 1) = 0 then
      nicnodes[t shr 1].node.r := nics[t]
    else
      nicnodes[t shr 1].node.w := nics[t];
  end;
{$ENDIF}
  syncnodes(disknodes, 'disk',NT_DISK,length(deltadisks));
  for var t:= 0 to high(deltadisks) do begin
    if con <> nil then con.WriteLn('Disk #'+inttostr(t)+': '+floatprecision(deltadisks[t],1));
    disknodes[t].node.r := round(deltadisks[t]);
    disknodes[t].node.w := 1000;
  end;

  //Win32_PerfFormattedData_Tcpip_NetworkInterface
  //Win32_PerfRawData_Tcpip_NetworkInterface
  var nics := GetPerformanceArray('Win32_PerfFormattedData_Tcpip_NetworkInterface',['BytesReceivedPersec','BytesSentPersec'],'*');
  if con <> nil then con.WriteLn(length(nics).tostring+' nics found');
  syncnodes(nicnodes, 'nic',NT_NIC,length(nics) shr 1);
  for var t:= 0 to (high(nics)) do begin
    if con <> nil then con.WriteLn('Nic #'+inttostr(t)+': '+inttostr(nics[t]));
    if (t and 1) = 0 then
      nicnodes[t shr 1].node.r := nics[t]
    else
      nicnodes[t shr 1].node.w := nics[t];
  end;


  if con <> nil then con.WriteLn('Gettting CPU Usages');
  usages := GetCpuUsages(usages);
  if con <> nil then con.WriteLn('Syncing Nodes');
  syncCPUNodes(length(usages));
  var sumUsed :int64 := 0;
  var sumTotal:int64 := 0;
  if con <> nil then con.WriteLn('Iterate');
  for var t := 0 to high(usages) do begin
    if con <> nil then con.WriteLn('Cpu #'+inttostr(t)+': '+floatprecision(usages[t].usage,4)+'/'+floatprecision(usages[t].max,2));
    cpunodes[t].node.r := round(usages[t].usage * 1000);
    cpunodes[t].node.w := 1000;
    sumUsed := sumUsed + cpunodes[t].node.r;
    sumTotal := sumTotal + cpunodes[t].node.w;
  end;

  usage := GetCPuUsage(usage);
  if con <> nil then con.WriteLn('Cpu (not great for vms): '+floatprecision(usage.usage,4)+'/'+floatprecision(usage.max,2));

  nodeh.node.r := sumUsed;
  nodeh.node.w := sumTotal;

  if con <> nil then con.WriteLn('Cpu (vm aware)         : '+floatprecision(sumUsed/1000,4)+'/'+floatprecision(sumTotal/1000,2));


end;

procedure oinit;
begin
  nodeh :=PMC.GetPerfHandle;
  nodeh.node.typ := NT_CPU_OVERALL;
  nodeh.desc.Desc := SystemX.GetComputerName;

end;

procedure ofinal;
begin
  if assigned(_PMC) then
    PMC.ReleasePerfHandle(nodeh);
end;


{ TSysBroadcastThread }


procedure TSysBroadcastThread.DoExecute;
begin
  inherited;
  try
    BroadcastSystemPerformance(con);
    lastupdated := getticker;
  except
    lastupdated := 0;
  end;
end;

procedure TSysBroadcastThread.InitFromPool;
begin
  inherited;
  Self.loop := true;
  runhot := false;
  coldruninterval := 1000;
  lastupdated := getticker;

end;

initialization



init.registerprocs('SysBroadcast', oinit, ofinal, 'PerfMessageClient');


end.
