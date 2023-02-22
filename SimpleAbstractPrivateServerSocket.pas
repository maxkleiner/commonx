unit SimpleAbstractPrivateServerSocket;

interface

uses
  helpers_winsock, typex, simpleAbstractConnection, classes, better_sockets, sysutils;

type
  ESimpleAbstractPrivateServerSocketException = class(Exception);


  TSimpleAbstractPrivateServerSocket = class(TSimpleAbstractConnection)
  strict protected
    function DoCheckForData: boolean;override;
    function DoWaitForData(timeout: cardinal): boolean;override;
  public
    socket: TBetterCustomIPClient;//<----------------------------------------------
    function DoConnect: boolean; override;
    procedure DoDisconnect; override;
    function GetConnected: boolean;override;
    function DoReadData(buffer: pbyte; length: integer): integer;override;
    function DoSendData(buffer: pbyte; length: integer): integer;override;
    function GetUniqueID: Int64; override;


  end;


implementation

{ TSimpleAbstractPrivateServerSocket }

function TSimpleAbstractPrivateServerSocket.DoConnect: boolean;
begin
  raise ESimpleAbstractPrivateServerSocketException.create(classname+' represents a server socket, so calling Connect is irrelevant.');
end;

procedure TSimpleAbstractPrivateServerSocket.DoDisconnect;
begin
  inherited;
  socket.close;
end;

function TSimpleAbstractPrivateServerSocket.DoCheckForData: boolean;
begin
  raise ECritical.create('no implemented for this class');
end;

function TSimpleAbstractPrivateServerSocket.DoReadData(buffer: pbyte;
  length: integer): integer;
begin
  result := socket.ReceiveBuf(buffer[0], length);
end;

function TSimpleAbstractPrivateServerSocket.DoSendData(buffer: pbyte;
  length: integer): integer;
begin
  result := socket.SendBuf(buffer[0], length);
end;

function TSimpleAbstractPrivateServerSocket.GetConnected: boolean;
begin
  if socket = nil then
    exit(false);
  result := socket.Connected;
end;

function TSimpleAbstractPrivateServerSocket.GetUniqueID: Int64;
begin
  result := socket.Handle;
end;

function TSimpleAbstractPrivateServerSocket.DoWaitForData(
  timeout: cardinal): boolean;
begin
  result := socket.waitfordata(timeout);//  BetterWaitForData(Socket, timeout);
end;

end.
