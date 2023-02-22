unit IRCServer;

interface

uses
  helpers_stream, tickcount, classes, typex, systemx, stringx, idtcpserver,idglobal, betterobject, idcontext, better_collections, debug, sysutils, managedthread, fatmessage;

type
  TIRCFlags = record
    namesx: boolean;
    uhnames: boolean;
  end;
  TchallengeMode = (cmRequired, cmRequiredForCHANL, cmOptional);

  TIRCChannel = class;//forward
  TIRCServer = class;//forward)

  TIRCConnection = class(TSharedObject)
  public
    challengemet: boolean;
    nick: string;
    user: string;
    user_num: string;
    user_wild: string;
    context: TIdContext;
    gotcaps: boolean;
    flags: TIRCFlags;
    scramble: boolean;
    lastseen: ticker;//time last seen, ponged or pinged or other line/command
    lastping: ticker;//time last ping was sent (pending pong)
    challenge_sent: string;
    procedure send_generic_msg(id: string; sTrailer: string);overload;
    procedure send_generic_msg(id: string; params: TArray<string>; sTrailer: string);overload;

    procedure channel_msg(from: TIRCConnection; chan: TIRCChannel; sTrailer: string);overload;
    procedure msg_chan_to_specific_user_raw(chan: TIRCChannel; sRaw: string; sPreChan: string = '');
    procedure privmsg(sTarget: string; sMessage: string; sFrom: string = '');
    procedure cmdmsg(sCmd: string; sFrom: string = '');
    procedure ircmsg(sCmd: string; sParams: string = '');
    function FullIdent: string;
    procedure pinged;
    procedure Detach; override;
    constructor Create; override;
    procedure Disconnect;
    function ScrambleString(s: string): string;
    function UnScrambleString(s: string): string;
    procedure SendScrambledLine(sLine: string);
  end;

  TIRCChannel = class(TSharedObject)
  protected
    procedure NotifyJoined(con: TIRCConnection);
    procedure NotifyLeft(con: TIRCConnection);
    procedure OpenLogFile;
    procedure CloseLogFile;
  public
    [weak] irc: TIRCSErver;
    name: string;
    users: TSharedList<TIRCConnection>;
    logfile: TFileStream;
    constructor Create; override;
    procedure Detach; override;
    procedure join(con: TIRCConnection);
    procedure leave(con: TIRCConnection);
    procedure msg_everyone_in_channel(confrom: TIRCConnection; sMsg: string; bExcludeSelf: boolean = true);
    procedure privmsg_everyone_in_channel(confrom: TIRCConnection; sMsg: string);

    procedure EchoNames(toCon: TIRCConnection);
    procedure EchoWhoHere(toCon: TIRCConnection);
    procedure EchoWhoHere_ToEveryone();
    procedure LogToFile(confrom: TIRCConnection; sMSG: string);



  end;

  TIRCServer = class (TSharedObject)
  private
    FCons: TSharedList<TIRCConnection>;
    FChannels: TSharedList<TIRCChannel>;
    FPort: int64;
  protected
    idsrv: TIdTCPServer;
    mq: TFatMessageQueue;
    eet: TExternalEventThread;
    function FindChannel(sName: string): TIRCChannel;
    function HasChannel(sName: string) : boolean;
    function AddChannel(sName: string): boolean;
    function CloseChannel(sName: string): boolean;

    procedure StartListening;
    procedure StopListening;
    procedure SRVOnConnect(AContext: TIdContext);
    procedure SRVOnDisconnect(AContext: TIdContext);
    procedure SRVOnExecute(AContext: TIdContext);
    procedure EETOnExecute(thr: TExternalEventThread);

    procedure handle_line(con: TIRCConnection; sLine: string);
    procedure handle_command_scramble(con: TIRCConnection);
    procedure handle_command(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_join(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_hist(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_close(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_promote(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_chal(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_char(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_chanL(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_whohere(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_part(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_names(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_privmsg(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_invite(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_command_kick(con: TIRCConnection; sLine: string; sl: TStringList);
    procedure handle_welcome(con: TIRCConnection);
    procedure RemoveFromAllChannels(con: TIRCConnection);
    procedure SendChannels();overload;
    procedure SendChannels(con: TIRCconnection);overload;
    procedure ChannelEmpty(chan: TIRCChannel);
    procedure ExpireDeadConnections;
    function AdjustNick(sNick: string): string;
    function HasNick(sNick: string): boolean;

  public
    challengemode : TchallengeMode;
    constructor Create; override;
    procedure Detach; override;
    property Port: int64 read FPort write FPort;

  end;





implementation

{ TIRCServer }

function TIRCServer.AddChannel(sName: string): boolean;
begin
  var lck : ILock := FChannels.locki;

  if HasChannel(sName) then
    exit(false);

  Debug.Log('adding channel '+sName);

  var chan := TIRCChannel.create;
  chan.name := sName;
  chan.irc := self;
  FChannels.Add(chan);
  exit(true);

end;

function TIRCServer.AdjustNick(sNick: string): string;
begin
  var l := FCons.LockI;
  var append := '';
  var iter := 0;
  var adj := sNick;
  while HasNick(adj) do begin
    inc(iter);
    adj := sNick + inttostr(iter);
  end;
  result := adj;

end;

procedure TIRCServer.ChannelEmpty(chan: TIRCChannel);
begin
  if FChannels.trylock then
  try
    if zcopy(chan.name,0,1) <> '#' then begin
      FChannels.Remove(chan);
      chan.free;
      chan := nil;
    end;
  finally
    fChannels.unlock;
  end;
  SendChannels;
end;

function TIRCServer.CloseChannel(sName: string): boolean;
//Returns: false if users still in channel
//Returns: true if close was successful, including if already closed or doesn't exist
begin
  var lck : ILock := FChannels.locki;

  if HasChannel(sName) then
    exit(true);

  Debug.Log('closing channel '+sName);


  var chan := Self.FindChannel(sNAme);
  if chan = nil then
    exit(true);
  if chan.users.Count > 0 then
    exit(false);

  FChannels.Remove(chan);
  chan.Free;
  chan := nil;
  exit(true);
end;

constructor TIRCServer.Create;
begin
  inherited;
  challengemode := cmRequiredForCHANL;
  mq := TFatMessageQueue.Create;
  fCons := TSharedList<TIRCConnection>.create;
  fChannels := TSharedList<TIRCChannel>.create;
  port := 223;

  StartListening;


  mq.handler := function (msg: IHolder<TFatMessage>): boolean
    begin
      Debug.Log('handling chanl_updated message');
      if msg.o.messageClass = 'chanl_updated' then begin

        var channame := msg.o.params[0];
        if FChannels.TryLock then
        try
          var chan := Self.FindChannel(channame);
          if chan <> nil then
            chan.EchoWhoHere_ToEVeryone;
        finally
          FChannels.Unlock;
        end;


      end;
    end;


end;

procedure TIRCServer.Detach;
begin
  if detached then exit;
  StopListening;
  FCons.free;
  FChannels.free;
  mq.Free;
  mq := nil;

  inherited;

end;

procedure TIRCServer.EETOnExecute(thr: TExternalEventThread);
begin
  thr.RunHot := mq.ProcessNextMessage;
  ExpireDeadConnections;


end;

procedure TIRCServer.ExpireDeadConnections;
begin
  var l := FCons.LockI;
  for var t := FCons.count-1 downto 0 do begin
    var c:= FCons[t];
    if (gettimesince(c.lastseen) > 180000) and (gettimesince(c.lastping) > 10000) then begin
      c.lastping := getticker;
      Debug.Log('pinging connection that we have not seen for 3 minutes');
      c.ircmsg('PING whatever');
    end;

    if gettimesince(c.lastseen) > 300000 then begin
      Debug.Log('expiring connection that we have not seen for 5 minutes');
      c.disconnect;
      FCons.delete(t);
      c := nil;
    end;

  end;
end;

function TIRCServer.FindChannel(sName: string): TIRCChannel;
begin

  var lck := FChannels.locki;

  for var t := 0 to FChannels.count-1 do begin
    if (comparetext(FChannels[t].name, sName)=0) then
      exit(FChannels[t]);
  end;

  result := nil;
end;

procedure TIRCServer.handle_command(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  if sl.count = 0 then exit;
  var cmd := uppercase(sl[0]);
  if (cmd = 'CHAL') or (cmd = SimpleOb('CHAL')) then begin
    handle_command_chal(con, sLine, sl);
  end else
  if (cmd = 'CHAR') or (cmd = SimpleOb('CHAR')) then begin
    handle_command_chaR(con, sLine, sl);
  end else
  if (cmd = 'OBFS') or (cmd = SimpleOb('OBFS')) then begin
    con.scramble := true;
    con.SendScrambledLine('OBFS');
  end else
  if (cmd = 'CAP') or (cmd = SimpleOb('CAP')) then begin
    if uppercase(sl[1]) = 'END' then begin
      con.gotcaps := true;
    end;
  end else
  if (cmd = 'NICK') or (cmd = SimpleOb('NICK')) then begin
    if sl.count < 2 then
      exit;

    var conl := Fcons.LockI;
    con.nick := AdjustNick(sl[1]);
//    if con.nick <> sl[1] then
      con.SendScrambledLine('UR '+con.nick);

  end else
  if (cmd = 'USER') or (cmd = SimpleOb('USER')) then begin
    con.user := sl[1];
    con.user_num := sl[2];
    con.user_wild := sl[3];
    con.SendScrambledLine('compa.net CAP * LS unrealircd.org/plaintext-policy unrealircd.org/link-security extended-join chghost cap-notify userhost-in-names multi-prefix away-notify account-notify sasl tls');
    handle_welcome(con);
  end else
  if (cmd = 'PING') or (cmd = SimpleOb('PING')) then begin
    con.pinged;
    ExpireDeadConnections;
  end else
  if (cmd = 'PONG') or (cmd = SimpleOb('PONG')) then begin
    con.pinged;
    ExpireDeadConnections;
  end else
  if (cmd = 'NAMESX') or (cmd = SimpleOb('NAMESX')) then begin
    con.flags.namesx := true;
  end else
  if (cmd = 'UHNAMES') or (cmd = SimpleOb('UHNAMES')) then begin
    con.flags.uhnames := true;
  end else
  if (cmd = 'CLOSE') or (cmd = SimpleOb('CLOSE')) then begin
    handle_command_close(con, sLIne, sl);
  end else
  if (cmd = 'HIST') or (cmd = SimpleOb('HIST')) then begin
    handle_command_hist(con, sLIne, sl);
  end else
  if (cmd = 'PROMOTE') or (cmd = SimpleOb('PROMOTE')) then begin
    handle_command_promote(con, sLIne, sl);
  end else
  if (cmd = 'JOIN') or (cmd = SimpleOb('JOIN')) then begin
    handle_command_join(con, sLIne, sl);
  end else
  if (cmd = 'PART') or (cmd = SimpleOb('PART')) then begin
    handle_command_part(con, sLIne, sl);
  end else
  if (cmd = 'NAMES') or (cmd = SimpleOb('NAMES')) then begin
    handle_command_names(con, sLIne, sl);
  end else
  if (cmd = 'MODE') or (cmd = SimpleOb('MODE')) then begin
//    handle_command_join(con, sLIne, sl);
  end else
  if (cmd = 'CHANL') or (cmd = SimpleOb('CHANL')) then begin
    handle_command_chanL(con, sLIne, sl);
  end else
  if (cmd = 'WHOHERE') or (cmd = SimpleOb('WHOHERE')) then begin
    handle_command_whohere(con, sLIne, sl);
  end else
  if (cmd = 'PRIVMSG') or (cmd = SimpleOb('PRIVMSG')) then begin
    handle_command_privmsg(con, sLIne, sl);
  end else
  if (cmd = 'INVITE') or (cmd = SimpleOb('INVITE')) then begin
    handle_command_invite(con, sLIne, sl);
  end else
  if (cmd = 'KICK') or (cmd = SimpleOb('KICK')) then begin
    handle_command_kick(con, sLIne, sl);
  end else begin
    Debug.Log('WARNING!!!!! *** unknown command '+cmd+' line:'+sLine);
  end;



end;

procedure TIRCServer.handle_command_chal(con: TIRCConnection; sLine: string;
  sl: TStringList);
const
  alpha = '0123456789qazwsxedcrfvtgbyhnujmikolpQAZWSXEDCRFVTGBYHNUJMIKOLP';
begin
  var cs := '';
  for var t:= 0 to 63 do begin
    cs := cs + alpha[random(high(alpha))];
  end;
  con.challenge_sent := cs;
  con.SendScrambledLine('CHAQ '+SimpleOb(con.challenge_sent));
end;

procedure TIRCServer.handle_command_chanL(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  if con.challengemet then
    SendChannels(con)
  else
    con.SendScrambledLine('challenge not met');
end;

procedure TIRCServer.handle_command_char(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  var res := zcopy(sLine, 5,length(sLine));
  if DifferentOb(res) = con.challenge_sent then
    con.challengemet := true;

end;

procedure TIRCServer.handle_command_close(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  if sl.count < 2 then
    exit;

  var ilock := FChannels.LockI;

  var slh := parsestringh(sl[1], ',');
  for var t:= 0 to slh.o.count-1 do begin
    if CloseChannel(slh.o[t]) then
      sendChannels();
  end;
end;

procedure TIRCServer.handle_command_hist(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin

  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;

procedure TIRCServer.handle_command_invite(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  FCons.Lock;
  try
    if sl.count < 3 then begin
      Debug.Log('BAD LINE: '+sLine);
      exit;
    end;

    var user := sl[1];
    var chan := sl[2];
    for var t := 0 to FCons.Count-1 do begin
      if 0=comparetext(FCons[t].nick, user) then begin
        try
        FCons[t].send_generic_msg('INVITE',[chan],'');
        except
        end;
      end;
    end;
  finally
    FCons.Unlock;
  end;


end;

procedure TIRCServer.handle_command_join(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  if sl.count < 2 then
    exit;

  var ilock := FChannels.LockI;




  var slh := parsestringh(sl[1], ',');
  for var t:= 0 to slh.o.count-1 do begin
    if AddChannel(slh.o[t]) then
      sendChannels();
    var chan := FindChannel(slh.o[t]);
    if chan <> nil then
      chan.join(con);
  end;



end;


procedure TIRCServer.handle_command_kick(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  FCons.Lock;
  try
    if sl.count < 3 then begin
      Debug.Log('BAD LINE: '+sLine);
      exit;
    end;

    var user := sl[1];
    var chan := sl[2];
    for var t := 0 to FCons.Count-1 do begin
      if 0=comparetext(FCons[t].nick, user) then begin
        try
        FCons[t].send_generic_msg('KICK',[chan],'');
        except
        end;
      end;
    end;
  finally
    FCons.Unlock;
  end;

end;

procedure TIRCServer.handle_command_names(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  var ilock := FChannels.LockI;
  for var t := 0 to FChannels.count-1 do begin
    Fchannels[t].echonames(con);
  end;


end;

procedure TIRCServer.handle_command_part(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  var ilock := FChannels.LockI;

  var slh := parsestringh(sl[1], ',');
  for var t:= 0 to slh.o.count-1 do begin
    var chan := FindChannel(slh.o[t]);
    if chan <> nil then begin
      Debug.Log('connection is leaving channel '+chan.name);
      chan.leave(con);
      Debug.Log('notifying other connections that we''ve left the channel '+chan.Name);
      chan.EchoWhoHere(con);
      MQ.QuickBroadcast('chanl_updated', [chan.name]);
    end;
  end;




end;

procedure TIRCServer.handle_command_privmsg(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  Fchannels.lock;
  try
    if sl.count > 1 then
    for var t := 0 to FChannels.count-1 do begin
      if sl.count < 2 then exit;
      var sTo := sl[1];
      var chan := FChannels[t];
      if comparetext(chan.name, sTo)=0 then begin
        sl.delete(0);
        sl.delete(0);
        var msg := unparsestring(' ',sl);
        chan.msg_everyone_in_channel(con, msg);
      end;
    end;
  finally
    FChannels.unlock;
  end;
end;

procedure TIRCServer.handle_command_promote(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin

  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;

procedure TIRCServer.handle_command_scramble(con: TIRCConnection);
begin
  con.scramble := true;
end;

procedure TIRCServer.handle_command_whohere(con: TIRCConnection; sLine: string;
  sl: TStringList);
begin
  var ilock := FChannels.LockI;

  if sl.count < 2 then
    exit;


  var slh := parsestringh(sl[1], ',');
  for var t:= 0 to slh.o.count-1 do begin
    var chan := FindChannel(slh.o[t]);
    if chan <> nil then begin
      chan.EchoWhoHere(con);
//      chan.echonames(con);
//      chan.leave(con);
    end;
  end;
end;

procedure TIRCServer.handle_line(con: TIRCConnection; sLine: string);
begin
  idsrv.Contexts.LockList;
  try
    con.lastseen := getticker;
    Debug.log(sLine);
    var slh := ParseStringh(sLine, ' ');
    handle_command(con, sLine, slh.o);
  finally
    idsrv.contexts.Unlocklist;
  end;
end;

procedure TIRCServer.handle_welcome(con: TIRCConnection);
begin
  con.send_generic_msg('001', 'Welcome to CompaNet... ');
  con.send_generic_msg('002', [con.nick], 'is your nickname');//your nick is now whatever
  con.send_generic_msg('003', 'Pointless message about server creation time');//this server was create ... date... whatever
//  con.send_generic_msg('005', ['AWAYLEN=307 CASEMAPPING=ascii CHANLIMIT=#:50 CHANMODES=beIqa,kLf,l,psmntirzMQNRTOVKDdGPZSCc CHANNELLEN=32 CHANTYPES=# DEAF=d ELIST=MNUCT EXCEPTS EXTBAN=~,tmTSOcaRrnqj HCN INVEX'], 'are supported by this server');
//  con.send_generic_msg('005', ['KICKLEN=30/join 7 KNOCK MAP MAXCHANNELS=5 MAXLIST=b:100,e:100,I:100 MAXNICKLEN=256 MODES=12 NAMESX NETWORK=CompaNet NICKLEN=256 PREFIX=(ohv)@%+) QUITLEN=307'], 'are supported by this server');
//  con.send_generic_msg('005', ['SAFELIST SILENCE=10 STATUSMSG=@%+ TARGMAX=DCALLOW:,ISON:,JOIN:,KICK:,KILL:,LIST:,NAMES:1,'+'NOTICE:1,PART:,PRIVMSG:4,SAJOIN:SAPART:,USERHOST:,USERIP:,WATCH:,WHOIS:1,WHOWAS:1 TOPICLEN=360 UHNAMES USERIP WALLCHOPS WATCH=128 WATCHOPTS=A'],'are supported by this server');
  con.send_generic_msg('396', [con.nick],'is nao your displayed host');
  con.send_generic_msg('251', [FCons.count.tostring], 'There are '+Fcons.count.tostring+' users/computers connected');
  con.send_generic_msg('252', ['0'],'operators, unknown');
  con.send_generic_msg('253', ['0'],'unknown connections... unknown');
  con.send_generic_msg('254', [Fchannels.count.tostring],'channels');
  con.send_generic_msg('255', [Fcons.count.tostring], 'clients');
  con.send_generic_msg('265', [Fcons.count.tostring, '999'], 'local users/max');
  con.send_generic_msg('266', [Fcons.count.tostring, '999'], 'global users/max');
  con.send_generic_msg('422', 'MOTD');
  con.send_generic_msg('MODE', '+ix');
  con.send_generic_msg('NOTICE', 'Notice: Jason is a genius');
  SendChannels(con);




end;

function TIRCServer.HasChannel(sName: string): boolean;
begin
  result := FindChannel(sName) <> nil;
end;

function TIRCServer.HasNick(sNick: string): boolean;
begin
  var l := FCons.LockI;
  for var t:= 0 to FCons.Count-1 do begin
    if comparetext(Fcons[t].nick, sNick)=0 then
      exit(true);
  end;

  exit(false);

end;

procedure TIRCServer.RemoveFromAllChannels(con: TIRCConnection);
begin
  var lck := FChannels.LockI;
  for var t := FChannels.count-1 downto 0 do begin
    FChannels[t].leave(con);
  end;
end;

procedure TIRCServer.SendChannels(con: TIRCconnection);
begin
  var cl := con.Locki;
  var chans: string := '';
  begin
    var l := FChannels.LockI;//LOCKS until the "end" of this scope
    for var t:= 0 to FChannels.count-1 do begin
      if t < (FChannels.count-1) then
        chans := chans + FChannels[t].name+' '
      else
        chans := chans + FChannels[t].name;
    end;
  end;

  if con <> nil then
    con.ircmsg('CHANL '+trim(chans));
end;

procedure TIRCServer.SendChannels;
begin
  var l := FCons.locki;
  for var t := 0 to FCons.count-1 do begin
    if FCons[t].trylock then
    try
      SendChannels(FCons[t]);
    finally
      FCons[t].unlock;
    end;
  end;

end;

procedure TIRCServer.SRVOnConnect(AContext: TIdContext);
begin
  Debug.Log('Hark! A connnexion!');
end;

procedure TIRCServer.SRVOnDisconnect(AContext: TIdContext);
begin
  Debug.Log('Buhbye!');

end;

procedure TIRCServer.SRVOnExecute(AContext: TIdContext);
begin
  //THIS function represts the >>> ENTIRE LIFETIME <<< of an
  //IRC connection.   Resources are setup in the start of the function
  //cleaned up at the end... pretty simple.
  Debug.Log('Hai!');


  var cli := TIRCConnection.Create;
  try
    cli.context := Acontext;
    self.FCons.Add(cli);//<<connection is added to shared so we connection can
                        //find by nick and and broadcast messages around

    while AContext.Connection.Connected do begin
      Acontext.Connection.IOHandler.ReadTimeout := 10;
      Acontext.Connection.IOHandler.DefStringEncoding := IndyTextEncoding_UTF8;
      var s := Acontext.Connection.IOHandler.ReadLn();
      if cli.scramble then
        s := cli.UnScrambleString(s);
      if s <> '' then begin
        handle_line(cli, s);
      end else begin
        ExpireDeadConnections;
      end;
    end;

  finally
    cli.context := nil;
    RemoveFromAllchannels(cli);

    FCons.Remove(cli);
    cli.free;
  end;


end;

procedure TIRCServer.StartListening;
begin
  eet := TPM.Needthread<TExternalEventThread>(nil);
  eet.Name := 'IRCServer Events';
  eet.ColdRunInterval := 8000;
  eet.OnExecute := EETOnExecute;



  if idsrv = nil then begin
    idsrv := TIdTCPServer.create(nil);
    idsrv.DefaultPort := port;
    idsrv.MaxConnections := 10000;
    idsrv.OnConnect := SRVOnConnect;
    idsrv.OnDisconnect := SRVOnDisconnect;
    idsrv.OnExecute := SRVOnExecute;
    idsrv.active :=true;
  end;

  eet.Start;

end;

procedure TIRCServer.StopListening;
begin
  eet.Stop;

  idsrv.free;
  idsrv := nil;

  TPM.NoNeedthread(eet);
  eet := nil;


end;

{ TIRCConnection }

procedure TIRCConnection.send_generic_msg(id: string; sTrailer: string);
begin
  var sLine := id+' '+Nick+' :'+sTrailer;
  debug.log('>>>>>'+sLine);
  SendScrambledLine(sLine);

end;

procedure TIRCConnection.channel_msg(from: TIRCConnection; chan: TIRCChannel;
  sTrailer: string);
begin
  //:[MG]-Request|Bot|Charlie!root@Movie.Gods.Rules PRIVMSG #moviegods :#337  33x [2.8G] Tropic.Thunder.2008.720p.BluRay.x264-x0r.mkv
  //^^^^user^^^^^^^^^^^^^^^^^!^^^^identsoemthing^^^ PRIVMSG ^^CHAN^^^^ :msg.......


 // :[MG]-MISC|EU|S|SpeedStick!root@Movie.Gods.Rules PRIVMSG #moviegods :#732   9x [5.5G] Kingdom.2019.GERMAN.720p.BluRay.x264-UNiVERSUM.mkv Process MovieWeb.exe (17676)

//  var sLine := ':'+chan.name+'!'+nick+' PRIVMSG '+chan.name+' ';
  var sLine := '';


  if from = nil then
    sLine := ':'+chan.name+'!'+chan.name+' PRIVMSG '+chan.name+' '
  else
    sLine := ':'+from.nick+'!'+from.nick+'@nowhere'+' PRIVMSG '+chan.name+' ';


  sLine := sLine+sTrailer;

  if context <> nil then
  if context.connection <> nil then
    if context.connection.iohandler <> nil then begin
      SendScrambledLine(sLine);
    end;
end;

procedure TIRCConnection.cmdmsg(sCmd, sFrom: string);
begin
  if sFrom = '' then
    sFrom := 'system!system@system';
  var sLine := ':'+sFrom+' '+sCmd;
  debug.log('>>cmd>>'+sLine);
  if assigned(context) then
    if assigned(context.connection) then
      if assigned(context.connection.iohandler) then
        SendScrambledLine(sLine);

end;

constructor TIRCConnection.Create;
begin
  inherited;
  lastseen := getticker;
end;

procedure TIRCConnection.Detach;
begin
  if detached then exit;

  Debug.Log('connection is going away.');


  inherited;


end;

procedure TIRCConnection.Disconnect;
begin
  if assigned(context) then
    if assigned(context.connection) then
      context.Connection.Disconnect;
end;

function TIRCConnection.FullIdent: string;
begin
  result := nick+'!'+user;
end;


procedure TIRCConnection.ircmsg(sCmd, sParams: string);
begin
  var sLine := sCmd;
  if sParams <> '' then
    sLine := sLine+' '+sParams;
  if assigned(context) then
    if assigned(context.connection) then
      if assigned(context.connection.iohandler) then
        SendScrambledLine(sLine);
end;

procedure TIRCConnection.msg_chan_to_specific_user_raw(chan: TIRCChannel;
  sRaw: string; sPreChan: string = '');
begin
  var sLine := ':system!system@system '+sPreChan+chan.name+' '+sRaw;
  SendScrambledLine(sLine);
  debug.log('>>ch>>'+sLine);
end;

procedure TIRCConnection.pinged;
begin
//  if sl.count > 1 then
//      con.send_generic_msg('PONG', [sl[1]],'pong')
//    else
  send_generic_msg('PONG', 'pong');
  lastseen := getticker;
end;

procedure TIRCConnection.privmsg(sTarget, sMessage, sFrom: string);
begin
  if sFrom = '' then
    sFrom := 'system!system@system';

  var sLine := ':'+sFrom+' PRIVMSG '+sTarget+' :'+sMessage;
  SendScrambledLine(sLine);
  debug.log('>>>>>'+sLine);
end;

function TIRCConnection.Scramblestring(s: string): string;
begin
  result := s;
  for var t:= low(s) to high(s) do begin
    case s[t] of #13, #10, #$58,#$5F: begin
      end else begin
      result[t] := char(ord(s[t]) xor $55);
      end;
    end;

  end;
end;

procedure TIRCConnection.SendScrambledLine(sLine: string);
begin
  if scramble then
    sline := ScrambleString(sLIne);

  context.Connection.IOHandler.DefStringEncoding := IndyTextEncoding_UTF8;
  context.Connection.IOHandler.WriteLn(sLine);

end;

procedure TIRCConnection.send_generic_msg(id: string; params: TArray<string>;
  sTrailer: string);
begin
  var sLine := id+' '+Nick+' ';
  for var t:= 0 to high(params) do begin
    sLine := sLine + params[t]+' ';
  end;
  sLine := sLine+':'+sTrailer;

  SendScrambledLine(sLine);
  debug.log('>>>>>'+sLine);
end;

function TIRCConnection.UnScrambleString(s: string): string;
begin
  result := SCrambleString(s);
end;

{ TIRCChannel }

procedure TIRCChannel.CloseLogFile;
begin
  var lck := Locki;
  logfile.Free;
  logfile := nil;
end;

constructor TIRCChannel.Create;
begin
  inherited;
  users := TSharedList<TIRCConnection>.create;


end;

procedure TIRCChannel.Detach;
begin
  if detached then exit;

  Users.free;
  Users := nil;
  inherited;

end;

procedure TIRCChannel.EchoNames(toCon: TIRCConnection);
begin
  var l := users.LockI;
  for var t:= 0 to users.count-1 do begin
    //:sniper.ny.us.abjects.net 353 panda-WEB2012R2-43862 = #mg-chat :lbws1999 +BRS72 +daniagatha +goldrak +AtomicFrost +LammMann +asdffdgdfg +bzzbrr usera0zG6bh2mh Marlin +icekold +tectec +fedorano +m0rn +bookerman  Process MovieWeb.exe (17676)
    toCon.cmdmsg('353 '+toCon.nick+' = '+name+' :'+users[t].nick);
  end;
  //:sniper.ny.us.abjects.net 366 panda-WEB2012R2-43862 #beast-xdcc :End of /NAMES list. Process MovieWeb.exe (17676)
  toCon.cmdmsg('366 '+toCon.nick+' '+name+' :END OF /NAMES list');
end;

procedure TIRCChannel.EchoWhoHere(toCon: TIRCConnection);
begin
  var l := users.LockI;
  var sUsers := '';
  for var t:= 0 to users.count-1 do begin
    //:sniper.ny.us.abjects.net 353 panda-WEB2012R2-43862 = #mg-chat :lbws1999 +BRS72 +daniagatha +goldrak +AtomicFrost +LammMann +asdffdgdfg +bzzbrr usera0zG6bh2mh Marlin +icekold +tectec +fedorano +m0rn +bookerman  Process MovieWeb.exe (17676)
    if t < users.count-1 then
      susers := susers + users[t].nick+' '
    else
      susers := susers + users[t].nick;
  end;
  toCon.cmdmsg('WHOHERE '+name+' '+sUsers);
end;

procedure TIRCChannel.EchoWhoHere_ToEveryone;
begin
  self.irc.idsrv.Contexts.LockList;
  try
  var l := users.locki;
  for var t := 0 to users.count-1 do begin
    var con := users[t];
    EchoWhohere(con);
  end;
  finally
    self.irc.idsrv.Contexts.UnlockList;
  end;
end;

procedure TIRCChannel.join(con: TIRCConnection);
begin
  var lck := users.locki;

  if not users.Has(con) then begin
    con.cmdmsg('JOIN :'+name, con.FullIdent);
    con.cmdmsg('332 '+con.nick+' '+name+' :Welcome...');
    con.cmdmsg('333 '+con.nick+' '+name+' not used 12341234');
//    con.msg_chan_to_specific_user_raw(self, '333', 'yourmom 123412341234');
  end;
  if users.Has(con) then
    exit;

  users.Add(con);
  EchoNames(con);
  NotifyJoined(con);

//  msg_everyone_in_channel(con,con.nick+' joined '+name+' there are now '+users.count.tostring+' users in this channel');

end;

procedure TIRCChannel.leave(con: TIRCConnection);
begin
  var empty := false;
  begin
    var lck := users.locki;
    if users.Has(con) then begin
      users.remove(con);
      NotifyLeft(con);
    end;
    empty := users.Count = 0;

  end;

  if empty then
    irc.channelempty(self);






end;

procedure TIRCChannel.LogToFile(confrom: TIRCConnection; sMSG: string);
begin
  var lck := LockI;
  OpenLogFile;//if not opened
  logfile.seek(0, soEnd);
  var from :string := ':';
  if confrom <> nil then
    from := confrom.nick+':';


  var bytes := StringToBytes(from+sMsg+NL);

  stream_guaranteewrite(logfile, @bytes[low(bytes)], length(bytes));

  CloseLogFile;





end;

procedure TIRCChannel.msg_everyone_in_channel(confrom: TIRCConnection; sMsg: string; bExcludeSelf: boolean = true);
begin
  LogToFile(confrom,sMsg);
  self.irc.idsrv.Contexts.LockList;
  try
  var l := users.locki;

  for var t := 0 to users.count-1 do begin
    var con := users[t];
    if (not bExcludeSelf) or (con<>conFrom) then
      con.channel_msg(conFrom, self,sMsg);

  end;
  finally
    self.irc.idsrv.Contexts.UnlockList;
  end;

end;

procedure TIRCChannel.NotifyJoined(con: TIRCConnection);
begin
  var l := users.locki;
  for var t := 0 to users.count-1 do begin
    users[t].cmdmsg('JOIN '+name+' '+con.nick, con.fullident);
  end;
end;

procedure TIRCChannel.NotifyLeft(con: TIRCConnection);
begin
  var l := users.locki;
  for var t := 0 to users.count-1 do begin
    users[t].cmdmsg('PART '+name+' '+con.nick,con.fullident);
  end;

end;

procedure TIRCChannel.OpenLogFile;
var
  fil: string;
begin
  var lck := Locki;
  if logfile <> nil then
    exit;
  fil := dllpath+'ChannelLogs\'+name+'.txt';
  forcedirectories(extractfilepath(fil));
  if not fileexists(fil) then begin
    logfile := TFileStream.Create(fil, fmCreate);
  end else begin
    logfile := TfileStream.Create(fil, fmOpenReadWrite+fmShareDenyNone);
  end;



end;

procedure TIRCChannel.privmsg_everyone_in_channel(confrom: TIRCConnection;
  sMsg: string);
begin
  LogToFile(confrom,sMsg);
  var l := users.locki;
  for var t := 0 to users.count-1 do begin
    users[t].privmsg(name, sMsg, confrom.fullident);
  end;
end;



initialization
debug.Log('Simple obfuscation: CAP='+SimpleOb('CAP'));
debug.Log('Simple obfuscation: NICK='+SimpleOb('NICK'));
debug.Log('Simple obfuscation: USER='+SimpleOb('USER'));
debug.Log('Simple obfuscation: PING='+SimpleOb('PING'));
debug.Log('Simple obfuscation: PONG='+SimpleOb('PONG'));
debug.Log('Simple obfuscation: NAMESX='+SimpleOb('NAMESX'));
debug.Log('Simple obfuscation: UHNAMES='+SimpleOb('UHNAMES'));
debug.Log('Simple obfuscation: JOIN='+SimpleOb('JOIN'));
debug.Log('Simple obfuscation: PART='+SimpleOb('PART'));
debug.Log('Simple obfuscation: NAMES='+SimpleOb('NAMES'));
debug.Log('Simple obfuscation: CHANL='+SimpleOb('CHANL'));
debug.Log('Simple obfuscation: PRIVMSG='+SimpleOb('PRIVMSG'));
debug.Log('Simple obfuscation: WHOHERE='+SimpleOb('WHOHERE'));
debug.Log('Simple obfuscation: DCC='+SimpleOb('DCC'));
debug.Log('Simple obfuscation: XDCC='+SimpleOb('XDCC'));
debug.Log('Simple obfuscation: RESUME='+SimpleOb('RESUME'));


end.
