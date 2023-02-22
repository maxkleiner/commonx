unit datalink;

interface

uses
  classes, db;

type
  TDataLink = record
    VarType: integer;
    DataSet: TDataSet;
    TableName: string;
    FieldName: string;
    Component: TComponent;
  end;

  PDataLInk = ^TDatalink;

implementation

end.
