unit FatMessage;

interface

uses
  stringx, debug, Betterobject, systemx, linked_list, generics.collections, classes, sysutils, orderlyinit;

type
  TFatMessage = class(TBetterObject)
  public
    //if you add new members also update Copy() constructor
    //if you add new members also update Copy() constructor
    messageClass: string;
    params: TArray<String>;
    //if you add new members also update Copy() constructor
    //if you add new members also update Copy() constructor
    handled: boolean;
    p: TProc;
    function Copy: IHolder<TFatMessage>;
  end;

  TFatMessageQueue = class(TBetterObject)
  private
    sectSubQueues: TCLXCriticalSection;
    sectIncoming: TCLXCriticalSection;
    sectWorking: TCLXCriticalSection;
{$IFNDEF NOLINKED}
    incoming_list: TDirectlyLinkedLinkableList;
    working_list: TDirectlyLinkedLinkableList;
{$ELSE}
    incoming: TArray<IHolder<TFatMessage>>;
    working: TArray<IHolder<TFatMessage>>;
{$ENDIF}
    subqueues: TList<TFatMessageQueue>;
    FPause: boolean;
    function AssimilateIncoming: boolean;
    function GetNextMessage: IHolder<TFatMessage>;
    procedure Posted;virtual;
    procedure SetPause(const Value: boolean);
  public
    handler: TFunc<IHolder<TFatMessage>, boolean>;
    onposted: TProc;
    procedure QuickPost(sMessageClass: string);overload;
    procedure QuickPost(sMessageClass: string; a: Tarray<string>);overload;

    procedure Post(m: IHolder<TFatMessage>);//process later
    function Send(m: IHolder<TFatMessage>): boolean;//send through hierarchy... like a broadcast, but synchronous, stops when handled
    procedure Broadcast(m: IHolder<TFatMessage>);//post copies into hierarchy
    function ProcessNextMessage: boolean;
    function NewSubQueue: TFatMessageQueue;
    procedure DeleteSubQueue(fmq: TFatMessageQueue);
    constructor Create; override;
    procedure Detach; override;
    function NewMessage: IHolder<TFatMessage>;
    procedure QuickBroadcast(messageClass: string);overload;
    procedure QuickBroadcast(messageClass: string; params: TArray<String>);overload;
    property pause: boolean read FPause write SetPause;

  end;


  TMainMessageQueue = class(TFatMessageQueue);



var
  MMQ:TMainMessageQueue = nil;
  MainMessageQueue: TMainMessageQueue = nil;



implementation



{ TFatMessageQueue }

function TFatMessageQueue.AssimilateIncoming: boolean;
begin
  ecs(sectWorking);
  try
    result := false;
    if tecs(sectIncoming) then
    try
      result := true;
      {$IFNDEF NOLINKED}
        if incoming_list.count = 0 then
          exit;
//        Debug.Log('Adding list with '+incoming_list.Count.tostring+' items');
        working_list.AddList(incoming_list);
        incoming_list.Clear;
//        Debug.Log('Working list now has '+working_list.Count.tostring+' items');
      {$ELSE}
      var base := length(working);
      setlength(working, length(working)+length(incoming));
      for var t := 0 to high(incoming) do begin
        working[t+base] := incoming[t];
      end;
      setlength(incoming,0);
      {$ENDIF}
    finally
      lcs(sectIncoming);
    end;
  finally
    lcs(sectWorking);
  end;
end;

procedure TFatMessageQueue.Broadcast(m: IHolder<TFatMessage>);
begin
  ecs(sectSubQueues);
  try
    //recursively broadcast a copy to subqueues (ultimately posts)
    for var t := 0 to subqueues.Count-1 do begin
      subqueues[t].Broadcast(m.o.copy);
    end;
  finally
    lcs(sectSubQueues);
  end;


  //post original (which might be a copy) to self
  Post(m);

end;

constructor TFatMessageQueue.Create;
begin
  inherited;
  ics(sectSubQueues, classname+'-sectSubQueues');
  ics(sectIncoming, classname+'-sectIncoming');
  ics(sectWorking, classname+'-sectWorking');
{$IFNDEF NOLINKED}
  incoming_list := TDirectlyLinkedLinkableList.create;
  working_list := TDirectlyLinkedLinkableList.create;
{$ENDIF}
  subqueues := TList<TFatMessageQueue>.create;

end;

procedure TFatMessageQueue.DeleteSubQueue(fmq: TFatMessageQueue);
begin
  ecs(sectSubQueues);
  try
    subqueues.remove(fmq);
    fmq.free;
    fmq := nil;
  finally
    lcs(sectSubQueues);
  end;
end;

procedure TFatMessageQueue.Detach;
begin
  if detached then exit;

{$IFNDEF NOLINKED}
  incoming_list.free;
  incoming_list := nil;
  working_list.free;
  working_list := nil;
{$ENDIF}


  subqueues.free;
  subqueues := nil;
  dcs(sectSubQueues);
  dcs(sectIncoming);
  dcs(sectWorking);
  inherited;

end;

function TFatMessageQueue.GetNextMessage: IHolder<TFatMessage>;
begin
  var assimilated := AssimilateIncoming;
  repeat
    result := nil;
    ecs(sectWorking);
    try
  {$IFDEF NOLINKED}
      if length(working)  = 0 then
        exit;

      result := working[0];
      for var t := 1 to high(working) do
        working[t-1] := working[t];

      setlength(working, length(working)-1);
  {$ELSE}
      if working_list.count  = 0 then
        exit;

      var res := working_list.First ;
      if res = nil then
        exit(nil);
      result := IHolder<TFatMessage>(res);
      working_list.Remove(res);
//      Debug.Log('removed item, now have '+commaize(working_list.count));
  {$ENDIF}
    finally
      lcs(sectWorking);
    end;
  until (result <> nil) or assimilated;
end;

function TFatMessageQueue.NewMessage: IHolder<TFatMessage>;
begin
  result := THolder<TFatMessage>.create;
  result.o := TFatMessage.create;
end;

function TFatMessageQueue.NewSubQueue: TFatMessageQueue;
begin
  ecs(sectSubQueues);
  try
    result := TFatMessageQueue.create;
    subqueues.add(result);
  finally
    lcs(sectSubQueues);
  end;


end;

procedure TFatMessageQueue.Post(m: IHolder<TFatMessage>);
begin
  ecs(sectIncoming);
  try

  //queue must have an onposted handler in order to
  //accept posted messages, this is to prevent memory leaks due to
  //unprocessed message buildups
  //onposted simply notifies something (via mechanism of your choice) when
  //a message is available, the case of a queue for a form, it turns on a
  //timer
  //... could be a signal... etc...
  //queues that do not have this handler can still process synchronous messages
  //via send()
  if assigned(onposted) then begin
{$IFNDEF NOLINKED}
    incoming_list.Add(m);
    Posted;
{$ELSE}
    setlength(incoming, length(incoming)+1);
    incoming[high(incoming)] := m;
    Posted;
{$ENDIF}
  end;
  finally
    lcs(sectIncoming);
  end;

end;

procedure TFatMessageQueue.Posted;
begin
  if Assigned(onposted) then begin
    onposted();
  end;
end;

function TFatMessageQueue.ProcessNextMessage: boolean;
begin
  if pause then
    exit(false);
  result := false;
  var m := GetNextMessage;
  result := m <> nil;
  if not result then
    exit(false);//we didn't handle anything

  Send(m);

end;

procedure TFatMessageQueue.QuickBroadcast(messageClass: string;
  params: TArray<String>);
begin
  var m := MMQ.NewMessage;
  m.o.messageClass := messageClass;
  m.o.params := params;
  mmq.Broadcast(m);

end;

procedure TFatMessageQueue.QuickPost(sMessageClass: string; a: Tarray<string>);
begin
  var m : IHolder<TFatMessage> := THolder<TFatMessage>.create(TFatMessage.Create);
  m.o.messageclass := sMessageClass;
  m.o.params := a;
  self.Post(m);

end;

procedure TFatMessageQueue.QuickPost(sMessageClass: string);
begin
  var m : IHolder<TFatMessage> := THolder<TFatMessage>.create(TFatMessage.Create);
  m.o.messageclass := sMessageClass;
  self.Post(m);
end;

procedure TFatMessageQueue.QuickBroadcast(messageClass: string);
begin
  var m := MMQ.NewMessage;
  m.o.messageClass := messageClass;
  mmq.Broadcast(m);



end;

function TFatMessageQueue.Send(m: IHolder<TFatMessage>): boolean;
begin
  result := false;
  if assigned(handler) then begin
    result := handler(m);
  end;

  if not result then begin
    for var t := 0 to subqueues.count-1 do begin
      result := subqueues[t].Send(m) or result;
    end;
  end;

end;

procedure TFatMessageQueue.SetPause(const Value: boolean);
begin
  FPause := Value;
  if not value then
    onposted;

end;

{ TFatMessage }

function TFatMessage.Copy: IHolder<TFatMessage>;
begin
  result := THolder<TFatMessage>.create;
  result.o := TfatMessage.create;
  result.o.messageClass := self.messageClass;
  result.o.params := self.params;

end;

procedure oinit;
begin
  MainMessageQueue := TMainMessageQueue.create;
  MMQ := MainMessageQueue;

end;

procedure ofinal;
begin
  MainMessageQueue.free;
  MainMessageQueue := nil;
  MMQ := MainMessageQueue;

end;

initialization

init.RegisterProcs('FatMessage', oinit, ofinal, 'BetterObject');


end.
