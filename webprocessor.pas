unit WebProcessor;
{$define RETAIN_HTTP_CLIENTS}
{x$define ALWAYS_CLOSE}
interface

uses betterobject, SharedObject, requestinfo, tickcount,beeper, numbers,
    better_sockets, helpers.sockets, stringx, sockfix, commandicons,hitclient,
    IPClientWrapper, httpclient, systemx, typex, commandprocessor, helpers_stream,
    MotherShipWebServer, classes, sysutils, ExceptionsX, windows, webstring, stringx.ansi, webfunctions;

const
  SHORT_SOCKET_TIMEOUT =15000;
  LONG_SOCKET_TIMEOUT = 300000;

CMD_ICON_WWW: TCommandIcon = (BitDepth: 32; RDepth:8;GDepth:8;BDepth:8;ADepth:8;Height:32;Width:32;
 data:
(
($00000000,$00000000,$02000000,$06000000,$01000000,$00000000,$00000000,$00000000,$04000000,$05000000,$11000000,$59010000,$97010001,$C4020001,$E3020001,$FB020001,$F5020001,$D9020001,$B7020001,$85010001,$44010000,$04000000,$00000000,$00000000,$00000000,$05000000,$04000000,$00000000,$00000000,$00000000,$01000000,$04000000),
($00000000,$03000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$06000000,$2C000000,$97010001,$F2020001,$FF020001,$FF020001,$FF020001,$F4020001,$E5020001,$E9020001,$FB020001,$FF020001,$FF020001,$FF020001,$DC020001,$71010000,$0C000000,$08000000,$07000000,$00000000,$00000000,$00000000,$02000000,$0A000000,$02000000),
($02000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$0D000000,$86010001,$F6020001,$FF020001,$F2020001,$A3010001,$61010000,$26000000,$00000000,$00000000,$00000000,$0D000000,$BC020001,$FF020001,$FF020001,$FF020001,$FF020001,$DE020001,$50010000,$00000000,$00000000,$00000000,$02000000,$0A000000,$03000000,$00000000),
($06000000,$02000000,$00000000,$00000000,$00000000,$20000000,$C6020001,$FF020001,$F3020001,$84010001,$15000000,$0A000000,$05000000,$00000000,$00000000,$00000000,$04000000,$0A000000,$7E010001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FE020001,$86010001,$03000000,$02000000,$0A000000,$03000000,$00000000,$00000000),
($01000000,$00000000,$00000000,$00000000,$25000000,$DB020001,$FF020001,$DF020001,$28000000,$01000000,$0A000000,$05000000,$00000000,$00000000,$00000000,$04000000,$0A000000,$02000000,$32000000,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$A1010001,$0E000000,$03000000,$00000000,$00000000,$00000000),
($00000000,$00000000,$00000000,$18000000,$D6020001,$FF020001,$FF020001,$F7020001,$2D000000,$0A000000,$05000000,$00000000,$00000000,$00000000,$04000000,$0A000000,$02000000,$00000000,$00000000,$A3010001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$92010001,$00000000,$00000000,$00000000,$02000000),
($00000000,$00000000,$07000000,$AF010001,$FF020001,$FF020001,$FF020001,$FF020001,$A9010001,$05000000,$00000000,$00000000,$00000000,$04000000,$0A000000,$01000000,$00000000,$00000000,$00000000,$0B000000,$74010000,$F5020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$59010000,$00000000,$05000000,$07000000),
($00000000,$06000000,$5F010000,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$E8020001,$00000000,$00000000,$00000000,$04000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$38010000,$E0020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$E9020001,$1B000000,$0A000000,$01000000),
($04000000,$0F000000,$DB020001,$FF020001,$FF020001,$FF020001,$FF020001,$FE020001,$93010001,$00000000,$00000000,$04000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$00000000,$00000000,$1D000000,$C3020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$91010001,$01000000,$00000000),
($05000000,$5A010000,$FF020001,$FF020001,$FF020001,$FE020001,$AE010001,$3C010000,$00000000,$00000000,$04000000,$0A000000,$01000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$00000000,$00000000,$02000000,$0A000000,$07000000,$C4020001,$FF020001,$D0020001,$5A010000,$F5020001,$F0020001,$11000000,$00000000),
($00000000,$B4010001,$FF020001,$FF020001,$FF020001,$BA020001,$00000000,$00000000,$00000000,$04000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$00000000,$00000000,$02000000,$0A000000,$03000000,$00000000,$59010000,$F8020001,$1A000000,$0A000000,$9D010001,$FF020001,$66010000,$00000000),
($0F000000,$F8020001,$FF020001,$FF020001,$FF020001,$A5010001,$00000000,$00000000,$04000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$00000000,$00000000,$02000000,$0A000000,$03000000,$00000000,$00000000,$16000000,$F1020001,$0A000000,$01000000,$49010000,$FF020001,$AE010001,$05000000),
($42010000,$FF020001,$FF020001,$FF020001,$FF020001,$9C010001,$00000000,$04000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$0F000000,$00000000,$00000000,$02000000,$0A000000,$03000000,$00000000,$00000000,$00000000,$05000000,$E2020001,$2C000000,$00000000,$0D000000,$FA020001,$E5020001,$05000000),
($68010000,$FF020001,$FF020001,$FF020001,$FF020001,$C4020001,$0B000000,$0A000000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$BE020001,$8E010001,$12000000,$0A000000,$03000000,$00000000,$00000000,$00000000,$05000000,$15000000,$EF020001,$8B010001,$00000000,$01000000,$D0020001,$FF020001,$15000000),
($7F010001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$72010000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$00000000,$95010001,$FF020001,$E2020001,$56010000,$00000000,$00000000,$00000000,$05000000,$0A000000,$88010001,$FF020001,$FA020001,$69010000,$09000000,$B9010001,$FF020001,$32000000),
($84010001,$FF020001,$FF020001,$FF020001,$F8020001,$8C010001,$09000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$00000000,$00000000,$67010000,$FF020001,$FF020001,$FF020001,$AF010001,$22000000,$05000000,$0A000000,$35000000,$FD020001,$FF020001,$FF020001,$FE020001,$54010000,$B0010001,$FF020001,$37010000),
($79010001,$FF020001,$FD020001,$B0010001,$34000000,$02000000,$00000000,$00000000,$00000000,$08000000,$07000000,$00000000,$00000000,$00000000,$02000000,$40000000,$FF020001,$FF020001,$FF020001,$FF020001,$F1020001,$78010000,$07000000,$03000000,$6B010000,$EC020001,$FF020001,$FF020001,$D4020001,$BE020001,$FF020001,$2E000000),
($60010000,$FF020001,$9D010001,$0A000000,$02000000,$00000000,$01000000,$09000000,$08000000,$07000000,$00000000,$00000000,$00000000,$02000000,$0A000000,$10000000,$FB020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$CC020001,$39010000,$01000000,$23000000,$A7010001,$FE020001,$FF020001,$F6020001,$FC020001,$11000000),
($37000000,$FF020001,$BE020001,$02000000,$00000000,$5C010000,$E9020001,$FD020001,$9B010001,$04000000,$00000000,$00000000,$02000000,$0A000000,$03000000,$00000000,$CC020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FC020001,$95010001,$18000000,$00000000,$49010000,$D9020001,$FF020001,$D7020001,$02000000),
($0A000000,$EF020001,$F5020001,$0F000000,$24000000,$F5020001,$FF020001,$FF020001,$FF020001,$A0010001,$0B000000,$02000000,$0A000000,$03000000,$00000000,$00000000,$9E010001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$E3020001,$57010000,$00000000,$0E000000,$8B010001,$94010001,$00000000),
($06000000,$A2010001,$FF020001,$66010000,$9C010001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$DF020001,$8E010001,$35000000,$00000000,$00000000,$00000000,$71010000,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$B4010001,$2D000000,$02000000,$03000000,$00000000),
($01000000,$42010000,$FF020001,$DC020001,$F8020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$44010000,$00000000,$00000000,$05000000,$4A010000,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$F3020001,$76010001,$07000000,$00000000),
($00000000,$01000000,$C1020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$92010001,$00000000,$00000000,$05000000,$0A000000,$14000000,$FE020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$CB020001,$27000000),
($00000000,$00000000,$3D000000,$FB020001,$FF020001,$FF020001,$FF020001,$FF020001,$FE020001,$AC010001,$52010000,$00000000,$00000000,$05000000,$0A000000,$01000000,$00000000,$D7020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FA020001,$D3020001,$A3010001,$73010000,$43010000,$15000000,$06000000),
($00000000,$08000000,$07000000,$81010001,$FF020001,$FF020001,$FF020001,$FF020001,$DC020001,$00000000,$00000000,$00000000,$05000000,$0A000000,$01000000,$00000000,$00000000,$A7010001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$7A010001,$00000000,$00000000,$00000000,$06000000,$09000000,$00000000),
($05000000,$07000000,$00000000,$04000000,$AF010001,$FF020001,$FF020001,$FF020001,$FD020001,$24000000,$00000000,$05000000,$0A000000,$01000000,$00000000,$00000000,$01000000,$7C010001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$FF020001,$F3020001,$2B000000,$00000000,$06000000,$09000000,$00000000,$00000000),
($04000000,$00000000,$00000000,$00000000,$0C000000,$B6010001,$FF020001,$FF020001,$FB020001,$4B010000,$05000000,$0A000000,$01000000,$00000000,$00000000,$01000000,$09000000,$50010000,$FF020001,$FF020001,$FF020001,$E6020001,$A1010001,$FF020001,$FF020001,$FF020001,$C7020001,$0C000000,$09000000,$00000000,$00000000,$00000000),
($00000000,$00000000,$00000000,$02000000,$0A000000,$09000000,$8F010001,$FD020001,$FF020001,$BF020001,$4F010000,$03000000,$00000000,$00000000,$01000000,$09000000,$06000000,$1C000000,$FF020001,$FF020001,$FF020001,$62010000,$0D000000,$D2020001,$FF020001,$FF020001,$FF020001,$83010001,$00000000,$00000000,$00000000,$00000000),
($00000000,$00000000,$02000000,$0A000000,$03000000,$00000000,$00000000,$48010000,$D6020001,$FF020001,$FF020001,$DC020001,$91010001,$5D010000,$42010000,$33000000,$15000000,$00000000,$E2020001,$FF020001,$B6010001,$02000000,$00000000,$36000000,$F9020001,$FF020001,$FF020001,$F8020001,$36000000,$00000000,$01000000,$06000000),
($00000000,$02000000,$0A000000,$03000000,$00000000,$00000000,$00000000,$05000000,$0F000000,$61010000,$C3020001,$FD020001,$FF020001,$FF020001,$FF020001,$FF020001,$8E010001,$00000000,$B0010001,$F1020001,$24000000,$00000000,$01000000,$00000000,$80010001,$FF020001,$FF020001,$FF020001,$C0020001,$01000000,$09000000,$04000000),
($01000000,$0A000000,$03000000,$00000000,$00000000,$00000000,$05000000,$0A000000,$01000000,$00000000,$00000000,$21000000,$68010000,$90010001,$AB010001,$B8020001,$7F010001,$02000000,$87010001,$74010000,$00000000,$00000000,$00000000,$06000000,$0E000000,$C7020001,$FF020001,$FF020001,$E3020001,$09000000,$05000000,$00000000),
($04000000,$02000000,$00000000,$00000000,$00000000,$02000000,$07000000,$01000000,$00000000,$00000000,$00000000,$05000000,$05000000,$00000000,$00000000,$00000000,$01000000,$07000000,$30000000,$05000000,$00000000,$00000000,$03000000,$06000000,$00000000,$27000000,$D7020001,$FC020001,$7C010001,$04000000,$00000000,$00000000)
 ));
type
  TRequestState = (rqsInit, rqsRegister, rqsExecute, rqsClientExecute, rqsInheritedExecute, rqsReadHeader, rqsReadBody, rqsDispatch, rqsScript, rqsWriteHeader, rqsWriteBody, rqsClosed);




  Tcmd_ProcessWebRequests = class(TCommand)
  private
    { Private declarations }
    FRequestState: TRequestState;

    FCLientSocket: TCustomIPclient;

    FRQINfo: TRequestInfo;
    msIncoming: TMemoryStream;
    FSendImmediate: boolean;
    FPreload: string;
    FLeftOvers: PByte;
    FLeftOverLength: integer;
    clientip: string;
    procedure SaveLeftOvers(p: Pbyte; len: integer);
    function GetStateString: string;
    procedure SetRequestState(const Value: TRequestState);
    function GetRequestState: TRequestState;
    function GetSocketProxy: TCustomIPClient;
    procedure SetSocketProxy(const Value: TCustomIPClient);

  protected

    procedure ReadRequest;//
    procedure ReadAvailable(bHeaderComplete:boolean);//
    procedure WriteResponse;//
    procedure WriteHeader;//
    procedure WriteContent;//
    procedure WriteChunk;//
    procedure WriteResponseData(s: ansistring; iLength: integer = -1);
    procedure DoExecute; override;
  public
    procedure Init;override;
    constructor Create;reintroduce;virtual;
    destructor Destroy; override;
    procedure Process(sPreBuf: string = '');
    procedure Process2(sPreBuf: string = '');
    procedure InitExpense; override;
    property Sendimmediate: boolean read FSendImmediate write FSendimmediate;
    property RequestState: TRequestState read GetRequestState write SetRequestState;
    property StateString: string read GetStateString;

    property ClientSocketProxy: TCustomIPClient read GetSocketProxy write SetSocketProxy;
    property ClientSocket: TCustomIPClient read FCLIentSocket write FClientSocket;

    property rqInfo: TRequestInfo read FRQINfo;

    function ReceiveText: string;
    procedure CheckConnected;


  end;


implementation

uses debug;



{ Tcmd_ProcessWebRequests }
procedure Tcmd_ProcessWebRequests.CheckConnected;
begin
  IF NOT FCLientSocket.Connected THEN
    raise ESocketError.Create('client dropped');
//  FClientSocket.checkconnected;
end;


constructor Tcmd_ProcessWebRequests.create;
begin
  inherited;
  self.FRequestState := rqsInit;


//  self.FCLientSocket := TIPClient.create;




end;

destructor Tcmd_ProcessWebRequests.Destroy;
begin
  FrqInfo.free;
  FrqInfo := nil;
  inherited;


//  self.FCLientSocket.free;
//  self.FCLientSocket := nil;



end;


procedure Tcmd_ProcessWebRequests.DoExecute;
begin
  inherited;
  Process;
end;

function Tcmd_ProcessWebRequests.GetRequestState: TRequestState;
begin
  result := rqsInit;
end;


function Tcmd_ProcessWebRequests.GetSocketProxy: TCustomIPClient;
begin
  result := self.ClientSocket;
end;


function Tcmd_ProcessWebRequests.GetStateString: string;
begin
  result := '';
  uniqueString(result);
end;

procedure Tcmd_ProcessWebRequests.Init;
begin
  inherited;
  Icon := @CMD_ICON_WWW;
end;

procedure Tcmd_ProcessWebRequests.InitExpense;
begin
  inherited;
  cpuexpense := 0;
end;

procedure Tcmd_ProcessWebRequests.Process2(sPreBuf: string = '');
//This is the main thread execution code.
var
  tm1, tm2: cardinal;
begin
  RequestState := rqsClientExecute;
//  FreeOnTerminate := true;
//  WebThreadMan.RegisterThread(self);
  try
    try
      try
        StepCount := 3;
        Step := 0;
        //Check to see if the Server is stopped, if so, exit immediately.
        if not (WebServer.State = wssRunning) then
          exit;


//        self.ClientSocket.TimeOut := SHORT_SOCKET_TIMEOUT;
        //Read the stuff
//        debug.log('About to read request',self.classname);
        FPreload := sPreBuf;
//        beeper.beep(1000,50);
        ReadRequest;
//        beeper.beep(500,50);
//        debug.log('Request read:'+rQInfo.Request.Document,self.classname);
//        self.CLientSocket.TimeOut := LONG_SOCKET_TIMEOUT;

        //http crap
        rqInfo.Request.Default('connection', 'close');
        FRqInfo.HTTPClient.keepconnectionalive := lowercase(rqInfo.request['connection']) = 'keep-alive';


        //Dispatch the request
        RequestState := rqsDispatch;
        Step := 1;
//        debug.log('Dispatching:'+rQInfo.request.document,self.classname);
        var tm := GetTicker;
        var tmIn:= now();
        clientip := self.FCLientSocket.remotehost;
        var cip := clientip;
        var sjunk:= '';
        if rqInfo.request.hasparam('x-forwarded-for') then
          SplitString(rqInfo.request['x-forwarded-for'],':',cip,sJunk);
        if cip <> clientip then begin
          clientip := cip;
          FRQINfo.Request.ClientIP := cip;
        end;

        WebServer.DispatchWebRequest(rqInfo);
        var tmFin := GetTicker;
        var tmDif := gettimesince(tmFin,tm);
        if projcode <> '' then begin
                  //RecordHit(ip: string; ts: TDateTime; runtime: int64; page: string; url: string; useragent: string; size: UInt64; referer: string);

          var a := rqInfo.request.useragent;
          var r := rqInfo.request.referer;
          var m := rqInfo.request.method;
          var d := rqInfo.request.document;
          var f := rqInfo.request.fullurl;

          HitClient.RecordHit(m, cip  ,tmIn, tmDif, d, f, a, greaterof(0,rqInfo.response.ContentLength), r);

        end;

        Step := 2;
//        debug.log('Dispatched:'+rQInfo.request.document,self.classname);
//        self.ClientSocket.TimeOut := SHORT_SOCKET_TIMEOUT;
      except
        //If expception was not handled by the more-elegant exception handlers
        //underneath, then generate a simple plain-text exception message.
        on E: ESocketError do begin
          debug.log('socket ended', 'error');
          rqinfo.Response.Ignore := true;
        end;
        on E: Exception do begin
          debug.log('Exception caught in Webprocessor.Process2: '+e.message, 'error');
          rqInfo.response.resultcode := 500;
          rqInfo.response.Content.text := '<HTML>'+E.Message+'</HTML>';;
          rqINfo.response.contentlength := -1;
        end;
      end;

      //Write the response
      tm1 := GetTickCount;

      if rqInfo.response.contenttype = 'text/html' then begin
        if rqInfo.request.hasparam('blend') then begin
          rqInfo.response.content.Insert(0, '<meta content="blendTrans(duration=0.25)" http-equiv="Page-Enter">');
          rqInfo.response.content.Insert(0, '<meta content="blendTrans(duration=0.25)" http-equiv="Page-Exit">');
        end;
      end;


      //Set a content length for the response if not explicitly set... based on the length of the response content.
      if rqInfo.Response.ContentLength = -1 then
        rqInfo.Response.ContentLength := length(rqInfo.response.content.text);

      if rqInfo.request.UserAgent = 'Charlotte/0.9' then begin
        rqInfo.Response.ContentLength := rqInfo.Response.ContentLength+1;
      end;


      if not rqInfo.response.ignore then begin
//        debug.log('Writing Response:'+rQInfo.request.document,self.classname);
        //Write the response down the socket.
        WriteResponse;

//        debug.log('Response written:'+rQInfo.request.document,self.classname);
      end;

      //Report this thread as closed
      RequestState := rqsClosed;

      tm2 := GetTickCount;
      rqInfo.response.SendTime := tm2-tm1;

      //Call hook if used, (not used in produciton)
      if assigned(rqInfo.response.OnResponseSent) then
        rqInfo.response.OnResponseSent(rqInfo);

      debug.log(rqInfo.Request.Command+' '+rqInfo.Request.Document+' '+inttostr(rqInfo.Response.resultcode)+' '+rqInfo.response.Message,'RQINFO');

      Step := 3;

    //Log exceptions if not handled elegantly
    except
      on E: Exception do begin
        rqInfo.response.ResultCode := 500;
        rqInfo.response.message := e.message;
        debug.log('**'+rqInfo.Request.Command+' '+rqInfo.Request.Document+' '+inttostr(rqInfo.Response.resultcode)+' '+rqInfo.response.Message,'RQINFO');
      end;
    end;
  finally

    {$IFDEF DELAY}
    //Delay for 5 seconds (to slow
//    if not Terminated then
//      sleep(5000);
    {$ENDIF}

    try
      if (not rqInfo.request.HasParam('connection'))
      or (lowercase(rqINfo.request['connection']) <> 'keep-alive')
      or (rqINfo.Response.Connection = rqcClose)
//      or true
      then begin
        ClientSocket.Disconnect;

        debug.log('Socket closed:'+rQInfo.request.document,self.classname);
      end;
    except
    end;
  end;
end;
procedure Tcmd_ProcessWebRequests.Process(sPreBuf: string);
var
  bKeepAlive: boolean;
  s: string;
  htpKeep: THTTPClient;
  requests_this_connection: ni;
begin
  requests_this_connection := 0;
  htpKeep := nil;
  try
    //! Lets stick a counter in here and count how many times we actually attempt to process something, should be 25 times
    WebServer.HitAccept;
    bKeepAlive := false;
    FRqInfo := TRequestInfo.create;
    FRqInfo.request.document := 'init';
    debug.log('request init');
    try
//      debug.log('About to process2: '+FRqInfo.request.document);
      inc(requests_this_connection);
      Process2(sPreBuf);

      bKeepAlive := rqInfo.response.connection = rqcKeepAlive;
    finally
      s := FRqINfo.request.document;
      {$ifdef RETAIN_HTTP_CLIENTS}
      if bKeepAlive then
        htpKeep := FRqINfo.StealHTTPCLient;
      {$endif}
      FRqInfo.free;
      FRqInfo := nil;
    end;




    while bKeepAlive do begin
      FRqInfo := TRequestInfo.create;
      {$ifdef RETAIN_HTTP_CLIENTS}
      FRqInfo.HTTPClient := htpKeep;
      {$endif}
//      s := rqinfo.request.document;
      status := '#'+requests_this_connection.tostring+' keep-alive after '+s;
      var tmStart := GetTicker;
      Step := 1;
      Stepcount := 1;
      while not self.clientsocket.waitfordata(1000) do begin
        if gettimesince(tmstart) > 60000 then break;
        if IsCancelled then break;

      end;
      if not self.ClientSocket.WaitForData(1) then begin
        if rqInfo=nil then
          Debug.Log('rqinfo is nil!');
        if rqInfo.request=nil then
          Debug.Log('rqInfo.request is nil!')   ;
        bKeepAlive := false;
        status := 'ka-timeout '+s;
        break;
      end;
      TRY
        inc(requests_this_connection);
        rqInfo.Request.Default('connection', 'close');
        //rqINfo.Request['connection'] := 'nil';
//        debug.log('About to process from keep alive: '+FRqInfo.request.document);
        WebServer.HitAccept;
        process2;
        bKeepAlive := rqInfo.response.connection = rqcKeepAlive;
//        if bKeepAlive then
//          self.ClientSocket.TimeOut := LONG_SOCKET_TIMEOUT;
      FINALLY
        s := FRqINfo.request.document;
        {$ifdef RETAIN_HTTP_CLIENTS}
         if bKeepAlive then
           htpKeep := FRqINfo.StealHTTPCLient;
        {$endif}

        FRQINfo.free;
        FRqInfo := nil;
      end;
    end;
  finally
//    htpKeep.free;
//    htpKeep := nil;
  end;


end;

procedure Tcmd_ProcessWebRequests.ReadAvailable(bHeaderComplete: boolean);
var
  s: rawbytestring;
//Reads bytes available on the socket.
begin

  CheckConnected;
  s := ReceiveText;

  //if the header has already been received, read into the content
  //else read into the "raw" buffer.
  if bHeaderComplete then begin
//    rqInfo.Request.ContentString := rqInfo.Request.ContentString + s;
    stream_GuaranteeWrite(rqInfo.Request.ContentStream.o, @s[low(s)], length(s));

  end else begin
    rqInfo.Request.RawText := rqInfo.Request.RawText + s;
  end;
end;

procedure Tcmd_ProcessWebRequests.ReadRequest;
var
  tm2, tm1: cardinal;
  iFirstSpace: integer;
  iTemp: integer;
  sTemp: rawbytestring;
  t: integer;
  sLeft, sRight : string;
  sLeft2, sRight2: string;
  sInlineParams: string;
  sFirstParam: string;
  sTempContent: string;
  bDoneReading: boolean;
  iContentLength : integer;
  iLastReceiveLength: integer;
  bHeaderComplete: boolean;
  sl: TStringList;
  sLeftover: rawbytestring;
const
  THREAD_READ_TIMEOUT = 30000;

begin
  RequestState := rqsReadHeader;
  { Place thread code here }
  bHeaderComplete := false;
  sTempContent := '';
  iContentLength := 0;
  rqINfo.Request.RawText := FPreload;

  //Init start timer
  tm1 := GetTickCount;
//  tmBench1 := GetTickCount;
  //Read... and be DEAD SURE... you've got it all


  repeat
    try
      //Check now many bytes are in the pipe
//      iLastReceiveLength:=ClientSocket.ReceiveLength;
      //If bytes are in the pipe, read them
//      IF iLastReceiveLength > 0 THEN BEGIN
        ReadAvailable(bHeaderComplete);

        //Reset timeout timer (client sender is still active)
        tm1 := GetTickCount;
//      END ELSE begin
        //Free up processor time if client is a slow sender
        CheckConnected;
//        Sleep(random(10));
//      end;

    except
      on E: EAbort do begin
        exit;
      end;
      on E: Exception do begin
        debug.log('Exception caught in Webprocessor.Process2 (read header): '+e.message, 'error');
        raise ESocketError.create('Exception reading header: '+E.Message);
        self.rqInfo.response.ResultCode := 400;
        self.rqInfo.Request.Document := 'erroneous';
        exit;
      end;
    end;

    tm2 := GetTickCount;

    //check timer rollover (happens only once every 18 days)
    //if the new time is less than the old timer then just set the old time
    //to the new time (rolled-over timeouts will take a little longer with this approach)
    if tm2<tm1 then
      tm1 := tm2;

    //Set status to reading body
    if bHeaderComplete then RequestState := rqsReadBody;

    //If header has not been received then search of end of header and get the content length from the header
    if not bHeaderComplete then begin
      //if found end of header....
      iTemp := pos(#13#10#13#10, rqInfo.Request.RawText);
      if iTemp = 0 then
        iTemp := pos(#13#13, rqInfo.Request.RawText);
      if iTemp<>0 then begin
        //split the request at the delimiter into the request[header] and requestcontent
        sTemp := rqInfo.Request.RawText;
//        rqInfo.Request.ContentString := copy(sTemp,  1, iTemp+3);
        //separate out and content bytes
//        rqInfo.Request.ContentString := '';
        sLeftOver := copy(sTemp, iTemp+4, length(sTemp) - iTemp+3);
        if length(sLeftOver) > 0 then
          SaveLeftOvers(@sLeftOver[1], length(sLeftOver))
        else
          sLeftOver := '';
        rqInfo.Request.ContentStream.o.seek(0, soBeginning);
        if sLeftOver <> '' then
          Stream_GuaranteeWrite(rqInfo.Request.ContentStream.o, @sLeftOver[low(sLeftOver)], length(sLeftOver));



        bheaderComplete := true;
        iContentLength := HackContentLength(rqInfo.Request.RawText);
      end;
    end else begin
      //rest of this stuff is handled in ReadAvailable();
    end;

    //determine that request is COMPLETE if header flag has been set indicating
    //that the header has been read AND the length of the RequestContent is
    //equal-to or greater than the content length specified in the header

    bDoneReading := bHeaderComplete and (rqInfo.request.contentstream.o.size>=iContentLength);

    //Thread-hang prevention
    //if haven't recieved data in THREAD_READ_TIMEOUT seconds, then kill the thread
    if (not bDoneReading) and (GetTimeSince(tm2,tm1) > THREAD_READ_TIMEOUT) then
      raise Exception.create('Thread read timeout');
  until
    bDoneReading;

    //This triggers the "raw" stringlist to split the request into multiple lines for easier parsing.
    rqInfo.request.rawtext := rqInfo.request.rawtext;

  try
    //if nothing was recieved then exit
    if length(rqInfo.Request.Rawtext)<1 then
      exit;

    sTemp := rqInfo.Request.Rawtext;

    //Get the 'GET/POST' part of the request

    iFirstSpace := pos(' ', sTemp);
    rqInfo.Request.Command := copy(sTemp, 1, iFirstSpace-1);


    //Remove the GET/POST part form the request line so that we can continue parsing
    sTemp := copy(sTemp, iFirstSpace+1, length(sTemp) - iFirstSpace);

    //Get the DOCUMENT part of the request
    iFirstSpace := pos(#10, sTemp);
    if iFirstSpace = 0 then
      iFirstSpace := pos(#13, sTemp);

    sTemp := copy(sTemp, 1, iFirstSpace-1);
    iFirstSpace := lastpos(' ', sTemp);
    rqInfo.Request.Document := copy(sTemp, 1, iFirstSpace-1);
    name := rqInfo.Request.command+' '+rqInfo.Request.Document;

    rqInfo.Request.command := uppercase(rqInfo.Request.Command);
    rqInfo.Request.Document := rqInfo.Request.Document;
    name := rqInfo.Request.command+' '+rqInfo.Request.Document;
    //showmessage(rqInfo.Request.text);

    //Get HEADER PARAMETERS
    //Params are passed as the 2nd through 2nd-to-last lines in the header
    t:= 1;
    sl := TStringList.create;
    try
      sl.text := rqInfo.request.rawtext;
      repeat
        rqInfo.request.Header.add(sl[t]);
        inc(t);

      until
        (t>=sl.count) or (sl[t] = '');
    finally
      sl.free;
    end;

    for t:= 0 to rqInfo.Request.Header.count-1 do begin
      //Split the line based on the first occurrence of a colon (:)
      sTemp := rqInfo.Request.Header[t];

      SplitString(sTemp, ':', sLeft, sRight);

      sRight := Trim(sRight);

      if (sLeft <> '') then begin
        //Left side is the name
        //Right side is param value
        rqInfo.Request.AddParam(Trim(sLeft), Trim(sRight), pcHeader);//<--Don't URL Decode the header parameters
      end;
    end;


    //GET COOKIE PARAMETERS
    //if (not rqInfo.request.HasParam('content-type') or (not (rqInfo.request['content-type'] = 'application/x-Digital Tundra'))) then
    if rqInfo.request.HasParam('Cookie')  then begin
      sInlineParams := rqInfo.Request['Cookie'];
      repeat
        //segregate the first parameter definition from the inline parameters
        SplitString(sInlineParams, ';', sFirstParam, sInlineParams);
        //Separate the parameter from the parameter value
        SplitString(sFirstParam, '=', sLeft, sRight);

        while pos('+', sRight) > 0 do begin
          SplitString(sRight, '+', sLeft2, sRight2);
          sRight := sLeft2+' '+sRight2;
        end;

        if sLeft <> '' then begin
          //Left side is the name
          //Right side is param value
          rqInfo.Request.AddParam(DecodeWebString(Trim(sLeft)), DecodeWebString(Trim(sRight)), pcCookie);
        end;
      until (sInlineParams = '');
    end;

    if rqInfo.request.HasParam('CookieEx')  then begin
      sInlineParams := rqInfo.Request['CookieEx'];
      repeat
        //segregate the first parameter definition from the inline parameters
        SplitString(sInlineParams, ';', sFirstParam, sInlineParams);
        //Separate the parameter from the parameter value
        SplitString(sFirstParam, '=', sLeft, sRight);

        while pos('+', sRight) > 0 do begin
          SplitString(sRight, '+', sLeft2, sRight2);
          sRight := sLeft2+' '+sRight2;
        end;

        if sLeft <> '' then begin
          //Left side is the name
          //Right side is param value
          rqInfo.Request.AddParam(DecodeWebString(Trim(sLeft)), DecodeWebString(Trim(sRight)), pcCookie);
        end;
      until (sInlineParams = '');
    end;

    //INLINE/URL PARAMETERS
    //-------------------
    //Get User-defined parameters from document name
    //split document name based on whatever comes first ? or #
    if (  (pos('?', rqInfo.Request.Document) < pos('#', rqInfo.Request.Document)  )
        or (pos('#', rqInfo.Request.Document) = 0)) then
      SplitString(rqInfo.Request.Document, '?', sLeft, sRight)
    else
      SplitString(rqInfo.Request.Document, '#', sLeft, sRight);
    //ReAssign docuement name to just the part BEFORE the "?"
    rqInfo.Request.Document := sLeft;

    sInlineParams := sRight;
    var origURLPArams := sInlineParams;
    if sRight<>'' then begin
      repeat

        //segregate the first parameter definition from the inline parameters
        SplitString(sInlineParams, '&', sFirstParam, sInlineParams);
        //Separate the parameter from the parameter value
        SplitString(sFirstParam, '=', sLeft, sRight);


        if sLeft <> '' then begin
          //Left side is the name
          //Right side is param value
          rqInfo.Request.AddParam(DecodeWebString(Trim(sLeft)), DecodeWebString(Trim(sRight)), pcInline);
        end;
      until (sInlineParams = '');
    end;
//    if zpos('id=', origURLParams) >=0 then
//      if rqInfo.request.params['id'] = '' then
//        raise ECritical.create('whowhowhowhowhowhowhowa');



    //If a multipart message
    if NOT IsMultiPart(rqInfo) then begin
      //GET CONTENT PARAMETERS
      if (zpos('form-urlencoded', lowercase(rqInfo.request.contenttype)) >=0)
      and (length(rqInfo.Request.Contentstring) > 0) then begin
        sInlineParams := rqInfo.Request.Contentstring;
        repeat

          //segregate the first parameter definition from the inline parameters
          SplitString(sInlineParams, '&', sFirstParam, sInlineParams);
          //Separate the parameter from the parameter value
          SplitString(sFirstParam, '=', sLeft, sRight);

  (*        while pos('+', sRight) > 0 do begin
            SplitString(sRight, '+', sLeft2, sRight2);
            sRight := sLeft2+' '+sRight2;
          end;*)

          if sLeft <> '' then begin
            //Left side is the name
            //Right side is param value
            rqInfo.Request.AddParam(DecodeWebString(Trim(sLeft)), DecodeWebString(Trim(sRight)), pcContent);
          end;
        until (sInlineParams = '');
      end;
    end;

(*    EchoParametersAsComments(rqInfo);
    showmessage(rqInfo.response.content.text);*)

    //super session hook -- used to aid Load-testing scripts
    if (rqInfo.request.HasParam('supersession')) and (rqInfo.request.HasParam('sessionid')) then begin
      if rqInfo.sessionid = 0 then begin
        rqInfo.request.AddParam('sessionid', rqInfo.request['supersession'], pcCookie);
      end;
    end;

    rqInfo.request.document := rqInfo.request.document;

  finally

  end;
end;

function Tcmd_ProcessWebRequests.ReceiveText: string;
var
  i: integer;
  ansi: ansistring;
begin
  if assigned(FLeftOvers) then begin

    SetLength(ansi, FLeftOverLength);
    MoveMem32(@ansi[1], FLeftOvers, FLeftOverLength);
    FreeMem(FLeftOvers);
    FLeftOvers := nil;
    result := ansi;
    exit;
  end;



  if not ClientSocket.Connected then
    raise ESocketError.create('Socket terminated on read');

  IF clientsocket.WaitForData(SHORT_SOCKET_TIMEOUT) then begin
    setlength(ansi, 512);
    setlength(ansi, helpers.sockets.Socket_Read(clientsocket, Pbyte(@ansi[STRZ]), 512));
    if length(ansi) = 0 then begin
      clientsocket.close;
    end;
    result := ansi;
  end else
    raise ESocketError.Create('timed out/disconnected waiting for text');

  CheckConnected;

end;

procedure Tcmd_ProcessWebRequests.SaveLeftOvers(p: Pbyte; len: integer);
begin
  GetMem(FLeftOvers, len);
  MoveMem32(FLeftOvers, p, len);
end;

procedure Tcmd_ProcessWebRequests.SetRequestState(const Value: TRequestState);
begin

//TODO -cunimplemented: unimplemented block
end;


procedure Tcmd_ProcessWebRequests.SetSocketProxy(const Value: TCustomIPClient);
begin
  self.ClientSocket := value;
end;


procedure Tcmd_ProcessWebRequests.WriteChunk;
begin
  self.WriteResponseData(rqInfo.Response.Content.text);
end;

procedure Tcmd_ProcessWebRequests.WriteContent;
var
  stream : TStream;
  junk : ansichar;
begin
  RequestState := rqsWriteBody;

{  if rqInfo.response.ContentStream = nil then begin
    stream := TMemoryStream.create;
    stream.seek(0,0);
    rqInfo.Response.content.SaveToStream(stream, TEncoding.ASCII);
    if rqInfo.request.UserAgent = 'Charlotte/0.9' then begin
      junk := '~';
      stream.Write(junk,1);
    end;
  end;}



  //Send stream if assigned
  if rqInfo.response.ContentStream <> nil then begin
    rqInfo.response.contentstream.Seek(0,0);

    stream := rqInfo.response.contentstream;
    //Set stream to nil to make sure memory isn't trashed on rqInfo.free.
    //Stream WILL BE FREED if still assigned (in case an internal failure prevents the stream from being sent).
    rqInfo.response.contentStream := nil;


    try
      if rqInfo.response.RangeEnd >= 0 then begin
        Socket_GuaranteeWriteStreamPart(stream, rqInfo.response.RangeStart, rqInfo.Response.RangeEnd, self.ClientSocket);
      end else begin
        self.CLientSocket.SendStream(stream);
      end;
    finally
      stream.free;
    end;

  //Otherwise send as text
  end else begin
    if rqInfo.request.UserAgent = 'Charlotte/0.9' then begin
      self.WriteResponseData(rqInfo.Response.Content.text, rqInfo.response.contentlength-1);
      self.WriteResponseData('~', 1);
    end else begin
      if not rqInfo.response.FakeContentLength then
        self.WriteResponseData(rqInfo.Response.Content.text, rqInfo.response.contentlength);
    end;

  end;
end;

procedure Tcmd_ProcessWebRequests.WriteHeader;
var
  s: string;
  t: integer;
  sConn: string;
begin
  RequestState := rqsWriteHeader;

  if rQInfo.response.RawHeader <> '' then begin
    self.WriteResponseData(rqInfo.response.RawHeader);
    exit;
  end;



  //Generate some default messages for certain return codes if no result message
  //was specified
  if rqInfo.Response.Location <> '' then begin
    rqInfo.Response.Message := 'Moved';
  end;

  if rqInfo.Response.ResultCode = 200 then
//    rqInfo.response.message := 'OK'
  else
  if rqInfo.Response.ResultCode = 500 then
//    rqINfo.response.message := ;

  //Allocate a chunk of memory to reduce memory fragmentation
  SetLength(s, 1000);
  //calc first line of header
  s:='HTTP/1.1 '+inttoStr(rqInfo.Response.Resultcode)+' '+rqInfo.response.message+#13#10;


  //if content encoding is not chunked
  if not (lowercase(rqInfo.Response.TransferEncoding)='chunked') then begin
    //Set the content length -- length of string if never set.. else override with real value
    if rqInfo.Response.ContentLength = -1 then
      s:= s+'Content-Length: '+inttostr(length(rqInfo.Response.Content.Text))+#13#10
    else
      s:= s+'Content-Length: '+inttostr(rqInfo.Response.ContentLength)+#13#10;
  end;

  //Transfer encoding header result
  if rqInfo.Response.TransferEncoding <> '' then
    s:=s+'Transfer-Encoding: '+rqInfo.Response.TransferEncoding+#13#10;

  if rqInfo.Response.ContentEncoding <> '' then
    s:=s+'Content-Encoding: '+rqInfo.Response.ContentEncoding+#13#10;



  //More header params
  s:=s+'Server: Mothership Enterprise'+#13#10;
  if rqInfo.Response.Location <>'' then
    s:=s+'Location: '+rqInfo.Response.Location+#13#10;
  s := s+'Access-Control-Allow-Origin: *'+CRLF;
  s:=s+'Content-Type: '+rqInfo.Response.ContentType+#13#10;
  s:=s+'Last-Modified: '+FormatDateTime('ddd'','' d-mmm-yyyy hh:nn:ss', now)+' GMT'+#13#10;
  s:=s+'Date: '+FormatDateTime('ddd'','' d-mmm-yyyy hh:nn:ss', now)+' GMT'+#13#10;
//  s:=s+'Last-Modified: Wed, 25 Jul 2001 17:26:20 GMT'+#13#10;
//  s:=s+'ETag: "b0a29beb2e15c11:b5d"'+#13#10;
//  s:=s+'Accept-Ranges: bytes'+#13#10;
//  s:=s+'Pragma: no-cache'+#13#10;
  s:=s+'Expires: Tuesday, 14-Dec-1971 04:30:00 GMT'+#13#10;

  //Cookie header params
  if rqInfo.response.CookieCount > 0 then begin
    for t:= 0 to rqInfo.response.cookiecount-1 do begin
      var val := rqInfo.Response.CookieValues[t];
      if val = '' then
        s:=s+'Set-Cookie: '+rqInfo.response.cookienames[t]+'='+rqInfo.response.cookievalues[t]+';expires=Monday, 10-Aug-1977 00:00:00 GMT;path=/'+#13#10
      else
        s:=s+'Set-Cookie: '+rqInfo.response.cookienames[t]+'='+rqInfo.response.cookievalues[t]+';expires=Monday, 10-Aug-2099 00:00:00 GMT;path=/'+#13#10;
    end;
  end;

  if rqInfo.response.connection = rqcAuto then begin
    rqInfo.request.default('connection', 'close');
    if lowercase(rqInfo.request['connection']) = 'keep-alive' then
      rqInfo.response.connection := rqcKeepAlive
    else
      rqInfo.response.connection := rqcClose;
  end;

  if rqInfo.response.connection = rqcClose then begin
    sConn := 'close';
  end else begin
    sConn := 'keep-alive'
  end;

{$IFDEF ALWAYS_CLOSE}
  rqInfo.response.connection := rqcClose;
{$ENDIF}

  if rqInfo.response.acceptRanges then begin
    s := s + 'Accept-Ranges: bytes'+#13#10;
  end;
  if rqInfo.response.rangeEnd >= 0 then begin
    if rqInfo.response.contentstream <> nil then
      s := s+'Content-Range: bytes '+inttostr(rqInfo.response.rangeStart)+'-'+inttostr(rqInfo.response.rangeEnd)+'/'+inttostr(rqInfo.response.contentstream.size)+#13#10;
  end;




//  s:=s+'Connection: '+sConn+#13#10;
  s:=s+'Content:'+#13#10+#13#10;


  //Send response down pipe
  self.WriteResponseData(s);

  rqInfo.request.rawtext := rqInfo.request.rawtext;

end;
procedure Tcmd_ProcessWebRequests.WriteResponse;
begin


  if not rqInfo.response.HeaderSent then
    WriteHeader;

  if not (rqInfo.response.TransferEncoding = 'chunked') then
    WriteContent;



end;

procedure Tcmd_ProcessWebRequests.WriteResponseData(s: ansistring; iLength: integer = -1);
const
  BUF_SIZE = 2;
begin
  try
(*//  buf := StrAlloc(BUF_SIZE);
    for t := 0 to rqInfo.Response.ContentLength-1 div BUF_SIZE do begin
      //setup base address
      iBase := t*BUF_SIZE;

      //setup length to write
      iWriteLength := (rqInfo.response.contentlength -1)- iBase;
      if iWriteLength>BUF_SIZE then
        iWriteLength := BUF_SIZE;

      for u:= 1 to iWritelength do begin
        //write the bytes to the temporary buffer.
        buf[u] := s[iBase+u];
      end;

      iAddress := @buf[1];
      self.ClientSocket.SendBuf(iAddress^, iWriteLength);
    end;*)

    socket_guaranteeWrite(self.ClientSocket, @s[STRZ], length(s));
    //self.ClientSocket.SendText(s, iLength);

  except
    on E: Exception do begin
      debug.log('Exception in WebProcessor.WriteResponseData:'+ E.MEssage, 'error');
    end;
  end;

end;

end.
