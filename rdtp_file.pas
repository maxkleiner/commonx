unit rdtp_file;

interface

uses
  classes, typex, types, systemx;

type
  TRemoteFileRec = record
    name: string;
    attributes: integer;
    dateUTC: TDateTime;
    path: string;
    size: int64;
  private
    function GetDate: TDateTime;
    procedure SetDate(const Value: TDateTime);

  public

    property Date: TDateTime read GetDate write SetDate;
  end;

  TRemoteFileArray = TArray<TRemoteFileRec>;


implementation

{ TRemoteFileRec }

function TRemoteFileRec.GetDate: TDateTime;
begin
  result := GMTtoLocalTime(dateUTC);
end;

procedure TRemoteFileRec.SetDate(const Value: TDateTime);
begin
  dateUTC := LocalTimeToGMT(value);
end;

end.
