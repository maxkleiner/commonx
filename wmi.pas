unit wmi;

interface

//NOTE: REQUIRES COINITIALIZE

uses
  typex,
  classes, types,
  stringx,
  WbemScripting_TLB;


type
  TSystemTemperature = record
    instanceName: string;
    raw: integer;
    function TempC: single;
    function DebugString: string;
  end;


function GetSystemTemperatures: Tarray<TsystemTemperature>;



implementation

{ TSystemTemperature }

function TSystemTemperature.DebugString: string;
begin
  result := instanceName+': '+floatprecision(tempC,1)+'°C';
end;

function TSystemTemperature.TempC: single;
begin
  result := (raw-2732)/10;

end;

function GetSystemTemperatures: Tarray<TsystemTemperature>;
var
  WMIServices: ISWbemServices;
  Root       : ISWbemObjectSet;
  Item       : Variant;
  I          : Integer;
begin
  Writeln('Temperature Info');
  Writeln('----------------');

  WMIServices := CoSWbemLocator.Create.ConnectServer('127.0.0.1', 'root\WMI','', '', '', '', 0, nil);
  try
    Root  := WMIServices.ExecQuery('SELECT * FROM MSAcpi_ThermalZoneTemperature','WQL', 0, nil);

    setlength(result, root.count);

    for I := 0 to Root.Count - 1 do
    begin
      Item := Root.ItemIndex(I);
      result[i].instanceName := item.instancename;
      result[i].raw := item.currenttemperature;
    end;
  except
  end;

end;
end.
