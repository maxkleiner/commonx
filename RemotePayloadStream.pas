unit RemotePayloadStream;

interface

uses
  stringx, sysutils, endian, PerfMessage, perfmessageclient,idglobal,systemx,
  idtcpclient, classes, killflag, debug, typex, tickcount;


type
  TPayMessage = packed record
    cmd: byte;
    arg: int64;
  end;


  TRemotePayloadStream = class(TStream)
  private
    function GetOffLine: boolean;
    procedure SetOffLine(const Value: boolean);
  protected
    cli: TIdTCPClient;
    remoteip: string;
    remoteport: nativeint;
    FTrackedSize: int64;
    FPos: int64;
    FOffline: boolean;
    FOfflinetime: ticker;
    procedure WriteMsg(msg: TPayMessage);

    procedure SetSize(const NewSize: Int64); override;
    function GetSize: Int64; override;

    function TrySomething(proc: TFunc<boolean>): boolean;
    procedure RefreshSeek;

    procedure EstablishConnection;
    function ReadRemoteSize: int64;
  public
    phIO: TPerfhandle;
    property offline: boolean read GetOffLine write SetOffLine;

    constructor Create(host: string; port: int64);
    destructor Destroy;override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function TryRead(pc: PByte; Count: Integer): Integer;
    function Write(const Buffer; Count: Integer): Integer; override;
    function TryWrite(pc: PByte; Count: Integer): Integer;
    function Seek(Offset: Integer; Origin: Word): Integer; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;








  end;

function IsRPS(sFile: string): boolean;


implementation

{ TRemotePayloadStream }

function IsRPS(sFile: string): boolean;
begin
  result := 0=CompareText('rps:', zcopy(sFile, 0,4));
end;

constructor TRemotePayloadStream.Create(host: string; port: int64);
begin
  inherited Create;
  remoteip := host;
  remoteport := port;
  phIO := PMC.GetPerfHandle;
  FTrackedSize := -1;
end;

destructor TRemotePayloadStream.Destroy;
begin
  if cli <> nil then begin
    cli.free;
    cli := nil;
  end;
  PMC.ReleasePerfHandle(phIO);
  inherited;
end;

procedure TRemotePayloadStream.EstablishConnection;
begin
  if (cli <> nil) and cli.connected then
    exit;

  if cli <> nil then begin
    cli.free;
    cli := nil;
  end;

  cli := TIdTCPClient.create;
  cli.Host := remoteip;
  cli.Port := remoteport;
  cli.connect;
  FTrackedSize := -1;
  RefreshSeek;


end;

function TRemotePayloadStream.GetOffLine: boolean;
begin
  result := FOffline and (gettimesince(FOfflineTime) < 150000);
end;

function TRemotePayloadStream.GetSize: Int64;
begin
  if FTrackedSize < 0 then
    FTrackedSize := ReadRemoteSize;

  result := FTrackedSize;

end;

function TRemotePayloadStream.Read(var Buffer; Count: Integer): Integer;
begin
  var pc := PByte(@buffer);
  result := TryRead(pc, count);
end;

function TRemotePayloadStream.ReadRemoteSize: int64;
begin
  var sz: int64 := 0;
  if offline then
    raise ECritical.create('remote payload stream is offline');
  offline := not TrySomething(function: boolean begin
    var msg: TPayMessage;
    msg.cmd := 4;
    msg.arg := 0;
    WriteMsg(msg);
    sz := cli.IOHandler.ReadInt64();
    endianswap(@sz,8);
    result := true;
  end);

  result := sz;

end;

procedure TRemotePayloadStream.RefreshSeek;
begin
  Seek(Fpos, soBeginning);
end;

function TRemotePayloadStream.Seek(Offset: Integer; Origin: Word): Integer;
begin
  raise ECritical.create('do not call 32-bit version of Seek');


end;

function TRemotePayloadStream.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  if offline then
    raise ECritical.create('remote payload stream is offline');
  var nuPos := offset;
  case Origin of
      TSeekOrigin.soBeginning: begin

      end;
      soCurrent: begin
        nuPos := FPos + nuPos;
      end;
      soEnd: begin
        nuPos := Size - nuPos;
      end;
  end;

  offline := not TrySomeThing(function: boolean begin
    var msg: TPayMessage;
    msg.cmd := 1;
    msg.arg := nuPos;
    WriteMsg(msg);
    FPos := nuPos;
    if FPos > FTrackedSize then
      FTrackedSize := FPos;
    result := true;
  end);

  result := FPos;

end;

procedure TRemotePayloadStream.SetOffLine(const Value: boolean);
begin
  FOffline := value;
  if value then
    FOfflineTime := getticker;
end;

procedure TRemotePayloadStream.SetSize(const NewSize: Int64);
begin
  inherited;
  offline := not TrySomething(function: boolean begin
    var msg: TPayMessage;
    msg.cmd := 5;
    msg.arg := NewSize;
    WriteMsg(msg);
    result := true;
  end);
  FTrackedSize := NewSize;
end;

function TRemotePayloadStream.TryRead(pc: PByte; Count: Integer): Integer;
var
  a: TIDBytes;
  got: int64;
begin
  if offline then
    raise ECritical.create('remote payload stream is offline');
  phIO.node.busyR := true;
  offline := not TrySomething(function: boolean begin
    var msg: TPayMessage;
    msg.cmd := 2;
    msg.arg := count;
    WriteMsg(msg);
    setlength(a, count);
    got := cli.IOHandler.ReadInt64;
    endianswap(@got, 8);
    setlength(a,0);
    cli.IOHandler.ReadBytes(a, got);
    movemem32(pc,@a[0], got);
    FPos := FPos + got;
    result := true;

  end);
  if offline then
    got := 0;
  result := got;
  phIO.node.incR(result);

end;

function TRemotePayloadStream.TrySomething(proc: TFunc<boolean>): boolean;
begin
  result := false;
  var tmStart := GetTicker;
  var success := false;
  repeat
    try
      EstablishConnection;
      success := proc();
    except
      on E: exception do begin
        Debug.Log('Error in rps:'+remoteip+':'+remoteport.tostring+' '+e.message);
        if ApplicationShutdown then
          exit;
        try
          cli.disconnect;
        except
        end;
        if GetTimeSince(tmStart) > 30000 then
          exit(false);

        sleep(4000);
      end;
    end;
  until success;

  result := success;

end;

function TRemotePayloadStream.TryWrite(pc: PByte; Count: Integer): Integer;
var
  a: TIDBytes;
begin
  if offline then
    raise ECritical.create('remote payload stream is offline');
  phIO.node.busyW := true;
  offline := not TrySomething(function:boolean begin
    var msg: TPayMessage;
    msg.cmd := 3;
    msg.arg := count;
    WriteMsg(msg);
    setlength(a, count);
    movemem32(@a[0], pc, count);
    cli.IOHandler.Write(a);
    FPos := FPos + count;
    result := true;
  end);
  if offline then
    count := 0;
  result := count;
  phIO.node.incW(result);
end;

function TRemotePayloadStream.Write(const Buffer; Count: Integer): Integer;
begin
  var pc :PByte := PByte(@buffer);
  result := TryWrite(pc, count);

end;

procedure TRemotePayloadStream.WriteMsg(msg: TPayMessage);
begin
  cli.UseNagle := true;
  cli.IOHandler.Write(msg.cmd);
  endianswap(@msg.arg, 8);
  cli.UseNagle := false;
  cli.IOHandler.Write(msg.arg);


end;

end.
