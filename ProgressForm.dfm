object frmProgress: TfrmProgress
  Left = 215
  Top = 215
  Caption = 'Progress'
  ClientHeight = 740
  ClientWidth = 1311
  Color = clWindow
  Ctl3D = False
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -17
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  GlassFrame.SheetOfGlass = True
  Position = poMainFormCenter
  OnActivate = frmBaseActivate
  OnClose = frmBaseClose
  OnCreate = FrmBaseCreate
  OnDblClick = frmBaseDblClick
  OnDestroy = frmBaseDestroy
  Right = 1549
  Bottom = 1018
  ShowHardWork = False
  PixelsPerInch = 144
  DesignSize = (
    1311
    740)
  TextHeight = 20
  object lbl: TLabel
    Left = 12
    Top = 12
    Width = 1287
    Height = 49
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = #25628#32034#32034#24341'1'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -26
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    Transparent = True
    StyleElements = [seFont, seBorder]
  end
  object PB: TProgressBar
    Left = 10
    Top = 52
    Width = 1287
    Height = 33
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akTop, akRight]
    DoubleBuffered = False
    ParentDoubleBuffered = False
    Position = 100
    Smooth = True
    BarColor = clMaroon
    Step = 1
    TabOrder = 0
  end
  object panBG: TPanel
    Left = 12
    Top = 95
    Width = 1287
    Height = 635
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Caption = 'panBG'
    ParentBackground = False
    TabOrder = 1
    Visible = False
  end
  object TimerWatchCommand: TTimer
    Enabled = False
    Interval = 25
    OnTimer = TimerWatchCommandTimer
    Left = 192
  end
  object TimerWatchQueue: TTimer
    Enabled = False
    Interval = 25
    OnTimer = TimerWatchQueueTimer
    Left = 676
    Top = 120
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 24
    OnTimer = Timer1Timer
    Left = 432
    Top = 272
  end
  object Timer2: TTimer
    OnTimer = Timer2Timer
    Left = 448
    Top = 72
  end
  object TimerWatchList: TTimer
    Enabled = False
    Interval = 25
    OnTimer = TimerWatchListTimer
    Left = 388
    Top = 161
  end
end
