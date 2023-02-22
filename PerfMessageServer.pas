unit PerfMessageServer;

interface

uses
  betterobject, PerfMessage, typex, orderlyinit, PeriodicEvents, numbers, managedthread,
  IdGlobal,IdBaseComponent, IdComponent, IdUDPBase, idudpserver, systemx, stringx,
  tickcount, idsockethandle, herro, debug, sysutils, simplequeue, fatmessage;

type
  TPerfSnapshot = record
    tick: ticker;
    nodecount: ni;
    data: array[0..65535] of TPerfNode;
  end;
  TDeltaTiming = record
    lastseen: ticker;
    elapsedtime_betweenframes: ticker;
  end;

  TDeltaResult = record
    elapsedtime: ticker;
    received: ticker;
    data: TArray<TPerfNode>;
    raw: TArray<TPerfNode>;
    oldraw: Tarray<TPerfNode>;
    desc: TArray<TPerfDescriptor>;
    timings: Tarray<TDeltaTiming>;

    function CountNodesRight(node: PPerfDescriptor): ni;
  end;
  PDeltaResult = ^TDeltaResult;

  TRealmData = record
    lastseen: ticker;
    origin: string;
    eport: ni;
    currentbuffer: ni;
    data : array[0..1] of TPerfSnapshot;
    desc: array[0..65535] of TPerfDescriptor;
    function GetDeltas: TDeltaResult;
    procedure ApplyNewData(Adata: TIdBytes);
    function CompName: string;
  end;
  PRealmData = ^TRealmData;

  TAllDeltaResults = record
    realms: TArray<TRealmData>;
    delta_realms: Tarray<TDeltaResult>;
    function GetMergedDeltas: TDeltaResult;
  end;

  TPerfMessageServer = class;//forward
  TqiUDPReceived = class(TQueueItem)
  protected
    procedure DoExecute; override;
  public
    srv: TPerfMessageServer;
    byts: TIdBytes;
    peerip: string;
    peerport: nativeint;
  end;

  TPerfMessageServer = class(TSharedObject)
  private
    queue: TSimpleQueue;
    realms: TArray<TRealmData>;
    udpS: TIdUdpServer;
    function NewRealm(sHostid: string; eport: ni): PRealmData;
    function FindRealm(sHost: string; ePort: ni): PRealmData;

    procedure InitServer;
    procedure CleanupServer;
    procedure ScrubRealms;
    procedure ProcessFromQueue(Adata: tIDBytes; peerip:string; peerport: int64);
    procedure udps_OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
  public
    function GetDeltas: TAllDeltaResults;
    procedure Shutdown;
    constructor Create; override;
    procedure Detach; override;
  end;


var
  PerfMessageFilter : string = '';



implementation

{ TPerfMessageServer }

function CountNodesRight(node: PDeltaResult): ni;
begin
  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;

procedure TPerfMessageServer.CleanupServer;
begin
  udps.Active := false;
  udps.Free;
  udps := nil;
end;

constructor TPerfMessageServer.Create;
begin
  inherited;
  queue := TPM.Needthread<TSimpleQueue>(nil);
  queue.start;
  InitServer;
end;

procedure TPerfMessageServer.Detach;
begin
  if detached then exit;
  udpS.Active := false;
  queue.stop;
  Shutdown;
  queue.waitfor;
  TPM.NoNeedThread(queue);
  queue := nil;

  inherited;
end;

function TPerfMessageServer.FindRealm(sHost: string; ePort: ni): PRealmData;
begin
  Lock;
  try
    for var t:= 0 to High(realms) do begin
      if (realms[t].origin = sHost)
      and (realms[t].eport = ePort) then begin
        exit(@realms[t]);
      end;
    end;
    debug.log('realm not found '+sHost+':'+eport.tostring);
    exit(nil);

  finally
    Unlock;
  end;

end;

function TPerfMessageServer.GetDeltas: TAllDeltaResults;
begin
  Lock;
  try
    result.realms := realms;
    setlength(result.delta_realms, length(realms));
    for var t := 0 to high(realms) do
      result.delta_realms[t] := realms[t].GetDeltas;
  finally
    Unlock;
  end;

end;


procedure TPerfMessageServer.InitServer;
begin
  if udps <> nil then exit;
  udps := TIdUDPServer.create(nil);
  udps.ThreadedEvent := true;
  udps.OnUDPRead := self.udps_onUDPRead;
  udps.DefaultPort := 1444;
  udps.Active := true;
  herro.RegisterLocalSkill('PerfNodeViewer',1,'1444','UDP');
end;

function TPerfMessageServer.NewRealm(sHostid: string; eport: ni): PRealmData;
begin
  Lock;
  try
    var ip: string := '';
    var compname: string := '';
    splitstring(shostid, ' ', ip, compname);
    compname := lowercase(compname);

{$DEFINE SORT_REALMS}
{$IFDEF SORT_REALMS}
    var newpos := 0;

    for var t := 0 to high(realms) do begin
        var c := lowercase(realms[t].compname);
        if compname > c then
          inc(newpos)
        else
          if compname = c then begin
            if eport > realms[t].eport then
              inc(newpos)
            else
              break;
          end else
            break;
    end;
{$ELSE}
    var newpos := length(realms);
{$ENDIF}

    debug.log('realm will be added at '+inttostr(newpos)+' '+sHostID+':'+eport.tostring);
    setlength(realms, length(realms)+1);

    for var t:= high(realms) downto newpos+1 do begin
      realms[t] := realms[t-1];
    end;
    result := @realms[newpos];
    result.origin := sHostID;
    result.eport := eport;

  finally
    Unlock;
  end;
end;

procedure TPerfMessageServer.ProcessFromQueue(Adata: tIDBytes; peerip:string; peerport: int64);
begin
//  Debug.Log('process:'+peerip);
  Lock;
  try
    //get the header
    if adata[0] <> 0 then
      exit;

    var hostid := PeerIP+' '+PAnsiChar(@adata[1]);
    var r := FindRealm(hostid, Peerport);
    if r = nil then begin
      r := NewRealm(hostid, peerport);
//      r.origin := hostid;
//      r.eport := peerport;
    end;
    r.lastseen := getticker;
    r.ApplyNewData(AData);
    ScrubRealms;
  finally
    Unlock;
  end;

end;

procedure TPerfMessageServer.ScrubRealms;
begin
  lock;
  try
    for var t:= 0 to high(realms) do begin
      if gettimesince(realms[t].lastseen) > 120000 then begin
        for var x := t to high(realms)-1 do begin
          realms[x] := realms[x+1];
        end;
        setlength(realms, length(realms)-1);
        exit;//<<------------exit early because T range is now bad
      end;
    end;
  finally
    unlock;
  end;
end;

procedure TPerfMessageServer.Shutdown;
begin
  CleanupServer;
end;

procedure TPerfMessageServer.udps_OnUDPRead(AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  if PerfMessagefilter <> '' then
    if Abinding.PeerIP <> PerfMessageFilter then
      exit;
  var qi := TqiUDPReceived.Create;
  qi.byts := AData;
  SetLength(qi.byts, length(qi.byts));
  qi.peerip := abinding.peerip;
  qi.peerport := abinding.PeerPort;
  qi.srv := self;
  qi.autodestroy := true;
  queue.AddItem(qi);

end;


procedure oinit;
begin
//
end;

procedure ofinal;
begin
//
end;

{ TRealmData }

procedure TRealmData.ApplyNewData(Adata: TIdBytes);
var
  hed: TPerfMessageHeader;
begin

    if length(adata) < sizeof(hed) then
      exit;

    movemem32(@hed, @adata[0], sizeof(hed));
    if hed.startnode > high(desc) then exit;
    if hed.startnode <0 then exit;
    if hed.nodesinmessage= 0 then
      exit;

    //hed.ticker := getticker;

    case hed.mtyp of
      MT_PERFORMANCE_DATA: begin
        if self.data[0].tick = hed.ticker then begin
          exit;
        end;
        if self.data[1].tick = hed.ticker then begin
          exit;
        end;


        var writenode := (currentbuffer + 1) and 1;
        if self.data[writenode].tick = hed.ticker then begin
          exit;
        end;

        if hed.ticker = 0 then
          exit;

        if self.data[writenode].tick = hed.ticker then begin
          debug.log('wtf #99');
          exit;
        end;


        var szToCopy := hed.nodesinmessage * SizeOf(TPerfNode);
        var copystart := sizeof(TPerfMessageHEader);
        self.data[writenode].tick := hed.ticker;
        movemem32(@self.data[writenode].data[hed.startnode],@adata[copystart],szToCopy);
        self.data[writenode].nodecount := hed.nodesinmessage+hed.startnode;

        currentbuffer := writenode;

        if data[0].tick = data[1].tick then begin
          debug.log('wtf #101');
        end;

        MMQ.QuickBroadcast('NewStats');
      end;
      MT_DESCRIPTORS: begin
        if hed.startnode > high(desc) then exit;
        if hed.startnode <0 then exit;

        var tocopy := lesserof(length(desc)-hed.startnode, hed.nodesinmessage);
        var szToCopy :=tocopy * sizeof(TPerfDescriptor);
        var copystart := sizeof(TPerfMessageHEader);

        movemem32(@self.desc[hed.startnode],@adata[copystart],szToCopy);
      end;
    end;

  lastseen := getticker;

end;

function TDeltaResult.CountNodesRight(node: PPerfDescriptor): ni;
begin
  result := 0;
  for var t := 0 to High(desc) do
    if desc[t].left = node.id then
      inc(result);
end;

function TRealmData.CompName: string;
begin
  var s1 := '';
  var s2 := '';
  SplitString(origin, ' ', s1,s2);
  result := s2;
end;

function TRealmData.GetDeltas: TDeltaResult;
begin
  var idxNow := currentbuffer;
  var idxThen := (currentbuffer + 1) and 1;
  result.received := lastseen;
  result.elapsedtime := data[idxNow].tick-data[idxThen].tick;
//  if result.elapsedtime < 1000 then
//    debug.log('here2');
  var len := data[idxNow].nodecount;
  setlength(result.data, len);
  setlength(result.desc, len);
  setlength(result.raw, len);
  setlength(result.oldraw, len);

  for var t := 0 to lesserof(data[idxNow].nodecount, data[idxThen].nodecount)-1 do begin
    result.data[t].id := data[idxNow].data[t].id;
    result.data[t].r := data[idxNow].data[t].r - data[idxThen].data[t].r;
    result.data[t].w := data[idxNow].data[t].w - data[idxThen].data[t].w;
    result.data[t].typ := data[idxNow].data[t].typ;
    result.desc[t] := self.desc[t];
    result.data[t].busyR := data[idxNow].data[t].busyR;
    result.data[t].busyW := data[idxNow].data[t].busyW;

    result.raw[t].r := data[idxNow].data[t].r;
    result.raw[t].w := data[idxNow].data[t].w;
    result.raw[t].typ := data[idxNow].data[t].typ;
    if idxThen>=0 then begin
      result.oldraw[t].r := data[idxThen].data[t].r;
      result.oldraw[t].w := data[idxThen].data[t].w;
    end;
    result.desc[t] := self.desc[t];
    result.data[t].typ := data[idxNow].data[t].typ;
    result.data[t].busyR := data[idxNow].data[t].busyR;
    result.data[t].busyW := data[idxNow].data[t].busyW;


  end;


end;


{ TAllDeltaResults }

function TAllDeltaResults.GetMergedDeltas: TDeltaResult;
begin
  var len := 0;
  for var t:= 0 to high(delta_realms) do begin
    inc(len, lesserof(length(delta_realms[t].data), length(delta_realms[t].desc)));
    if t = 0 then
      result.received := delta_realms[t].received;
    result.received := lesserof(delta_realms[t].received, result.received);
  end;

  setlength(result.timings, len);


  setlength(result.data, len);
  setlength(result.desc, len);
  setlength(result.raw, len);
  setlength(result.oldraw, len);
  var realmbaseid := 0;
  var taridx:= 0;
  result.elapsedtime := 100000;
  for var r := 0 to high(delta_realms) do begin
    if delta_realms[r].elapsedtime > 0 then
      result.elapsedtime := lesserof(delta_realms[r].elapsedtime, result.elapsedtime);

    var nuBaseId: ni := realmbaseid;
//    Debug.log(inttostr(r)+'='+inttostr(realmbaseid));

    for var t := 0 to lesserof(high(delta_realms[r].data), high(delta_realms[r].desc)) do begin
      result.desc[taridx] := delta_realms[r].desc[t];
      result.data[taridx] := delta_realms[r].data[t];
      result.raw[taridx] := delta_realms[r].raw[t];
      result.oldraw[taridx] := delta_realms[r].oldraw[t];

      if result.desc[taridx].id >=0 then
        result.desc[taridx].id := result.desc[taridx].id+realmbaseid;
      if result.data[taridx].id >=0 then
        result.data[taridx].id := result.data[taridx].id+realmbaseid;
      if result.desc[taridx].left >=0 then
        result.desc[taridx].left := result.desc[taridx].left+realmbaseid;
      if result.desc[taridx].above >=0 then
        result.desc[taridx].above := result.desc[taridx].above+realmbaseid;
      if result.raw[taridx].id >=0 then
        result.raw[taridx].id := result.raw[taridx].id+realmbaseid;

      result.timings[taridx].elapsedtime_betweenframes := delta_realms[r].elapsedtime;
      result.timings[taridx].lastseen := delta_realms[r].received;



      nubaseid := greaterof(result.data[taridx].id+1, nubaseid);
      inc(taridx);

    end;
    realmbaseid :=  nubaseid;
  end;
end;

{ TqiUDPReceived }

procedure TqiUDPReceived.DoExecute;
begin
  inherited;
  srv.ProcessFromQueue(byts, peerip, peerport);
end;

initialization
  orderlyinit.init.RegisterProcs('PerfMessageServer', oinit, ofinal, 'herro');


end.
