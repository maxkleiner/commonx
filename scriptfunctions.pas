unit scriptfunctions;

interface

uses webscript,orderlyinit;
var
  sf: TScriptFunctions = nil;


implementation


procedure oinit;
begin
  sf := TScriptFunctions.create;

end;

procedure ofinal;
begin
  if assigned(sf) then
    sf.free;


end;

initialization
  init.RegisterProcs('scriptfunctions', oinit, ofinal);

finalization



end.
