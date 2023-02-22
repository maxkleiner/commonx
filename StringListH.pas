unit StringListH;

interface

uses
  betterobject, classes, debug;

type
  IStringList = interface
    procedure SetTextStr(const Value: string);
    function GetTextStr: string;
    property Text: string read GetTextStr write SetTextStr;
    procedure FreeIfNotInterface;
    function GetCount: Integer;
    property Count: integer read GetCount;
    function obj: TStringlist;
  end;

  TStringListEx = class(TStringList)
  public
    function obj(): TStringlist;
    procedure FreeIfNotInterface;

  end;


  TStringListExH = class(THolder<TStringList>, IStringList)
  private
    FO: TStringList;
  public
    constructor Create;override;
    destructor Destroy; override;

    property oi: TStringList read FO implements IStringList;
    procedure FreeIfNotInterface;

    function obj(): TStringList;

  end;




implementation

{ TStringListEx }

constructor TStringListExH.Create;
begin
  inherited;
  o := TStringlist.create;
end;


destructor TStringListExH.Destroy;
begin
  Debug.log('destroying '+classname);
  inherited;
end;

procedure TStringListExH.FreeIfNotInterface;
begin
{$IFDEF UNSAFE_STRINGLIST}
  free;
{$ENDIF}
end;

function TStringListExH.obj: TStringList;
begin
  result := o;
end;

{ TStringListEx }

procedure TStringListEx.FreeIfNotInterface;
begin
  Free;
end;

function TStringListEx.obj: TStringlist;
begin
  result := self;

end;

end.
