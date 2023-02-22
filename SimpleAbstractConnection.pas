unit SimpleAbstractConnection;
{x$DEFINE VERBOSE COMMUNICATION LOG}
{$DEFINE READ_AHEAD}
{$I 'DelphiDefs.inc'}
{$DEFINE ALLOW_UTF8}

interface
uses
{$IFDEF NEED_FAKE_ANSISTRING}
  ios.stringx.iosansi,
{$ENDIF}
  SysUtils, systemx, betterobject, sharedobject, debug, numbers, typex, tickcount, signals, ringbuffer, commandprocessor, classes;

type
  ETransportError = class(Exception);


  Tcmd_ConnectionConnector = class;//forward
  TReadLnResult = record
    success: boolean;
    line: string;
  end;

//############################################################################
  TDebugEvent = procedure;
  TConnectionBufferState = record
    size: ni;
    consumed: ni;
    function PercentConsumed: single;
  end;
  TSimpleAbstractConnection = class(TSharedObject)
  //Description: This is the abstract base class that all types of connection
  //classes inherit from.  All connection classes have a hostname and enpoint,
  //and must implement the Connnect, Disconnect, Waitfordata, ReadData, and
  //Senddata procedures.
  private
    FOnData: TDebugEvent;
    FError: string;
    FTimeOut: cardinal;
    FdebugTag: string;
    temp: array[0..16383] of byte;
    FRequiresPolling: boolean;
    FPolledByReader: boolean;
    procedure SetHostName(const Value: string);
    function GetDebugTag: string;
    procedure SetDebugTag(const Value: string);




  protected
    rbReadAhead: TRingBuffer;

    FHostName: string;  //Identifies the computer to connected to
    FEndPoint: string;  //Identifies the PORT/SOCKET/PIPE or other kind of listener
    FBaudRate: ni;

    procedure DebugTagUpdated(s: string);virtual;
    function GetConnected: boolean;virtual;abstract;//<---------------------------------------------
    function DoReadData(buffer: pbyte; length: integer): integer;virtual;abstract;//<<------------------------------

    //IMPLMENTATION MUST BLOCK to send at LEAST 1 byte
    function DoSendData(buffer: pbyte; length: integer): integer;virtual;abstract;//<---------------------------------------------
    //IMPLMENTATION MUST BLOCK to send at LEAST 1 byte

    function GetBaudRate: integer;virtual;
    procedure SetBaudRate(const Value: integer);virtual;
    function HasLeftOvers: boolean;inline;
    function HasLeftOverSpace: boolean;inline;
    procedure SetEndPOint(const Value: string);virtual;
    function GetISDataAvailable: boolean;virtual;
  strict protected
    tmLastDebugTime: ticker;
{$IFDEF ALLOW_UTF8}
    FFailedReadLn: Tarray<byte>;
{$ELSE}
    FFailedReadLn: ansistring;
{$ENDIF}
    function DoCheckForData: boolean;virtual;abstract;
    function DoWaitForData(timeout: cardinal): boolean;virtual;abstract;//<---------------------------------------------

    procedure DebugIfTime;
    function BufferStatusString: string;
    property PolledByReader: boolean read FPolledByReader write FPolledByReader;
    procedure UpdateBufferStatus;
    function DoConnect: boolean; virtual;abstract;//<---------------------------------------------
    procedure DoDisconnect; virtual;abstract;//<---------------------------------------------

  public
    lastusage: ticker;
    MaxConnectionTries: ni;
    send_eol_cr: boolean;
    send_eol_lf: boolean;
    readln_eol: ansichar;
    readln_ignore: ansichar;
    Disconnecting: boolean;
    bufferState: TConnectionBufferState;
    evData: TSignal;
    constructor Create; override;
    destructor Destroy;override;
    property HostName: string read FHostName write SetHostName;
    property EndPoint: string read FEndPoint write SetEndPOint;

    function Connect: boolean;
    procedure Disconnect;
    function CheckForData: boolean;



    function SendData(buffer: pbyte; length: integer; bSendAll: boolean = true): integer;
    function WaitForData(timeout: cardinal): boolean;



    property Connected: boolean read GetConnected;

    procedure Flush;virtual;
    function ReadData(buffer: pbyte; length: ni; bReadAll: boolean; iTimeOut: ticker = 0): ni;overload;//override DoReadDAta
    function ReadData(buffer: pbyte; length: ni): ni;overload;
    function GuaranteeReadData(buffer: pbyte; length: ni; iTimeOut: ticker; bThrowExceptions: boolean = true): ni;
    procedure GuaranteeeSendata(buffer: pbyte; length: ni; iTimeOut: ticker);
    procedure GuaranteeSendStream(s: TStream);


    property OnData: TDebugEvent read FOnData write FOnData;
    property Error: string read FError write FError;
    function CheckConnected: boolean;virtual;

    property BaudRate: integer read GetBaudRate write SetBaudRate;
    property Timeout: cardinal read FTimeOut write FTimeout;
    function IsConnected: boolean;
    property DebugTag: string read GetDebugTag write SetDebugTag;
    property RequiresPolling: boolean read FRequiresPolling write FRequiresPolling;

    function BeginConnect: Tcmd_ConnectionConnector;
    function EndConnect(c:Tcmd_ConnectionConnector): boolean;
    property IsDataAvailable: boolean read GetISDataAvailable;
    function CheckConnectedOrConnect: boolean;
    function ReadLn(out sLine: string; iTimeout: nativeint): boolean;
    procedure SendLn(sLine: string);
    function GetUniqueID: int64;virtual;abstract;
  end;


  Tcmd_ConnectionConnector = class(TCommand)
  public
    c: TSimpleAbstractConnection;
    Cresult: boolean;
    procedure InitExpense;override;
    procedure DoExecute;override;
  end;






implementation

function TSimpleAbstractConnection.BeginConnect: Tcmd_ConnectionConnector;
begin
  result := Tcmd_ConnectionConnector.create;
  result.c := self;
  result.start;

end;

function TSimpleAbstractConnection.BufferStatusString: string;
begin
  result := 'leftOvers (ReadAhead): '+rbReadAhead.AvailableDataSize.tostring;
end;

function TSimpleAbstractConnection.CheckConnected: boolean;
begin
  try
    result := connected;
    if not connected then result := connect;
  except
    result := false;
  end;

end;


function TSimpleAbstractConnection.CheckConnectedOrConnect: boolean;
begin
  result := connected;
  if not result then
    result := connect;
end;

function TSimpleAbstractConnection.CheckForData: boolean;
begin
  result := false;
  Lock;
  try
    if DoCheckForData then begin
      signal(evData, true);
      result := true;
    end;
  finally
    Unlock;
  end;
end;

function TSimpleAbstractConnection.Connect: boolean;
var tmStart: ticker;
begin
  Disconnecting := false;

  tmStart := getTicker;
  var tries := 0;
  repeat
    result := DoConnect;

    if not result then
      sleep(random(500));

    inc(tries);
  until result or (gettimesince(tmStart) > 8000) or (tries>MaxConnectionTries);


end;

constructor TSimpleAbstractConnection.Create;
begin
  inherited;
  readln_eol := #13;
  readln_ignore := #10;
  FHostName := '';
  FEndPoint := '';
  FOnData := nil;
  FError := '';
  evData := TSignal.create;
  rbReadAhead := TRingBuffer.create;
  rbReadAhead.Size := 65536;
  send_eol_cr := true;
  send_eol_lf := true;
  MaxConnectionTries := 8;

end;


procedure TSimpleAbstractConnection.DebugIfTime;
begin
  if gettimesince(tmLastDebugTime) > 1000 then begin
//    debug.log(self.BufferStatusString);
    tmLastDebugTime := getticker;
  end;
end;

procedure TSimpleAbstractConnection.DebugTagUpdated(s: string);
begin
  //no implementation required
end;

destructor TSimpleAbstractConnection.Destroy;
begin
  rbReadAhead.free;
  rbReadAhead := nil;
  evData.free;
  inherited;
end;

procedure TSimpleAbstractConnection.Disconnect;
begin
  Disconnecting := true;
  DoDisconnect;
end;

function TSimpleAbstractConnection.EndConnect(
  c: Tcmd_ConnectionConnector): boolean;
begin
  c.WaitFor;
  result := c.cresult;
  c.free;
  c := nil;

end;

procedure TSimpleAbstractConnection.Flush;
begin
  //no implementation required
end;

function TSimpleAbstractConnection.GetBaudRate: integer;
begin
  //no implementation required
  result := FBaudRate;
end;

function TSimpleAbstractConnection.GetDebugTag: string;
begin
  Lock;
  try
    result := FDebugTag;
  finally
    Unlock;
  end;
end;

function TSimpleAbstractConnection.GetISDataAvailable: boolean;
begin
  if PolledByReader then
    CheckForData;
  result := evData.IsSignaled;
end;



procedure TSimpleAbstractConnection.GuaranteeeSendata(buffer: pbyte; length: ni;
  iTimeOut: ticker);
var
  pp: pbyte;
  togo: ni;
  ijust: ni;
  tmStart: ticker;
begin
  pp := buffer;
  togo := length;
  tmStart := getticker;
  while togo > 0 do begin
    ijust := 0;
    ijust:= SendData(pp, togo);
    if iJust <=0 then begin
      Disconnect;
      raise ETransportError.Create(classname+' sent zero bytes!**');
    end;
    dec(togo, ijust);
    inc(pp, ijust);
    if ijust > 0 then begin
      tmStart := getticker;
    end;
    if (gettimesince(tmStart) > iTimeOut) then begin
      Disconnect;
      raise ETransportError.Create(classname+' timeout during guaranteed write.');
    end;
  end;
end;

function TSimpleAbstractConnection.GuaranteeReadData(buffer: pbyte;
  length: ni; iTimeOut: ticker; bThrowExceptions: boolean = true): ni;
var
  pp: pbyte;
  togo: ni;
  justread: ni;
  tmStart: ticker;
begin
  pp := buffer;
  togo := length;
  tmStart := getticker;
  result := 0;
  while togo > 0 do begin
    justread := 0;
    if WaitforData(iTimeout) then begin
      justread := ReadData(pp, togo);
      if justread <=0 then begin
        Disconnect;
        if bThrowExceptions then
          raise ETransportError.Create('socket disconnected, got '+inttostr(result)+' of '+inttostr(length)+' bytes requested of guarantee');
        exit(0);
      end;
    end;

    dec(togo, justread);
    inc(pp, justread);
    if justread > 0 then begin
      tmStart := getticker;
    end;
    if (iTimeOut > 0) and (gettimesince(tmStart) > iTimeOut) then begin
      Disconnect;
      raise ETransportError.Create(classname+' timeout during guaranteed read.');
    end;
    inc(result, justread);
  end;
  result := length;
end;

procedure TSimpleAbstractConnection.GuaranteeSendStream(s: TStream);
var
  temp: array of byte;
begin
  setlength(temp, 65535);
  var cx := s.Size-s.Position;
  while cx > 0 do begin
    var iTo := lesserof(cx, 65536);
    var iJust := s.Read(temp[0], iTo);
    if iJust = 0 then
      raise ECritical.Create('read 0 bytes from stream');
    self.GuaranteeeSendata(@temp[0], iJust, 16000);
  end;


end;

function TSimpleAbstractConnection.HasLeftOvers: boolean;
begin
  result := rbReadAhead.IsDataAvailable;
end;

function TSimpleAbstractConnection.HasLeftOverSpace: boolean;
begin
  result := rbReadAhead.SpaceAvailable > 0;
end;

function TSimpleAbstractConnection.IsConnected: boolean;
begin
  result := GetConnected;
end;

function TSimpleAbstractConnection.ReadData(buffer: pbyte; length: ni): ni;
var
  iJustread, iToRead: nativeint;
  tempread: ni;
begin
  result := 0;
  //if there are leftovers
  DebugIfTime;
  If HasLeftOvers then begin
    result := rbReadAhead.GetAvailableChunk(buffer, length);
    UpdateBufferStatus;
    exit;
  end;

  //if we didn't read anything
  //OR we didn't read enough (and the readall flag is set)
  if (result = 0) then begin
    //move stuff to temp
{$IFDEF READ_AHEAD}
    itoRead := lesserof(sizeof(temp), rbReadAhead.BufferSpaceAvailable);
{$ELSE}
    itoRead := lesserof(sizeof(temp), length);
{$ENDIF}
    tempread := doReadData(@temp[0], iToRead);
    if tempread > 0 then begin
      //pull what we need out of temp array
      result := lesserof(tempread, length);
      MoveMem32(buffer, @temp[0], result);
      //save whatever is left
      var tobuffer := tempread-result;
      if tobuffer > 0 then begin
        rbReadAhead.BufferData(@temp[result], tobuffer);
      end;
      UpdateBufferStatus;
    end
    else
      exit(tempread);
  end

  {$IFDEF VERBOSE COMMUNICATION LOG}
  Debug.Consolelog('Just Read '+inttostr(result)+' of '+inttostr(length)+' bytes: '+memorytohex(buffer, result));
  {$ENDIF}

end;

function TSimpleAbstractConnection.ReadData(buffer: pbyte; length: ni;
  bReadAll: boolean; iTimeOut: ticker = 0): ni;
begin
  if bReadAll then
    result := GuaranteeReadData(buffer, length, iTimeOut)
  else
    result := readData(buffer, length);
end;



function TSimpleAbstractConnection.SendData(buffer: pbyte; length: integer; bSendAll: boolean = true): integer;
var
  iSent: int64;
  iToSend: int64;
  iJustSent: int64;
begin
  iSent := 0;
  while iSent < length do begin
    iToSend := length-isent;
    ijustSent := DoSendData(@buffer[iSent], length-iSent);
    if (iJustSent<=0)(* and (not Connected)*) then
      raise ETransportError.Create('Connection dropped during send.');
    inc(iSent, iJustSent);
    if not bSendAll then break;
  end;

  result := iSent;

  {$IFDEF VERBOSE COMMUNICATION LOG}
  Debug.log(self,'Just Sent '+inttostr(result)+' of '+inttostr(length)+' bytes: '+memorytohex(buffer, result),'');
  {$ENDIF}

end;

procedure TSimpleAbstractConnection.SetBaudRate(const Value: integer);
begin

  //raise Exception.create('unimplemented');
  FBaudRate := value;

end;

procedure TSimpleAbstractConnection.SetDebugTag(const Value: string);
begin
  Lock;
  try
    FDebugTag := value;
    DebugTagUpdated(value);
  finally
    Unlock;
  end;
end;

procedure TSimpleAbstractConnection.SetEndPOint(const Value: string);
begin
  FEndPoint := Value;
end;

procedure TSimpleAbstractConnection.SetHostName(const Value: string);
begin
  FHostName := Value;
end;

procedure TSimpleAbstractConnection.UpdateBufferStatus;
begin
  bufferState.size := rbReadAhead.Size;
  bufferstate.consumed := rbReadAhead.DataAvailable;
end;

function TSimpleAbstractConnection.WaitForData(timeout: cardinal): boolean;
begin
  if HasLeftOvers then begin
    result := true;
  end else
    result := DoWaitForData(timeout);
end;

{ Tcmd_ConnectionConnector }

procedure Tcmd_ConnectionConnector.DoExecute;
begin
  c.Connect;
end;

procedure Tcmd_ConnectionConnector.InitExpense;
begin
  CPuExpense := 0;
end;

{ TConnectionBufferState }

function TConnectionBufferState.PercentConsumed: single;
begin
  if size = 0 then
    exit(1.0);
  exit(consumed/size);
end;

function TSimpleAbstractConnection.ReadLn(out sLine: string; iTimeout: nativeint): boolean;

var
{$IFDEF ALLOW_UTF8}
  byt: TArray<byte>;

{$ELSE}
  ansi: ansistring;

{$endif}
begin
  result := false;
  sline := '';
{$IFDEF ALLOW_UTF8}
  byt := FFailedReadLn;
  setlength(FFailedReadln,0);
{$ELSE}
  ansi := FFailedReadln;
  FFailedReadln := '';
{$ENDIF}

  while true do begin
    if WaitforData(iTimeout) then begin
      var b: byte;
      if ReadData(@b, 1) = 0 then
        raise ETransportError.create('failed to read byte during ReadLn.  Connection dropped.');
//      if b <> readln_ignore then begin
        if b=ord(readln_eol) then begin
{$IFDEF ALLOW_UTF8}
          byt := systemx.ByteRemove(byt,ord(readln_ignore));
          try
            sline := TEncoding.UTF8.GetString(byt);
          except
            sline := TEncoding.ANSI.GetString(byt);
            Debug.Log('UTF Dencode Error! String Treated as ANSI instead: '+sline);
          end;
{$ELSE}
          sline := StringReplace(string(ansi), readln_ignore, '', [rfReplaceAll]);
{$ENDIF}

          exit(true);
        end;
{$IFDEF ALLOW_UTF8}
        setlength(byt, length(byt)+1);
        byt[high(byt)] := b;
{$ELSE}
        ansi := ansi + ansichar(b);
{$ENDIF}
//      end;
    end else begin
{$IFDEF ALLOW_UTF8}
      FFailedReadLn := byt;
{$ELSE}
      FFailedReadLn := ansi;
{$ENDIF}

      //if we call readln but fail to get even a PARTIAL line, then the connection
      //dropped presumably because we called WaitForData before this
{$IFDEF ALLOW_UTF8}
      if length(FFailedReadLn) = 0  then
        raise ETransportError.create('connection broken during readln()');
{$ELSE}
      if FFailedReadLn = '' then
        raise ETransportError.create('connection broken during readln()');
{$ENDIF}
      exit(false);
    end;

  end;

end;

procedure TSimpleAbstractConnection.SendLn(sLine: string);
var
  eolstr: ansistring;
begin
  eolstr := '';
  if send_eol_cr then
    eolstr := #13;
  if send_eol_lf then
    eolstr := eolstr+#10;
{$IFDEF ALLOW_UTF8}
  var bytes := TEncoding.UTF8.GetBytes(sLine+string(eolstr));
  SendData(@bytes[0], length(bytes), true);
{$ELSE}
  var ansi := ansistring(sLine)+eolstr;

  {$IFDEF NEED_FAKE_ANSISTRING}
    SendData(ansi.addrof[strz], length(ansi), true);
  {$ELSE}
    SendData(@ansi[strz],       length(ansi), true);
  {$ENDIF}
{$ENDIF}
end;


end.
