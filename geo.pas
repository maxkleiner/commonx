unit geo;

interface

uses
  systemx, typex, storageEnginetypes, rdtpdb, stringx, mysqlstoragestring;


type
  TLatLon = record
    lat,lon: double;
    procedure init;
    function Abs: TLatLon;
  end;

function GetIPLocation(conn: TRDTPDB; ip: string): TLatLon;


implementation


function GetIPLocation(conn: TRDTPDB; ip: string): TLatLon;
begin
  var ipint := IPToInt32(ip);
  var rs := conn.readqueryh('select * from geoip where startip<='+gvs(ipint)+' and endip>='+gvs(ipint));


end;

{ TLatLon }

function TLatLon.Abs: TLatLon;
begin
  result.lat := system.abs(lat);
  result.lon := system.abs(lon);
end;

procedure TLatLon.init;
begin
  lat := 0;
  lon := 0;
end;

end.
