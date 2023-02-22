object frmBase: TfrmBase
  Left = 0
  Top = 0
  Caption = 'Deploy'
  ClientHeight = 292
  ClientWidth = 405
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -3
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  Position = poScreenCenter
  Scaled = False
  OnClose = FormClose
  OnCloseQuery = FormCloseQuery
  OnCreate = FrmBaseCreate
  OnDestroy = FormDestroy
  OnPaint = FormPaint
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 4
  object tmAfterFirstActivation: TTimer
    Enabled = False
    Interval = 1
    OnTimer = tmAfterFirstActivationTimer
    Left = 64
    Top = 16
  end
  object tmDelayedFormSave: TTimer
    Enabled = False
    Interval = 4000
    OnTimer = tmDelayedFormSaveTimer
    Left = 176
    Top = 16
  end
  object tmFatMessage: TTimer
    Interval = 15
    OnTimer = tmFatMessageTimer
    Left = 272
    Top = 16
  end
  object tmCommandWait: TTimer
    Interval = 100
    OnTimer = tmCommandWaitTimer
    Left = 272
    Top = 176
  end
end
