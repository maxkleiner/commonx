unit Checksum;

interface

function MD5File(const fileName : string) : string;

implementation

uses IdHashMessageDigest, idHash, classes, sysutils, systemx, stringx,
  multibuffermemoryfilestream, consolelock;

//returns MD5 has for a file
function MD5File(const FileName: string): string;
var
  IdMD5: TIdHashMessageDigest5;
  FS: TMultiBufferMemoryFileStream;
begin
//  LockConsole;
  try
   IdMD5 := TIdHashMessageDigest5.Create;
   FS := TMultiBufferMemoryFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
   try
     Result := IdMD5.HashStreamAsHex(FS)
   finally
     FS.Free;
     IdMD5.Free;
   end;
  finally
//    UnlockConsole;
  end;
end;

end.
