unit ProxyDefault;

interface

uses
  betterobject,classes, stringx;

function GetDefaultProxy: IHolder<TStringList>;

implementation

function GetDefaultProxy: IHolder<TStringList>;
begin
  result := stringtostringlisth('');
end;

end.
