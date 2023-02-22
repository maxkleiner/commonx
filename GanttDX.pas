unit GanttDX;

interface


uses
  graphicsx,system.UITypes, debug, advancedgraphics_dx, typex, systemx, graphics, betterobject, maths, geometry, System.SysConst, types, classes, colorblending, colorconversion, tickcount, numbers, sysutils, better_colors, math, guihelpers, speech, d3dx9, windows, stringx, dxtypes, direct3d9_jedi, rtti_helpers, ganttdata;

//  windows, System.SysConst, system.UITypes, AdvancedGraphics_Dx, ganttdata, colorconversion, graphics, numbers, sysutils, messages;

type
  TRegion = record
    startpoint: single;
    endpoint: single;
    function Dif: single;
    function Center: single;
  end;


  TDXGantt = class(TDX2d)
  private
    FOnSelected: TNotifyEvent;
    function GetScreenFromHour(tm: TDatetime): double;
    function GetOptimalTimeLabelDistance: double;
  protected
    FMouseScrollStartXX,
    CurrentHistoryx1,
    CurrenthistoryX2,
    TargetHistoryX1,
    TargetHistoryX2: single;
    scrolldrag: TRegion;
    procedure DoMouseDown; override;
    procedure DoMouseUp;override;
    procedure DoMouseOver;override;
  public
    data: PGanttData;
    selectdrag: TRegion;

    procedure DoDraw; override;
    procedure ResetView;

    function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;override;
    function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean;override;
    procedure UpdatePhysics(rDeltaTime: Cardinal); override;
    procedure LoadTextures; override;
    function GetHourFromScreen(screenx: ni; portion: double = 1.0): double;

    property OnSelected: TNotifyEvent read FOnSelected write FOnSelected;
    procedure ZoomWayout;
  end;

implementation

{ TDXGantt }

procedure TDXGantt.DoDraw;
var
  rec: TGanttRecord;
begin
  inherited;
  ecs(datalock);
  try


    ClearScreen(clBlack);
    BoundX1 := CurrentHistoryX1;
    BoundX2 := CurrentHistoryX2;
    Boundy1 := 0;
    Boundy2 := lesserof(data.maxtrack*(1+(1/8)),1920);


    AlphaOp := aoAdd;






    PushBounds;
    try
      BeginVertexBatch;
      var mx:= self.data.GetLowerChartMax;
      try
        BoundY1 := 0;
        BoundY2 := mx*9;
        for var t := 0 to (24*60)-1 do begin
          var minuteStart := t/(24*60);
          var minuteEnd := (t+1)/(24*60);
          var r := data.GetMinuteSummaryForMinute(minuteStart).LowerChartvalue;
          var c := graphicsx.GetVUColorNarrow(r/INCIDENT_THRESHOLD);
          Rectangle_Fill(minuteStart,boundy2-r,minuteEnd, boundy2, c);
        end;
      finally
        EndVertexBatch;
      end;
      AlphaOp := aoStandard;
      SetFont(0);

      for var t := 0 to (24*60)-1 do begin
        var minuteStart := t/(24*60);
        var minuteEnd := (t+1)/(24*60);
        var r := data.GetMinuteSummaryForMinute(minuteStart).LowerChartvalue;
//        var c := graphicsx.GetVUColorNarrow(r/mx);
        if (r > INCIDENT_THRESHOLD) or ((r / mx) > 0.5) then
          TextOut(floatprecision(r,2), minutestart, boundy2-r, clWhite,0.9,1.0);
      end;

      var r := data.GetMinuteSummaryForMinute(data.GetLowerChartMaxMinute/(24*60)).UnfinishedRequests;
      TextOut(floatprecision(r,2)+' seconds avg (all touching)', data.GetLowerChartMaxMinute/(24*60), boundy2-r, clWhite,0.9,1.0);

    finally
      PopBounds;
      SetTexture(-1);
    end;



{$DEFINE DRAW_OPT}
{$IFDEF DRAW_OPT}
    var fx := greaterof(0,trunc(boundx1*(24*60)));
    var lx := lesserof(trunc(boundx2*(24*60))+1,1439);



    var fidx := 4000000000;
    var lidx := -1;

    if length(data.minutesummaries.minutes) >= 1440 then begin
      for var t := fx to lx do begin
         var nu := Self.data.minutesummaries.minutes[t].firstRecIndex;
        if (nu >=0) and (nu < fidx) then
          fidx := nu;

        nu := Self.data.minutesummaries.minutes[t].lastRecIndex;
        if (nu >=0) and (nu > lidx) then
          lidx := nu;


      end;
    end;

    if lidx > high(data.recs) then
      lidx := high(data.recs);
    if fidx > high(data.recs) then
      fidx := high(data.recs);
{$ELSE}
  var fidx := 0;
  var lidx := high(data.recs);
{$ENDIF}
//  Debug.log(commaize(fidx)+' - '+commaize(lidx));


  //---MAIN RECORDS
    AlphaOp := aoNone;
    BeginVertexBatch;
    try
      var recs := data.recs;
      var minwid := Self.ScaleScreenXtoGlobal(1);
      for var t  := fidx to lidx do begin
        rec := recs[t];
        if t > high(recs) then
          continue;
        var ts := recs[t].date-data.startday;
        var te := recs[t].runtimef;
  //      if te < 0.0001 then
  //        te := 0.0001;
        te := ts+te;
//        if ts > boundx2+(1/24) then
//          break;
//        if te < boundx1-(1/24) then
//          continue;

        //rec.track := 0;
        var sts: single := ts;
        var ste: single := te;
        if ScaleGlobalXtoScreen(te-ts) < 1 then
          ste := sts + minwid;

        Rectangle_Fill(sts, rec.track, ste, rec.track+1, rec.color,rec.color,rec.color,rec.color, 0.9);

      end;

    finally

      endVertexBAtch;
    end;
    AlphaOp := aoAdd;

      if data.selected <> nil then begin
        var a := (sin(getticker/50)+1.0)/2;
        rec := data.selected^;
        Rectangle(rec.date-data.startday, rec.track, rec.endtime-data.startday, rec.track+1, clWhite);
        Rectangle_Fill(rec.date-data.startday, rec.track, rec.endtime-data.startday, rec.track+1, clWhite,clBlue,clBlue,clRed, a);
      end;


    begin
      if selectdrag.endpoint >= 0 then
        Rectangle_Fill(selectdrag.startpoint, boundy1, selectdrag.endpoint, boundy2, clWhite, 0.3);
    end;

  //  BeginVertexBatch(D3DPT_LINELIST);
    var drawTimeSegs := procedure (period:double; c: TColor) begin
        if ScaleGlobalXtoScreen(period) > 5 then begin
          var lasthourplotted :double := -9999999;
          var t:double := 0;
          while t < 1 do begin
            var xx := t;
            self.BeginLine;
            self.DrawLine(xx, boundy1,c);
            self.DrawLine(xx, boundy2,c);
            self.EndLIne;

            t := t + period;
          end;
          FlushLine;
        end;
    end;

    drawTimeSegs(1/(24*60), $3f7f7f7f);
    drawTimeSegs(1/(24*4), $34fffff00);
    drawTimeSegs(1/24, $FFFfffff);







    SetFont(0);
    try
{$IFDEF OLD_TIME_WIDTHS}
      var lasthourplotted :double := -9999999;
      for var t := 0 to width-1 do begin
        var hour := GetHourFromScreen(t, 1);

        if t = 0 then begin
          lasthourplotted := hour;
          continue;
        end;

        if hour <> lasthourplotted then begin
          var xx := screenToGlobalX(t);
          var sDate := DateTimeToStr(data.startday+(hour/24));
          TextOut(sDate, xx, (BoundY1+BoundY2)/2, [tfShadow, tfStroke]);
          lasthourplotted := hour;

        end;
      end;
{$ELSE}
      var optwid := self.GetOptimalTimeLabelDistance;
      var tmX :double := greaterof(0,trunc(boundx1/optwid)*optwid);
      BeginVertexBatch;
      while tmX < lesserof(boundx2,1.0) do begin
        var sDate := FormatDatetime('hh:nn:ss ampm', data.startday+tmX);
        TextOut(sDate, tmX, (BoundY1+BoundY2)/2, [tfShadow, tfStroke]);
        tmX := tmX+optwid;

      end;
      EndVertexBatch;
{$ENDIF}
    finally
    end;

    begin
      if data.selected <> nil then begin
        rec := data.selected^;
        TextPosition.x := 0;
        TextPOsition.y := 0;
        ResetText;
        SetFont(0);

        canvas_Text(CRLF+CRLF+CRLF+'Selected:'+CRLF,[tfStroke]);
        canvas_Text('URL: '+rec.head+CRLF);
        canvas_Text('agent: '+rec.useragent+CRLF);
        canvas_Text('Start: '+datetimetostr(rec.date)+CRLF);
        canvas_Text('Runtime: '+floatprecision(rec.runtime/1000,2)+' seconds.'+CRLF);
        canvas_Text('Size: '+commaize(rec.sz)+CRLF);
        canvas_Text('ip: '+rec.ip+CRLF);

      end;
    end;
  finally
    lcs(datalock);
  end;


end;

procedure TDXGantt.DoMouseDown;
begin
  inherited;

  if MouseButtonChanged(1) then
  if mouse_buttons_down[1] then begin
//    data.hotstring := trunc(FLastMouseYY);
//    reg.startpoint := FLastMouseXX;
//    reg.endpoint := FLastMouseXX;
//    data.stringHistorySelection := reg;
    var searchAt  := mouse_last_pos_for_wheel;


    var x := ScreenToGlobalX(searchAt.x)+data.startday;
    var y := ScreenToGlobalY(searchAt.y);
    data.searchpoint(x,y);




    Mousehandled := true;
  end;

  if mouse_buttons_down[0] then begin
    scrolldrag.startpoint := (mouse_last_pos_for_wheel.x);
    ScrollDrag.endpoint := (mouse_last_pos_for_wheel.x);
    FMouseScrollStartXX := TargetHistoryX1;
    Debug.Log('Start = '+floatprecision(    scrolldrag.startpoint,8));
  end;

  if MouseButtonChanged(1) then
  if mouse_buttons_down[1] then begin
    var searchAt  := mouse_last_pos_for_wheel;
    selectdrag.startpoint := ScreenToGlobalX(searchAt.x);
    selectdrag.endpoint := selectdrag.startpoint;
    Debug.Log('Select Start = '+floatprecision(scrolldrag.startpoint,8));
  end;




end;

procedure TDXGantt.DoMouseUp;
begin
  inherited;
  if MouseButtonChanged(0) then
  if not mouse_buttons_down[0] then begin
//    scrolldrag.startpoint := (mouse_last_pos_for_wheel.x);
    ScrollDrag.endpoint := (mouse_last_pos_for_wheel.x);

  end;

  if MouseButtonChanged(1) then
  if not mouse_buttons_down[1] then begin
//    scrolldrag.startpoint := (mouse_last_pos_for_wheel.x);
    var searchAt  := mouse_last_pos_for_wheel;
    selectdrag.endpoint := ScreenToGlobalX(searchAt.x);
    if assigned(OnSelected) then
        OnSelected(self);
  end;




end;

function TDXGantt.DoMouseWheelDown(Shift: TShiftState;
  MousePos: TPoint): Boolean;
var
  w: nativefloat;
  x1,x2: nativefloat;
  c,cPercent: nativefloat;
begin
  inherited;
//  if data.mode = dmPickEngine then begin
    w := (TargetHistoryX2-TargetHistoryX1);
    if w = 0 then
      w := high(data.recs);
    cPercent := (ScreenToGlobalX(mouse_last_pos_for_wheel.x) - TargetHistoryX1) / w;
    c := ScreenToGlobalX(mouse_last_pos_for_wheel.x);

    w := w * 1.21;
    x1 := c - (w*cPercent);
    x2 := c + (w*(1-cPercent));
    TargetHistoryX1 := x1;
    TargetHistoryX2 := x2;
//  end;




  result := true;

end;


function TDXGantt.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;
var
  w: nativefloat;
  x1,x2: nativefloat;
  c,cPercent: nativefloat;
begin
  inherited;
//  if data.mode = dmPickEngine then begin
    w := (TargetHistoryX2-TargetHistoryX1);
    cPercent := (ScreenToGlobalX(mouse_last_pos_for_wheel.x) - TargetHistoryX1) / w;
    c := ScreenToGlobalX(mouse_last_pos_for_wheel.x);

    w := w / 1.15;
    x1 := c - (w*cPercent);
    x2 := c + (w*(1-cPercent));

    TargetHistoryX1 := x1;
    TargetHistoryX2 := x2;
//  end;

  result := true;

end;


function TDXGantt.GetHourFromScreen(screenx: ni; portion: double = 1.0): double;
begin
  var start := CurrentHistoryx1;
  result := ScreenToGlobalX(screenx);
  result := result * 24 * 1/portion;
  result := trunc(result);
  result := result / portion;

end;

function TDXGantt.GetOptimalTimeLabelDistance: double;
begin
  //6 hour
  result := 1/4;//every 6 hours

  if ScaleGlobalXToScreen(result) > 400 then
    result := 1/8;//every 3 hours

  if ScaleGlobalXToScreen(result) > 400 then
    result := 1/12;//every 2 hours

  if ScaleGlobalXToScreen(result) > 400 then
    result := 1/24;//every hour


  if ScaleGlobalXToScreen(result) > 400 then
    result := result / 2;//30 minutes

  if ScaleGlobalXToScreen(result) > 400 then
    result := result / 2;//15 minutes

  if ScaleGlobalXToScreen(result) > 600 then
    result := result / 3;//5 minutes

  if ScaleGlobalXToScreen(result) > 1200 then
    result := result / 5;//1 minute



end;

function TDXGantt.GetScreenFromHour(tm: TDatetime): double;
begin
  result := GlobalToScreenX(tm-trunc(tm));

end;

procedure TDXGantt.LoadTextures;
begin
  inherited;
  LoadFont   ('graphics\font.png',2,2);//0

end;

procedure TDXGantt.ResetView;
begin
  BoundX1 := 0;
  BoundX2 := 0.001;
  CurrentHistoryx1 := 0.0;
  CurrentHistoryx2 := 0.001;
  TargetHistoryX1 := 0.0;
  TargetHistoryX2 := 1.0;
end;


procedure TDXGantt.UpdatePhysics(rDeltaTime: Cardinal);
const
  aa = 0.1;
var
  a,b: double;
begin
  inherited;
  if rDeltaTime > 1000 then
    rDeltaTime := 1000;

  a := aa;
  b := 1.0-a;

  //btnPause.ColorWhenLit.FromColor(colorblend(clRed,clBlack,(getticker mod 333)));
//  HandleCalibrationState;

  CurrentHistoryX1 := {CLAMP}((CurrentHistoryX1 * (b)) + (TargetHistoryX1 * (a)){,0,HISTORY_SIZE});
  CurrentHistoryX2 := {CLAMP}((CurrentHistoryX2 * (b)) + (TargetHistoryX2 * (a)){,0,HISTORY_SIZE});

//  CurrentStringStart := (CurrentStringStart * (b)) + (TargetStringStart * (a));
//  CurrentStringEnd := (CurrentStringEnd * (b)) + (TargetStringEnd * (a));

end;

procedure TDXGantt.ZoomWayout;
begin
  TargetHistoryX1 := 0.0;
//  TargethistoryX2 := (60*60*24);
  TargetHistoryX1 := 0.0;
  TargetHistoryX2 := 1.0;

end;

procedure TDXGantt.DoMouseOver;
begin
  inherited;
  if mouse_buttons_down[0] then begin
    scrolldrag.endpoint := (mouse_last_pos_for_wheel.x);
    var wid := TargetHistoryX2-TargetHistoryX1;
    var dif := scrolldrag.dif;
    dif := ScaleScreenXtoGlobal(dif,true);


    TargetHistoryX1 := FMouseScrollStartXX - dif;
    TargetHistoryX2 := TargetHistoryX1+wid;
//    Debug.Log('dif='+floatprecision(dif,8));

  end;
  if mouse_buttons_down[1] then begin
//    scrolldrag.startpoint := (mouse_last_pos_for_wheel.x);
    var searchAt  := mouse_last_pos_for_wheel;
    selectdrag.endpoint := ScreenToGlobalX(searchAt.x);
//    if assigned(OnSelected) then
//        OnSelected(self);
  end;


end;

{ TRegion }

function TRegion.Center: single;
begin
  result := ((endpoint-startpoint)/2)+startpoint;
end;

function TRegion.Dif: single;
begin
  result := endpoint-startpoint;

end;

end.
