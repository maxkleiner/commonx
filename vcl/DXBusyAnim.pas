unit DXBusyAnim;
{$R-}
interface


uses
  globalmultiqueue,simplequeue,debug, betterobject, advancedgraphics_dx, graphics, numbers, systemx, typex, better_colors, colorconversion, sysutils, D3DX9, pxl.types, tickcount, colorblending, windows;


const
  PROJECTILE_COUNT = 2500;
  PROJECTILE_DIMMING = 1;

const
  GRAV_POINT_TEST_CONST : TVector4 = (FX: 0; Fy: 0; Fz: 0; Fw: 0);
  GRAV_POINT_COUNT = 3;
  GRAV_HIGH = GRAv_POINT_COUNT-1;
  GRAV_POINT_CONST : array [0..GRAV_HIGH] of TVector4 = (
      (FX: 0;       Fy: -1;     Fz: 0; Fw: 1),
//      (FX: 0.666;   Fy: -0.666; Fz: 0; Fw: 1),
//      (FX: 1;       Fy: 0;      Fz: 0; Fw: 1),
      (FX: 0.666;   Fy: 0.666;  Fz: 0; Fw: 1),
//      (FX: 0;       Fy: 1;      Fz: 0; Fw: 1),
//      (FX: -0.666;  Fy: 0.666;  Fz: 0; Fw: 1),
//      (FX: -1;      Fy: 0;      Fz: 0; Fw: 1),
      (FX: -0.666;  Fy: -0.666; Fz: 0; Fw: 1)//,
//      (FX: 0;       Fy: 0;      Fz: 0; Fw: 1)
);


type
  TGravityPoint = record
    pos: TVector4;
    oldpos: TVector4;
    deltaFrameTimeInSeconds: single;
    function VacuumForce: TVector4;

    procedure Init;
    procedure Draw(canvas: TDX2D);
  end;

  TProjectile = class(TBetterobject)
  public
    pos: TVector4;
    Velocity: TVector4;
    canvas: TDX2D;
    belowground: boolean;
    c: TColor;
    a: single;
    sz: single;
    procedure Draw;
    procedure init;override;

  end;


  TValorDraw = class(TDX2d)
  private
    FLazy: boolean;
    procedure Update;
    procedure SetBusy(const Value: boolean);

  protected
    procedure Resize; override;
 public
    physicstime: single;
    grav_source: array[0..GRAV_HIGH] of TVector4;
    grav : array[0..GRAV_HIGH] of TGravityPoint;
    proj: array[0..PROJECTILE_COUNT-1] of TProjectile;
    Fbusy: boolean;
    status: Tarray<string>;
    progress: Tarray<TProgress>;
    bounceprogress: Tarray<TProgressF>;
    progfade: ticker;
    procedure CalcBounceProgress;
    PROCEDURE SyncProgcount(cnt: nativeint);
    procedure DoDraw; override;
    procedure LoadTextures; override;
    procedure Init; override;
    procedure UpdatePhysics(rDeltaTime: Cardinal); override;
    procedure UpdateCommandProgres(status: string; p: TProgress; idx, cnt: nativeint);
    procedure InitRandom;
    property Busy: boolean read FBusy write SetBusy;
    property Lazy: boolean read FLazy write FLazy;



  end;






implementation



{ TValorDraw }

procedure TValorDraw.CalcBounceProgress;
const
  YIN = 0.9;
  YANG = 1.0-YIN;
  FAST_YIN = 0.99;
  FAST_YANG = 1.0-FAST_YIN;
begin
  self.Lock;
  try
    for var t:= 0 to high(bounceprogress) do begin
      if (bounceprogress[t].stepcount <> progress[t].Stepcount)
      or (bounceprogress[t].step > progress[t].step)
      then begin
        bounceprogress[t].step := (progress[t].step);
        bounceprogress[t].stepcount := progress[t].stepcount;
      end else begin


        bounceprogress[t].step := (bounceprogress[t].step * YIN) + (progress[t].step * YANG);
        bounceprogress[t].stepcount := (bounceprogress[t].stepcount * YIN) + (progress[t].stepcount * YANG);
      end;
    end;
  finally
    unlock;
  end;

end;

procedure TValorDraw.DoDraw;
var
  x: integer;
  x1,y1,x2,y2: single;
  c: Tcolor;
  t: integer;
begin
  inherited;
  ClearScreen(0);

  SetIdentityBounds;


{$IFDEF DRAW_GRAV_POINTS}
  for t := 0 to high(grav) do begin
    grav[t].Draw(self);
  end;
{$ENDIF}

  BeginVertexBatch;
  for t := 0 to PROJECTILE_COUNT-1 do begin
    proj[t].Draw;
  end;
  EndVertexBatch;


  if busy or (progfade<>0) then begin
    if lazy then begin
      SetTexture(2);
      AlphaOp := aoStandard;
      Sprite(((BoundX2-BoundX1)/2)+BoundX1,((BoundY2-BoundY1)/2)+BoundY1, getticker/1000,clWhite,0.8,32);
    end;
    AlphaOp := aoAdd;

    BoundX1 :=0;
    BoundX2 :=1;
    SetTexture(-1);
    var proga := 1.0;
    if progfade<>0 then begin
      proga := greaterof(0.0,1.0-(gettimesince(progfade) /2000.0));

      if proga <= 0.0 then
        progfade := 0;
      if busy then
        proga := lesserof(1.0,1.0-proga);
    end;

    lock;
    boundy1 := length(bounceprogress);
    for var tt:=0 to high(bounceprogress) do
      Rectangle_Fill(0,tt,bounceprogress[tt].PercentComplete,24,clOrange,proga*0.5);
    SetTexture(0);
    for var tt:=0 to high(bounceprogress) do
      Rectangle_Fill(0,tt,bounceprogress[tt].PercentComplete,24,clWhite,proga);
    const prog_glow_size = 1*8;
    var prog_glow_X_size := ScaleScreenXtoGlobal(ScaleGlobalYtoScreen((prog_glow_size)));
    settexture(1);
    for var tt:=0 to high(bounceprogress) do
      Rectangle_Fill(bounceprogress[tt].PercentComplete-prog_glow_X_size,tt-prog_glow_size,bounceprogress[tt].PercentComplete+prog_glow_X_size,tt+prog_glow_size,clWhite,progfade);
    ResetText;
    alphaop := TAlphaOp.aoStandard;
    SetFont(0);
    for var tt:=0 to high(bounceprogress) do
      TextOut(status[tt],tt,2,clWhite,proga,1.0);
    unlock;
  end;

  SetIdentityBounds;




end;

procedure TValorDraw.Init;
var
  t: integer;
begin
  inherited;
  InitRandom;
  for t := 0 to PROJECTILE_COUNT-1 do begin
    proj[t] := TProjectile.Create;
    proj[t].pos.Init;
    proj[t].Velocity.init;
    proj[t].canvas := self;
   // projectile[t].vx := random(300);
    proj[t].pos.x := random(width);
    proj[t].pos.y := random(height);
    proj[t].c := (random($FFFF) shl 16)+random($FFFF);
  end;
end;

procedure TValorDraw.InitRandom;
begin
  for var t:= 0 to high(grav_source) do begin
    grav_source[t] := GRAV_POINT_CONST[t];
//    grav_source[t].x := (Random(200)/100)-1.0;
//    grav_source[t].y := (Random(200)/100)-1.0;

  end;
end;

procedure TValorDraw.LoadTextures;
begin
  inherited;
  LoadTexture('graphics\spark4.png');
  LoadTexture('graphics\spark2.png');
  LoadTexture('graphics\guitar_pick.png');
  LoadFont('graphics\font.png',2,2);//0


end;

procedure TValorDraw.Resize;
begin
  inherited;
  SetIdentityBounds;
  init;

end;

procedure TValorDraw.SetBusy(const Value: boolean);
begin
  if Fbusy = value then
    exit;
  FBusy := Value;

  progfade := getticker;
end;

procedure TValorDraw.SyncProgcount(cnt: nativeint);
begin
  lock;
  setlength(status,cnt);
  setlength(progress,cnt);
  setlength(bounceprogress,cnt);
  unlock;
end;

procedure TValorDraw.Update;
begin
  inherited;

end;

procedure TValorDraw.UpdateCommandProgres(status: string; p: TProgress; idx,
  cnt: nativeint);
begin
  lock;
  SyncProgCount(cnt);
  self.status[idx] := status;
  self.progress[idx] :=p;
  unlock;

end;

procedure TValorDraw.UpdatePhysics(rDeltaTime: Cardinal);
var
  t: integer;
begin
  inherited;
  CalcBounceProgress;
  var deltatimeinseconds: single := rDeltaTime / 1000;
  physicstime := physicstime + deltatimeinseconds;
  var center: pxl.types.TVector4;
  center.Init;
  center.w := 1;
  center.x := ((Self.BoundX2-Self.BoundX1)/2)+Self.BoundX1;
  center.y := ((Self.Boundy2-Self.Boundy1)/2)+Self.Boundy1;
  var busyfact := 0.01;
  if busy then busyfact := 0.1;
  var speed := busyfact*((1+sin((physicstime*1000)*0.0001))/2);

  //GRAV_POINTS are constant
  //we need a translation matrix to move them to the center
  var trans := TranslateMtx4(center);

  //we need a rotate matrix to rotate
  var rotate := RotateMtx4(Vector3(0,0,1), speed*physicstime);
  var squishY := ScaleMtx4(Vector3(1,SurfaceHeight/SurfaceWidth,1));


  //ram all the points through the composite matrix
  for t:= 0 to high(GRAV_SOURCE) do begin
    var size := (surfacewidth/4)*(((1.5+(sin((physicstime*1000)*0.0009)))/2){+(t/2)}); //((1+sin((physicstime*1000)*0.0005))/2);
    //we need a scale matrix to make it bigger or smaller
    var scale := ScaleMtx4(Vector3(size, size, size));

    //build the composite matrix, first scale, then rotate, then translate
    var composite := (scale * rotate * squishy) * trans;

    grav[t].oldpos := grav[t].pos;
    grav[t].pos := GRAV_SOURCE[t] * composite;
    if grav[t].deltaFrameTimeInSeconds = 0 then begin
      grav[t].oldpos := grav[t].pos;
    end;
    grav[t].deltaFrameTimeInSeconds := deltatimeinseconds;

//    grav[t].pos := grav[t].pos * trans;
  end;

//  ForX_QI_FAKE(0,projectile_COUNT,SIMPLE_BATCH_SIZE, procedure (idx: int64) begin
  for t := 0 to projectile_COUNT -1 do begin
    var p := proj[t];
    for var u := 0 to High(grav) do begin
      var g := grav[u];
      //each projectile is influenced by each gravity point

      //calculate distance from p->g
      var gravVector := g.pos-p.pos;
      var dist := gravVector.Length;
      gravVector.normalize;
//      if ((t=0) and (u=0)) then Debug.Log(diff.ToString);
      var attractionG : single := (1/((greaterof(0.0001,dist))))*8000*(greaterof(0.02,(lesserof(1.0,0.3+(sin((( (u/300) +(physicstime*3000))*0.00045){+((u)/11)}))))));;
      var attractionV : single := (1/(greaterof(0.0001,dist)))*8000*(greaterof(0.02,(lesserof(1.0,0.3+(sin((((u/200)+(physicstime*3000))*0.00045){+((u)/12)}))))));;
      p.a := attractionG/1000;
      if not busy then attractionG := attractionG * 0.1;
      if not busy then attractionV := attractionV * 0.1;
      var VacuumVector :=  ((g.VacuumForce*3.0));
      p.Velocity := p.Velocity + (gravVector * attractionG);
      p.Velocity := p.Velocity + (VacuumVector * attractionV);
      var range: integer := 64;
      var minus: integer := 32;
      var rnd: TVector4 := Vector4(random(range)-minus, random(range)-minus, 0.0, 0.0);
//      p.velocity := p.velocity + rnd;


    end;
    var terminal: single := 1500.0;
    if p.velocity.Length > terminal then
        p.velocity := p.Velocity / (p.velocity.Length / terminal);

    if p.velocity.Length < 0-terminal then
        p.velocity := p.Velocity / (p.velocity.Length / (0-terminal));

    const DAMPENING = 0.2;
    var REV := 0-dampening;
    if lazy then
      rev := rev - (random(1000)/500);

    if (p.pos.x < boundX1) and (p.velocity.x < 0.0) then
      p.velocity := p.velocity * Vector4(REV,1.0,1.0,1.0);
    if (p.pos.x > boundX2) and (p.velocity.x > 0.0) then
      p.velocity := p.velocity * Vector4(REV,1.0,1.0,1.0);
//    if (p.pos.y < boundY1) and (p.velocity.y < 0.0) then
//      p.velocity := p.velocity * Vector4(1.0,REV,1.0,1.0);
    if (p.pos.y > boundY2) and (p.velocity.y > 0.0) then
      p.velocity := p.velocity * Vector4(1.0,REV,1.0,1.0);

    p.velocity := p.velocity + Vector4(0.0,1.0,0.0,0.0);



    p.pos := p.pos + (p.Velocity * deltatimeinSeconds);

//  end,[]);
  end;
end;

{ TProjectile }

procedure TProjectile.Draw;
begin
  canvas.settexture(0);
  canvas.AlphaOp := aoAdd;
  canvas.Sprite(pos.x,pos.y, colorblend(clBlack, c, ((velocity.length/(PROJECTILE_COUNT*PROJECTILE_DIMMING)))), 1.0, sz);

//  canvas.ResetText;
//  canvas.SetFont(0);
//  canvas.TextColor := c;
//  canvas.TextPosition.X := 0;
//  canvas.TextPosition.y := 0;
//  canvas.TextOffset := D3DXVector3(pos.x,pos.y,0);
//
//  canvas.canvas_Text('o');

end;


procedure TProjectile.init;
begin
  pos.init;
  Velocity.init;
  sz := random(96);
end;

{ TGravityPoint }

procedure TGravityPoint.Draw(canvas: TDX2D);
begin
//  exit;
  canvas.ResetText;
  canvas.SetFont(0);
  canvas.TextColor := clWhite;
  canvas.TextPosition.X := 0;
  canvas.TextPosition.y := 0;
  canvas.TextOffset := D3DXVector3(pos.x,pos.y,0);
  canvas.canvas_Text('x');
end;

procedure TGravityPoint.Init;
begin
  pos.Init;
end;

function TGravityPoint.VacuumForce: TVector4;
begin
  result := (pos-oldpos) *Self.deltaFrameTimeInSeconds;
  result.w := 0.0;



end;

end.
