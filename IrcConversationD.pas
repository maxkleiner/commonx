unit IrcConversationD;

interface

uses
  irc_abstract, systemx, typex, stringx, betterobject, classes, dirfile, sysutils, commandprocessor, debug;

type
  TChatConversationDaemon = class(TSharedObject)
  private
    FOnIRCConnected: TNotifyEvent;
    procedure DoSendHelpHEader;
  protected
    conversation: Iholder<TChatConversation>;
    irc: TChatMultiUserClient;
    FBackGroundCommands: TCommandList<TCommand>;
    procedure SendHelp();
    procedure SendHelpOverView();virtual;
    procedure SendHelpCommands();virtual;
    function GetConversation: TChatConversation;
    procedure SendHelpHeader;
    procedure SendHelpLine(sCommand, sParams, sHelp: string);
    procedure SendHelpFooter;
  public
    constructor Create(irc: TChatMultiUserClient; channel: string; inviteuser: string = ''); reintroduce;virtual;
    procedure Detach; override;
    function OnCommand(swhoFrom, sOriginalLine, sCmd: string; params: TStringList): boolean;virtual;
    procedure SayHello;virtual;
    procedure TestUTF8;
    property conv: TChatConversation read Getconversation;
    procedure CheckCommands;
    property OnIRCConnected: TNotifyEvent read FOnIRCConnected write FOnIRCConnected;
    procedure UserEnteredRoom(user: string); virtual;
    function MultiDate(dt: TDateTime): string;
  end;


implementation

{ TChatConversationDaemon }

procedure TChatConversationDaemon.CheckCommands;
begin
  if FBackgroundCommands = nil then
    exit;
//  Debug.Log('check commands');
  var locki: ILock := FBackGroundCommands.Locki;

  for var t := FBackGroundCommands.count-1 downto 0 do begin
//    Debug.Log('check '+inttostr(t));
    var c := FBackgroundCommands[t];
    if c.IsComplete then begin
      FBackgroundCommands.Remove(c);
      if c.Error then begin
        conv.PM('*OK* Error '+c.ClassName+' '+c.ErrorMessage);
      end else begin
        conv.PM('*OK* OK '+c.ClassName);
      end;
      c.Free;
      exit;
    end;
  end;

end;

constructor TChatConversationDaemon.Create(irc: TChatMultiUserClient; channel: string; inviteuser: string = '');
begin

  var origchannel := channel;
  var user := zcopy(channel,1,length(channel));
  if zcopy(channel,0,1) = '@' then
    channel := '.'+irc.nick+'@'+user;


  FBackGroundCommands := TCommandList<TCommand>.create;
  inherited Create;

  var firstcharS := zcopy(channel, 0,1);
  var firstchar := #0;
  if length(firstcharS) >0 then
      firstchar := firstcharS[STRZ];

  if not CharInSet(firstchar,['#','@','.']) then
    channel := '#'+channel;
  self.irc := irc;
  conversation := irc.NewConversation(channel);

//  conversation.o.fPeriodically := procedure begin
//    checkCommands;
//  end;
  conversation.o.OnPeriodically := checkcommands;

  conversation.o.fOnCommand := OnCommand;//


  if irc.WaitForState(irccsStarted) then begin
    try

      if zcopy(origchannel,0,1) = '@' then
        irc.invite(channel, user);
      SayHello;
      if assigned(FOnIRCConnected) then
        FOnIRCConnected(self);

    except
    end;
  end;

  conv.OnUserEntersRoom := procedure (user: string) begin
    self.UserEnteredRoom(user);
  end;


end;

procedure TChatConversationDaemon.Detach;
begin
  if detached then exit;

  FBackGroundCommands.CancelAll;
  FBackGroundCommands.WaitForAll_DestroyWhileWaiting;
  FBackGroundCommands.Free;
  FBackGroundCommands := nil;

  irc.EndConversation(conversation);
  conversation := nil;
  inherited;

end;

procedure TChatConversationDaemon.DoSendHelpHEader;
begin
  conversation.o.PrivMsg('Help for '+classname);

end;

function TChatConversationDaemon.GetConversation: TChatConversation;
begin
  result := conversation.o;
end;

function TChatConversationDaemon.MultiDate(dt: TDateTime): string;
begin
  var gmt := localtimetogmt(dt);
  var cst := localtimetogmt(dt-(6/24));
  var cdt := localtimetogmt(dt-(5/24));
  result := '`cE`'+datetimetostr(gmt)+'`cF` GMT | '+'`cD`'+datetimetostr(cdt)+'`cF` CDT | '+'`cC`'+datetimetostr(cst)+'`cF` CST'

end;

function TChatConversationDaemon.OnCommand(swhoFrom, sOriginalLine, sCmd: string;
  params: TStringList): boolean;
begin
  result := false;

  if not result then begin
    if sCmd = 'help' then begin
      SendHelp();
      exit(true);
    end else
    if sCmd = 'hello' then begin
      Sayhello;
    end;
    if sCmd = 'testutf8' then begin
      TestUTF8;
    end;
  end;
end;




procedure TChatConversationDaemon.SayHello;
begin
  var d: TDateTime;
  d := dirfile.GetFileDate(dllname);
  conversation.o.PMCon('`c9``b0`  _    _      _ _        `n`');
  conversation.o.PMCon('`cA``b0` | |  | |    | | |       `n`');
  conversation.o.PMCon('`cB``b0` | |__| | ___| | | ___   `n`');
  conversation.o.PMCon('`cC``b0` |  __  |/ _ \ | |/ _ \`n`');
  conversation.o.PMCon('`cD``b0` | |  | |  __/ | | (_) |`n`');
  conversation.o.PMCon('`cE``b0` |_|  |_|\___|_|_|\___/ `n`');
  conversation.o.PMCon('`cF``b0`                        `n`');

  conversation.o.PMCon('Hi from '+self.ClassName+' in '+extractfilename(dllname)+' dated '+MultiDate(d)+'`n`');

end;


procedure TChatConversationDaemon.SendHelp;
begin
  SendHelpHeader;
  SendHelpCommands;
  SendHelpFooter;
end;

procedure TChatConversationDaemon.SendhelpCommands;
begin
  SendHelpLine('hello', '','causes server to reply with "hello", essentially a ping');
  SendHelpLine('testutf8    ','','a test of utf8 encoding, if you get a bunch of ?s then utf8 is not supported currently');

end;

procedure TChatConversationDaemon.SendHelpFooter;
begin
    conv.PM(ESCIRC+'</table>');
    conv.PM(ESCIRC+'<span color=red>To Send a command, type ! followed by the command name, space, and params (if applicable)</span>');

end;

procedure TChatConversationDaemon.SendHelpHeader;
begin
  conv.PMHold(ESCIRC+'<table><tr><th align=left colspan=3><h2>Help for '+classname+'</h2></th></tr>');
  conv.PMHold(ESCIRC+'<tr><th align=left>Command</th><th align=left>Params</th><th align=left>Details</th></tr>');
end;

procedure TChatConversationDaemon.SendHelpLine(sCommand, sParams, sHelp: string);
begin
//  conv.PM(ESCIRC+'<tr><td><b>'+sCommand+'</b></td><td>'+AmpEncode(sHelp)+'</td></tr>');
  conv.PMHold(ESCIRC+'<tr><td><b>'+sCommand+'</b></td><td><i>'+AmpEncode(sParams)+'</i></td><td>'+AmpEncode(sHelp)+'</td></tr>');

end;

procedure TChatConversationDaemon.SendHelpOverView;
begin
  //''
end;

procedure TChatConversationDaemon.TestUTF8;
begin
  conversation.o.PrivMsg(' ██░ ██ ▓█████  ██▓     ██▓     ▒█████');
  conversation.o.PrivMsg('▓██░ ██▒▓█   ▀ ▓██▒    ▓██▒    ▒██▒  ██▒');
  conversation.o.PrivMsg('▒██▀▀██░▒███   ▒██░    ▒██░    ▒██░  ██▒');
  conversation.o.PrivMsg('░▓█ ░██ ▒▓█  ▄ ▒██░    ▒██░    ▒██   ██░');
  conversation.o.PrivMsg('░▓█▒░██▓░▒████▒░██████▒░██████▒░ ████▓▒░');
  conversation.o.PrivMsg(' ▒ ░░▒░▒░░ ▒░ ░░ ▒░▓  ░░ ▒░▓  ░░ ▒░▒░▒░');
  conversation.o.PrivMsg(' ▒ ░▒░ ░ ░ ░  ░░ ░ ▒  ░░ ░ ▒  ░  ░ ▒ ▒░');
  conversation.o.PrivMsg(' ░  ░░ ░   ░     ░ ░     ░ ░   ░ ░ ░ ▒    ');
  conversation.o.PrivMsg(' ░  ░  ░   ░  ░    ░  ░    ░  ░    ░ ░    ');
end;

procedure TChatConversationDaemon.UserEnteredRoom(user: string);
begin
//   Debug.Log(user+' entered conversation room: '+conv.channel);
  if 0<>CompareText(user, irc.nick) then
    conv.PrivMsg('Hello '+user+'! I am a bot that is here to help you. Usually you can type !help to get help.');
  //
end;

end.
