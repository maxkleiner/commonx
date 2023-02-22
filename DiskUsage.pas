unit DiskUsage;

{$APPTYPE CONSOLE}

interface

uses
  SysUtils, tickcount,
  WBEMScripting_TLB,
  ActiveX, numbers,
  Stringx,
  Variants;


function GetPerformanceArray(wmiClass: string; wmiProperty: TArray<string>; wmiFieldFilter: string = '*'): Tarray<int64>;

function CalculateArrayDeltas(aOld,aNew: TArray<int64>; tmDelta: ticker): TArray<double>;


implementation

var
  Floc: TSWbemLocator= nil;
  FServices: ISWbemServices = nil;

function Gloc(): TSWbemLocator;
begin
  if FLoc = nil then begin
    Floc := TSWbemLocator.Create(nil);
  end;
  if FServices = nil then begin
      FServices := FLoc.ConnectServer('.', 'root\CIMV2' {'root\cimv2'}, '', '', '', '',
        0, nil);
  end;

  Exit(floc);

end;

function CalculateArrayDeltas(aOld,aNew: TArray<int64>; tmdelta: ticker): TArray<double>;
begin
  setlength(result, lesserof(length(aOld), length(aNew)));
  for var t := 0 to high(result) do
    result[t] := (aNew[t]-aOld[t])/tmdelta;

end;
function GetPerformanceArray(wmiClass: string; wmiProperty: TArray<string>; wmiFieldFilter: string = '*'): Tarray<int64>;
var
  Services: ISWbemServices;
  SObject: ISWbemObject;
  ObjSet: ISWbemObjectSet;
  SProp: ISWbemProperty;
  Enum: IEnumVariant;
  Value: Cardinal;
  TempObj: OLEVariant;
  SN: variant;
  i: integer;
begin
  setlength(result,0);
//  Result := '';
  i := 0;
  try
    try
      GLoc();
      Services := FServices;
      ObjSet := Services.ExecQuery('SELECT '+wmiFieldFilter+' FROM ' + wmiClass, 'WQL',
        wbemFlagReturnImmediately and wbemFlagForwardOnly, nil);
      Enum := (ObjSet._NewEnum) as IEnumVariant;
      if not VarIsNull(Enum) then
        try
          setlength(result,0);
          while Enum.Next(1, TempObj, Value) = S_OK do
          begin
            try
              SObject := IUnknown(TempObj) as ISWBemObject;
            except SObject := nil;
            end;
            TempObj := Unassigned;
            if SObject <> nil then
            begin
              for var tt := 0 to high(wmiProperty) do begin
                SProp := SObject.Properties_.Item(wmiProperty[tt], 0);
                SN := SProp.Get_Value;
                if not varIsNUll(SN) then begin
                  setlength(result,length(result)+1);
                  result[high(result)] := sn;
                end;
              end;
            end;
          end;
          SProp := nil;
        except
  //        Result := '';
        end
      else
        setlength(result,length(result));
  //      Result := '';
      Enum := nil;
      Services := nil;
      ObjSet := nil;
    finally
      //loc.free;
    end;
  except
    halt;
//    on E: Exception do
//      Result := e.message;
  end;
end;


initialization

finalization
  FServices := nil;
  if FLoc <> nil then
    FLoc.free;

end.
