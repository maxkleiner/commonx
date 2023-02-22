unit FormTotalDebug;
 
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, FormBase, FormBGThreadWatcher, Vcl.ComCtrls, FrameTotalDebug;

type
  TfrmTotalDebug = class(TfrmBase)
    procedure frmBaseCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
//    framDbg: TframTotalDebug;
    fram: TfrmBGThreadWatcher;
    procedure FirstActivation; override;

  end;

var
  frmTotalDebug: TfrmTotalDebug;

procedure ShowTotalDebug(par: TControl);

implementation

{$R *.dfm}

procedure ShowTotalDebug(par: TControl);
begin
  if frmTotalDebug = nil then
    frmTotalDebug := TfrmTotalDebug.create(par);

  frmTotalDebug.show;
end;

procedure TfrmTotalDebug.FirstActivation;
begin
  inherited;
  fram := TfrmBGThreadWatcher.create(self);
  fram.parent := self;
end;

procedure TfrmTotalDebug.frmBaseCreate(Sender: TObject);
begin
  inherited;

//  framDbg := TframTotalDebug.create(self);
//  framDbg.parent := self;
//  framDbg.align := alClient;
end;

end.
