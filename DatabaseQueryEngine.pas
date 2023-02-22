unit DatabaseQueryEngine;

interface

uses
  stringx,typex, systemx, sysutils;

function ApplyContextVariablesToQuery(FContext: string; q: string): string;

implementation


function ApplyContextVariablesToQuery(FContext: string; q: string): string;
begin
  if zpos('$#$', q) <0 then
    exit(q);

  var slh := ParseStringH(FContext,';');
  var sl := slh.o;


  result := q;
  for var t := 0 to sl.count-1 do begin
    var s := sl[t];
    var s1,s2: string;
    if SplitString(s, '=', s1,s2) then begin
      result := stringreplace(q, '$#$'+s1+'$#$', s2, [rfReplaceAll, rfIgnoreCase]);
    end;
  end;


end;

end.
