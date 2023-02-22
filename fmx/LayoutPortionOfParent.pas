unit LayoutPortionOfParent;

interface

uses
  FMX.Layouts, classes, fmx.controls, types;


type
  TUseProportion = (upLeft, upTop, upWidth, upHeight);
  TUseProportions = set of TUseProportion;

  [ComponentPlatformsAttribute($FFFF)]
  TLayoutPortionOfParent = class(TLayout)
  private
    FUseProportions: TUseProportions;
    FProportionY: double;
    FProportionW: double;
    FProportionX: double;
    FProportionH: double;
    procedure SetUseProportions(const Value: TUseProportions);
    procedure SetProportionH(const Value: double);
    procedure SetProportionW(const Value: double);
    procedure SetProportionX(const Value: double);
    procedure SetProportionY(const Value: double);

  protected
    procedure DoRealign; override;
    procedure CalcNewBounds;
    procedure DoResized; override;

  public
    constructor Create(AOwner: TComponent); override;
  published
    property UseProportions: TUseProportions read FUseProportions write SetUseProportions;
    property ProportionX: double read FProportionX write SetProportionX;
    property ProportionY: double read FProportionY write SetProportionY;
    property ProportionW: double read FProportionW write SetProportionW;
    property ProportionH: double read FProportionH write SetProportionH;


  end;


procedure Register;

implementation

{ TLayoutPortionOfParent }

procedure TLayoutPortionOfParent.CalcNewBounds;
begin
  if parent=nil then
    exit;
  if not (parent is TControl) then
    exit;

  var parcontrol := parent as TControl;
  var parBounds := parcontrol.BoundsRect;


  var b := RectF(self.Left, self.Top, self.Width, self.Height);
  if upLeft in UseProportions then
    b.Left := parBounds.width *  ProportionX;
  if upWidth in UseProportions then
    b.Width := parBounds.width * ProportionW;
  if upTop in UseProportions then
    b.Top := parBounds.height * ProportionY;
  if upHeight in UseProportions then
    b.Height := parBounds.height * ProportionH;


  self.SetBounds(b.Left, b.Top, b.Width, b.Height);



end;

constructor TLayoutPortionOfParent.Create(AOwner: TComponent);
begin
  inherited;


  proportionX := 0.25;
  proportionY := 0.25;
  proportionW := 0.5;
  proportionH := 0.5;


end;

procedure TLayoutPortionOfParent.DoRealign;
begin
  inherited;




end;


procedure TLayoutPortionOfParent.DoResized;
begin
  inherited;
  CalcNewBounds;
end;

procedure TLayoutPortionOfParent.SetProportionH(const Value: double);
begin
  FProportionH := Value;
  CalcNewBounds;
end;


procedure TLayoutPortionOfParent.SetProportionW(const Value: double);
begin
  FProportionW := Value;
  CalcNewBounds;
end;

procedure TLayoutPortionOfParent.SetProportionX(const Value: double);
begin
  FProportionX := Value;
  CalcNewBounds;
end;

procedure TLayoutPortionOfParent.SetProportionY(const Value: double);
begin
  FProportionY := Value;
  CalcNewBounds;
end;

procedure TLayoutPortionOfParent.SetUseProportions(
  const Value: TUseProportions);
begin
  FUseProportions := Value;
  CalcNewBounds;
end;

procedure Register;
begin
   RegisterComponents('DigitalTundra',[TLayoutPortionOfParent]);

end;




end.
