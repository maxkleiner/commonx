unit LeakHelper;


interface

{$IFDEF DEBUG_MEMORY_LEAKS}
uses
  FastMM5, SysUtils, stringx, systemx;
{$ENDIF}
procedure ReportMemoryLeaksToFile(sFileName: string; bSequential: boolean);



implementation

procedure ReportMemoryLeaksToFile(sFileName: string; bSequential: boolean);
{$IFNDEF DEBUG_MEMORY_LEAKS}
begin
//  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;
{$ELSE}
begin
  try
    if not bSequential then
      FastMM5.FastMM_LogStateToFile(sFileName)
    else begin
      var seq := 0;
      while true do begin
        var nuFile := slash(extractfilepath(sFileName))+extractFileName(sFileName)+'.'+stringx.PadString(seq.tostring,'0',8)+extractfileext(sFileName);
        if not fileexists(nufile) then begin
          ForceDirectories(extractfilepath(nufile));
          FastMM5.FastMM_LogStateToFile(nufile);
          break;
        end;
        inc(seq);
      end;
    end;
  except
  end;


end;
{$ENDIF}

end.
