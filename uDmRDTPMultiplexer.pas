unit uDmRDTPMultiplexer;

interface

uses
{$IFDEF MSWINDOWS}
  ActiveX,
{$ENDIF}
  orderlyinit,
  SysUtils, Classes, sockfix, RDTPServerList, RDTPMultiplexerServer, applicationparams, rdtpprocessor,
  simpleabstractprivateserversocket, simplereliableudp, typex, skill, herro, debug;

type
  TIPClientLocal = TCustomIPClient;

  TdmRDTPMultiServer = class(TDataModule)
    procedure DataModuleCreate(Sender: TObject);
    procedure tcpAccept(Sender: TObject; ClientSocket: TIPClientLocal);
    procedure DataModuleDestroy(Sender: TObject);
  private


    FOnIdle: TRDTPIdleEvent;
    procedure udpAccept(endpoint: TReliableUDPEndpoint);

    { Private declarations }
  public
    tcp: TTCPServer;
    udp: TMultiplexedUDPServer;
    { Public declarations }
    property OnIdle: TRDTPIdleEvent read FOnIdle write FOnIdle;
    procedure CloseStuff;
  end;

var
  G_RDTP_DEFAULT_MULTIPLEXER_PORT: nativeint;
  dmRDTPMultiServer: TdmRDTPMultiServer;

implementation


{$R *.dfm}


procedure TdmRDTPMultiServer.CloseStuff;
begin
  tcp.active := false;
  udp.Active := false;
end;

procedure TdmRDTPMultiServer.DataModuleCreate(Sender: TObject);
var
  ap:  TAppParams;
  t: ni;
begin
  tcp := TTcpServer.create(self);

  ap := NeedAppParams;
  try
    tcp.localPort := ap.GetItemEx('MultiplexerPort', inttostr(G_RDTP_DEFAULT_MULTIPLEXER_PORT));
    tcp.ServerSocketThread.ThreadCacheSize := 99999;
    tcp.OnAccept := self.tcpAccept;
    tcp.active := true;
    tcp.BlockMode := TServerSocketBlockMode.bmThreadBlocking;

    udp := TMultiplexedUDPServer.create(self);
    udp.BindToport(ap.GetItemEx('MultiplexerPort', G_RDTP_DEFAULT_MULTIPLEXER_PORT));
    udp.OnDataAvailable := Self.udpAccept;
    udp.ThreadedEvent := true;

    rdtpservers.Lockread;
    try
      for t:= 0 to RDTPServers.Count-1 do begin
        herro.RegisterLocalSkill(RDTPServers.ServiceNames[t], 0, tcp.localPort, 'RDTP/RUDP');
        herro.RegisterLocalSkill(RDTPServers.ServiceNames[t], 0, tcp.localPort, 'RDTP/TCP');
      end;
    finally
      rdtpservers.UnlockRead;
    end;

    Debug.log('Listening on port '+tcp.localport);
  finally
    NoNeedAppParams(ap);
  end;
end;

procedure TdmRDTPMultiServer.DataModuleDestroy(Sender: TObject);
begin
  //
  tcp.Active := false;
end;

procedure TdmRDTPMultiServer.tcpAccept(Sender: TObject;
  ClientSocket: TIPClientLocal);
var
  proc: TRDTPMultiplexerProcessor;
  ac: TSimpleAbstractPrivateServerSocket;
begin
{$IFDEF MSWINDOWS}
  Coinitialize(nil);
{$ENDIF}
  Debug.Log('tcpAccept!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
  proc := TRDTPMultiplexerProcessor.create;
  try
    ac := TSimpleAbstractPrivateServerSocket.create;
    ac.socket := clientsocket;
    try
      proc.OnIdle := self.OnIdle;
      proc.Socket := ac;
      proc.ProcessMultiple;
    finally
      ac.free;
    end;
  finally
    proc.free;
  end;
{$IFDEF MSWINDOWS}
  COUnInitialize();
{$ENDIF}

end;

procedure TdmRDTPMultiServer.udpAccept(endpoint: TReliableUDPEndpoint);
var
  proc: TRDTPMultiplexerProcessor;
  ac: TSimpleReliablePrivateServerEndpoint;
begin

  proc := TRDTPMultiplexerProcessor.create;
  try
    ac := TSimpleReliablePrivateServerEndpoint.create;
    try
      while endpoint.connecting do begin
        sleep(100);
      end;
      ac.cli := endpoint;
      while ac.Connected do begin
        proc.OnIdle := self.OnIdle;
        proc.Socket := ac;
        proc.ProcessSingle;
      end;
    finally
      ac.free;
    end;
  finally
    proc.free;
  end;

end;

procedure oinit;
begin
  //
end;

procedure ofinal;
begin
//  if dmRDTPMultiServer <> nil then begin
//    dmRDTPMultiServer.free;
//    dmRDTPMultiServer := nil;
//  end;

end;

initialization
  G_RDTP_DEFAULT_MULTIPLEXER_PORT := 420;

  init.registerprocs('uDmRDTPMultiplexer', oinit, ofinal, 'CommandProcessor');

end.
