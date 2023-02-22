unit ProgressStack;

interface

uses
  typex,systemx,betterobject,stringx, orderlyinit, helpers_array;


type
  TProgressHandle = class;//forward
  IProgressHandle = interface
    function GetStep: int64;
    function GetStepCount: int64;
    procedure SetStep(const Value: int64);
    procedure SetStepCount(const Value: int64);
    function GetStepCountD: double;
    function GetStepD: double;
    procedure SetStepCountD(const Value: double);
    procedure SetStepD(const Value: double);
    function GetStatus: string;
    procedure SetStatus(const Value: string);

    function PercentComplete: double;
    property StepD: double read GetStepD write SetStepD;
    property StepCountD: double read GetStepCountD write SetStepCountD;

    property Step: int64 read GetStep write SetStep;
    property StepCount: int64 read GetStepCount write SetStepCount;
    function o: TProgressHandle;
  end;
  TProgressHandle = class(TSharedObject, IProgressHandle)
  private
    function GetStep: int64;
    function GetStepCount: int64;
    procedure SetStep(const Value: int64);
    procedure SetStepCount(const Value: int64);
    function GetStepCountD: double;
    function GetStepD: double;
    procedure SetStepCountD(const Value: double);
    procedure SetStepD(const Value: double);
    function GetStatus: string;
    procedure SetStatus(const Value: string);
  public
    FStepD: double;
    FStepCountD: double;
    FStatus: string;
    function PercentComplete: double;
    property StepD: double read GetStepD write SetStepD;
    property StepCountD: double read GetStepCountD write SetStepCountD;
    property Status: string read GetStatus write SetStatus;
    property Step: int64 read GetStep write SetStep;
    property StepCount: int64 read GetStepCount write SetStepCount;
    function o: TProgressHandle;
  end;

  TProgressStack = class(TSharedObject)
  private
    progs: TArray<IProgressHandle>;
  public
    function BeginProgress: IProgressHandle;
    procedure EndProgress(p: IProgressHandle);
  end;




var
  GProgress: TProgressStack;

implementation

procedure oinit;
begin
  GProgress := TProgressStack.create;
end;

procedure ofinal;
begin
  Gprogress.free;
  GProgress := nil;
end;


{ TProgressStack }


{ TProgressHandle }

function TProgressHandle.GetStatus: string;
begin
  result := FStatus;
end;

function TProgressHandle.GetStep: int64;
begin
  result := round(FStepD)

end;

function TProgressHandle.GetStepCount: int64;
begin
  result := round(FStepCountD);
end;

function TProgressHandle.GetStepCountD: double;
begin
  result := FStepCountD;
end;

function TProgressHandle.GetStepD: double;
begin
  result := fStepd;
end;

function TProgressHandle.o: TProgressHandle;
begin
  result := self;
end;

function TProgressHandle.PercentComplete: double;
begin
  if stepcount = 0.0 then
    exit(0.0);
  result := Step/StepCount;

end;

procedure TProgressHandle.SetStatus(const Value: string);
begin

end;

procedure TProgressHandle.SetStep(const Value: int64);
begin
  FStepD :=value;

end;

procedure TProgressHandle.SetStepCount(const Value: int64);
begin
  FStepD := value;

end;

procedure TProgressHandle.SetStepCountD(const Value: double);
begin
  FStepCountD := value;
end;

procedure TProgressHandle.SetStepD(const Value: double);
begin
  FStepD := value;

end;

{ TProgressStack }

function TProgressStack.BeginProgress: IProgressHandle;
begin
  var ilock := LockI;
  result := TProgressHandle.create;
  setlength(progs,length(progs)+1);
  progs[high(progs)] := result;

end;

procedure TProgressStack.EndProgress(p: IProgressHandle);
begin
  var ilock := LockI;
  TArray_Helper.Remove<IProgressHandle>(progs,p, function (p1,p2: IProgressHandle): boolean begin
    result := p1.o = p2.o;
  end);

end;

initialization
  init.RegisterProcs('ProgressStack',oinit,ofinal,'');

end.
