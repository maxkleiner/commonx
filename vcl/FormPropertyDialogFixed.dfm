object frmPropertyDialogFixed: TfrmPropertyDialogFixed
  Left = 0
  Top = 0
  Caption = 'frmPropertyDialogFixed'
  ClientHeight = 542
  ClientWidth = 863
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  GlassFrame.Enabled = True
  GlassFrame.Bottom = 48
  OldCreateOrder = False
  DesignSize = (
    863
    542)
  PixelsPerInch = 96
  TextHeight = 13
  object btnOK: TButton
    Left = 699
    Top = 509
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = '&OK'
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object btnCancel: TButton
    Left = 780
    Top = 509
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = '&Cancel'
    ModalResult = 1
    TabOrder = 1
  end
end
