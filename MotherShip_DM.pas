unit MotherShip_DM;

interface

uses
  typex, WebProcessor, better_sockets,sockfix,SysUtils, Classes, speech, ExtCtrls, easyimage, debug, applicationparams, commandprocessor;

type
  TdmMotherShip = class(TDataModule)
    tmMainThread: TTimer;

    procedure DataModuleCreate(Sender: TObject);
    procedure tcpAccept(Sender: TObject; ClientSocket: TCustomIpClient);
    procedure tmMainThreadTimer(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    cmds: TCommandList<Tcmd_ProcessWebREquests>;
    { Private declarations }

  public
    { Public declarations }
    tcp: TBetterTcpServer;
    procedure Listen;
    procedure StopListening;

  end;

var
  dmMotherShip: TdmMotherShip;

implementation

uses mothershipwebserver, systemx, webconfig,
  RequestInfo, NewServerSocketThread;

{$R *.dfm}

procedure TdmMotherShip.DataModuleCreate(Sender: TObject);
var
  sKeyName: string;
begin
  cmds := TCommandlist<Tcmd_ProcessWebRequests>.create;
  sKeyName := lowercase(DLLName);
  sKeyName := changefileext(sKeyName, '.ini');

  tcp := TBetterTCPServer.create(self);
  tcp.BlockMode := bmThreadBlocking;
  tcp.OnAccept := self.tcpAccept;
  tcp.LocalPort := apget('ListeningPort', '89');
  tcp.active := false;



  WebServer := TMothershipWebServer.create();
  WebServer.Configure(sKeyName, []);
//  WebServer.OnStartListening := self.Listen;
//  WebServer.OnStopListening := self.StopListening;
  Listen;
//  SayNatural('Listening on port '+tcp.LocalPort);

end;


procedure TdmMotherShip.Listen;
begin
  WebServer.Start;
  tcp.Active := true;
  if not tcp.active then
    raise ECritical.create('could not listen on port '+tcp.localport);
end;

procedure TdmMotherShip.DataModuleDestroy(Sender: TObject);
begin
  if tcp.active then
    StopListening;
  webserver.free;
  webserver := nil;
  inherited;
end;

procedure TdmMotherShip.StopListening;
begin
  tcp.active := false;
  if webserver <> nil then
    webServer.Stop;

  while cmds.count > 0 do begin
    Debug.Log('Waiting for web commands');
    sleep(1000);
  end;

end;

procedure TdmMotherShip.tcpAccept(Sender: TObject;
  ClientSocket: TCustomIpClient);
var
  proc: Tcmd_ProcessWebRequests;
begin
  proc := Tcmd_ProcessWebRequests.create;
  try
    proc.ClientSocketProxy := clientsocket;
    cmds.add(proc);
    proc.FireForget:= false;
    proc.RaiseExceptions := false;
    proc.start;
    proc.waitfor;
  finally
    cmds.Remove(proc);
    proc.free;
  end;
end;


procedure TdmMotherShip.tmMainThreadTimer(Sender: TObject);
begin
  try
    easyimage.GifQueue.ProcessAll;
  except
    on E: Exception do begin
      debug.log('Exception in GIF Conversion Queue Timer Event: '+E.message,'error');
    end;
  end;
end;

end.
