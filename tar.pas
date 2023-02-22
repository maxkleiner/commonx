unit tar;

interface

uses
  exe,typex,systemx, sysutils, stringx, dir, dirfile;

function UnTar(sFile: string; sDestDir: string): TArray<string>;

implementation

function UnTar(sFile: string; sDestDir: string): TArray<string>;
var
  fi: TFileInformation;
begin

  forcedirectories(sDestDir);
  exe.RunProgramAndWait('tar', '-x -f '+quote(sFile), sDestDir, true, true, false);
  var dir := TDirectory.create(sDestDir, '*.*',0,0,false);
  try
    result := dir.ToArray(true,false,false);
  finally
    dir.free;
  end;









end;

end.
