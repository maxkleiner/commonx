unit FormSecondaryDock;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FormBase, Vcl.ExtCtrls,typex, stringx, systemx, guihelpers;

type
  TfrmSecondaryDock = class(TfrmBase)
  private

  protected
    procedure Loaded; override;
    procedure Activate; override;
   { Private declarations }
  public
    { Public declarations }
    function PickSecondaryScreen: ni;
    procedure FirstActivation; override;
    function ShouldActivate: boolean;
    procedure UpdatePosition;


  end;

var
  frmSecondaryDock: TfrmSecondaryDock;

implementation

{$R *.dfm}

{ TfrmBase1 }

procedure TfrmSecondaryDock.Activate;
begin
  inherited;
  UpdatePosition;
end;

procedure TfrmSecondaryDock.FirstActivation;
begin
  inherited;
  updateposition;
end;

procedure TfrmSecondaryDock.Loaded;
begin
  inherited;
  UpdatePosition;
end;

function TfrmSecondaryDock.PickSecondaryScreen: ni;
begin
  result := GetIdealMonitor(miWidest);



end;

function TfrmSecondaryDock.ShouldActivate: boolean;
begin
  result := screen.monitorcount > 1;
end;

procedure TfrmSecondaryDock.UpdatePosition;
begin
  if screen.monitorcount > 1 then begin
    var mon := picksecondaryscreen;
    left := screen.monitors[mon].Left;
    top := screen.monitors[mon].top;
    width := screen.monitors[mon].width;
    height := screen.monitors[mon].height;
  end;
end;

end.
