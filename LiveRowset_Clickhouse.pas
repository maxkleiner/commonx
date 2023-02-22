unit LiveRowset_Clickhouse;

interface

uses
  liverowset, betterobject, systemx, stringx, sysutils, managedthread, commandprocessor, variants,
  typex,numbers,mysqlstoragestring, storageenginetypes, rdtpdb, classes;


type
  TLiveRowset_Clickhouse = class(TliveRowset)
  strict private
  private
  public
    no_standard_fields: boolean;

    procedure Commit;override;
    procedure Refresh;override;

  end;



implementation

{ TLiveRowset }

procedure TLiveRowset_Clickhouse.Commit;
begin
  rs.IterateAC(procedure (sl: TStringlist) begin
    var r:PSeRow := rs.GetRowStruct(rs.cursor);
    if r^.deletepending then begin
      sl.add(vartostr(rs[keyfield]));
    end;
  end,procedure (sl: TStringlist) begin
    provideclient.o.WriteQuery('alter table '+alter_table+' delete where '+keyfield+' in ('+unparsestring(',',sl)+')');
  end);

  rs.IterateAC(procedure (sl: TStringlist) begin
    var r :PSeRow := rs.GetRowStruct(rs.cursor);
    if r^.appended then begin
      if not no_standard_fields then begin
        rs.values[0,rs.cursor] := formatdatetime('YYYY-MM-DD',now());
        rs.values[1,rs.cursor] := gss(varDouble,now);
        rs.values[2,rs.cursor] := gss(varInt64,rs[keyfield]);
      end;
      sl.add('('+RowToValues_NoParens(rs, false)+')');
    end;
  end,procedure (sl: TStringlist) begin
    var q := 'insert into '+table+' values '+unparsestring(',',sl);
    provideclient.o.WriteQuery(q);
  end);


  rs.Iterate(procedure begin//USES CUR REC STUFF DON'T Multi-Thread
    var r :PSeRow := rs.GetRowStruct(rs.cursor);
    if not (r^.appended or r^.deletepending) then begin
      if r^.modded then begin
        if not no_standard_fields then begin
          rs.values[0,rs.cursor] := formatdatetime('YYYY-MM-DD',now());
          rs.values[1,rs.cursor] := gss(varDouble,now);
          rs.values[2,rs.cursor] := gss(varInt64,rs[keyfield]);
        end;
        var slh := NewStringListH;
        for var t := 0 to high(r^.vals) do begin
          if r^.mods[t] then begin
            var fname := rs.fielddefs[t].sname;
            slh.o.add(fname+'='+gvs(rs.CurRecordFieldsByIdx[t]))
          end;
        end;
        if slh.o.count > 0 then
          provideclient.o.writequery('alter table '+alter_table+' update '+unparsestring(',',slh.o)+' where '+keyfield+'='+gvs(rs[keyfield]));
      end;
    end;
  end);

  rs.Reset(false);
  halt;




end;


procedure TLiveRowset_Clickhouse.Refresh;
begin
  inherited;
end;

end.
