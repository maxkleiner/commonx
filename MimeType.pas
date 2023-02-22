unit MimeType;

interface

uses
  systemx, stringx, sysutils;

function MimeTypeFromExt(sExt: string): string;

implementation

function MimeTypeFromExt(sExt: string): string;
//Returns an appropriate mime-type for a given file extension.  For example
//".jpg" returns "image/jpeg".  For inclusion in HTTP headers.   Currently the
//following are defined.<BR>
//.jpg: image/jpeg<BR>
//.swf: application/x-shockwave-flash<BR>
//.gif: image/gif<BR>
//.pdf: application/pdf<BR>
//.html: text/html<BR>
//.htm: text/html<BR>
//.mp3: audio/x-mpeg<BR>
//.lrm: application/encarta<BR>
//.exe: application/x-octet-stream<BR>
//.hqx: application/mac-binhex40<BR>
//.doc: application/msword<BR>
//.ica: application/x-ica<BR>
//<BR>
//Add new content types as necessary.

begin
  //Get the document extension
  sExt := lowercase(sExt);
  //Translate the document extension into the MIME type that corresponds
  //to it
  if sExt = '.svg' then begin
    result := 'image/svg+xml';
  end else
  if sExt = '.jpg' then begin
    result := 'image/jpeg';
  end else
  if sExt = '.png' then begin
    result := 'image/png';
  end else
  if sExt = '.swf' then begin
    result := 'application/x-shockwave-flash';
  end else
  if sExt = '.gif' then begin
    result := 'image/gif';
  end else
  if sExt = '.pdf' then begin
    result := 'application/pdf';
  end else
  if sExt = '.html' then begin
    result := 'text/html';
  end else
  if sExt = '.ms' then begin
    result := 'text/html';
  end else
  if sExt = '.js' then begin
    result := 'text/javascript';
  end else
  if sExt = '.htm' then begin
    result := 'text/html';
  end else
  if sExt = '.htc' then begin
    result := 'text/x-component';
  end else
  if sExt = '.ts' then begin
    result := 'text/typescript';
  end else
  if sExt = '.mp3' then begin
    result := 'audio/x-mpeg';
  end else
  if (sExt = '.lrm') then begin
    result := 'application/encarta';
  end else
  if (sExt = '.exe') then begin
    result := 'application/octet-stream';
  end else
  if (sExt = '.css') then begin
    result := 'text/css';
  end else
  if (sExt = '.cab') then begin
    result := 'application/octet-stream';
  end else
  if (sExt = '.hqx') then begin
    result := 'application/mac-binhex40';
  end else
  if (sExt = '.doc') then begin
    result := 'application/msword';
  end else
  if (sExt = '.wml') then begin
    result := 'text/vnd.wap.wml';
  end else
  if (sExt = '.mp4') then begin
    result := 'video/mp4';
  end else
  if sExt = '.ica' then begin
    result := 'application/x-ica';
 end;
end;

end.
