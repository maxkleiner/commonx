unit SocketProxy;

interface



uses
  typex, systemx, stringx, simplewinsock, simpletcpconnection, periodicevents,
  betterobject, simpleabstractconnection, generics.collections, orderlyinit, tickcount;

type
  TLocalConnectionType = TSimpleTCPConnection;

  IConnection = IHolder<TLocalConnectionType>;

  TsocketProxy = class(TSharedobject)
  private
    FList: TList<IConnection>;
    pe: TExternalPeriodicEvent;
    procedure Periodically(event: TPeriodicEvent);
  public

    function FindSocket(id: int64): IConnection;
    function Connect(shost: string; sEndpoint: string):IConnection;
    procedure Disconnect(id: int64);
    constructor Create; override;
    procedure Detach; override;
    procedure Clean;

  end;


var SkPx: TSocketProxy = nil;


implementation

{ TsocketProxy }

procedure TsocketProxy.Clean;
begin
  Lock;
  try
    for var t:= FList.Count-1 downto 0 do begin
      if gettimesince(FList[t].o.LastUsage) > 600000 then
        FList.delete(t);
    end;
  finally
    Unlock;
  end;
end;

function TsocketProxy.Connect(shost, sEndpoint: string): IConnection;
begin
  var c := TLocalConnectionType.Create;
  c.HostName := shost;
  c.EndPoint := sendPoint;

  result := THolder<TLocalConnectionType>.create;
  result.o:= c;
  result.o.Connect;

  if result.o.connected then begin
    lock;
    try
      var uid := result.o.GetUniqueID();
//      var found : IConnection := FindSocket(uid);
//      if found = nil then
        result.o.lastusage := getticker;
        FList.Add(result)
//      else
//        result := nil;
    finally
      Unlock;
    end;
  end;









end;

constructor TsocketProxy.Create;
begin
  inherited;
  FList := TList<IConnection>.create;
  pe := TExternalPeriodicEvent.Create;
  pe.OnEvent := self.Periodically;
  pe.Interval := 30000;
  PEA.Add(pe);
end;

procedure TsocketProxy.Detach;
begin

  if detached then exit;
  PEa.Remove(pe);
  pe.Free;
  pe := nil;

  FList.Clear;
  FList.free;
  FList := nil;
  inherited;

end;

procedure TsocketProxy.Disconnect(id: int64);
begin
  var found: IConnection := nil;
  begin
    var l:ILock := LockI;
    found := FindSocket(id);
    if found <> nil then
      Flist.Remove(found);
  end;
  if found <> nil then
    found.o.Disconnect;



end;

function TsocketProxy.FindSocket(id: int64): IConnection;
begin
  result := nil;
  Lock;
  try
    for var t:= 0 to FList.Count-1 do begin
      if FList[t].o.GetUniqueID = id then begin
        FList[t].o.LastUsage := GetTicker;
        exit(FList[t]);
      end;
    end;
  finally
    Unlock;
  end;
end;


procedure TsocketProxy.Periodically(event: TPeriodicEvent);
begin
  clean;
end;

procedure oinit;
begin
  SkPx := TsocketProxy.Create;
end;

procedure ofinal;
begin
  if assigned(SkPx) then
    SkPx.Free;
  SkPx := nil;
end;

initialization
  init.RegisterProcs('socketproxy', oinit, ofinal, 'managedthread');

end.
