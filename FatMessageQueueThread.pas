unit FatMessageQueueThread;

interface

uses
  betterobject, managedthread, fatmessage;

type
  TFatMessageQueueThread = class(TManagedThread)
  protected
    mq: TFatMessageQueue;
    procedure DoExecute; override;
    function HandleMessage(msg: IHolder<TFatMessage>): boolean;virtual;
  public
    procedure InitFromPool; override;
    procedure PrepareForPool; override;
  end;


implementation

{ TFatMessageQueueThread }

procedure TFatMessageQueueThread.DoExecute;
begin
  inherited;
  RunHot := false;
  while mq.ProcessNextMessage do ;
  ColdRuninterval := 500;//TODO 1: Improve! There might be a rare chance that messages are in a cold queue


end;

function TFatMessageQueueThread.HandleMessage(
  msg: IHolder<TFatMessage>): boolean;
begin
  //handle message can be called from multiple thread contexts
  //depending on if a message comes in through Send() or Post()
  //POSTED messages are handled by this thread
  //but SENT messages might be in any thread context
  result := false;
end;

procedure TFatMessageQueueThread.InitFromPool;
begin
  inherited;
  Loop := true;
  mq := MMQ.NewSubQueue;
  mq.onposted := procedure
    begin
      RunHot := true;
      HasWork := true;
    end;

  mq.handler := function (msg: IHolder<TFatMessage>): boolean
    begin
      result := handleMessage(msg);
    end;


end;

procedure TFatMessageQueueThread.PrepareForPool;
begin
  MMQ.DeleteSubQueue(mq);

  inherited;

end;

end.
