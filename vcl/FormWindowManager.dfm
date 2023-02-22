object frmWindowManager: TfrmWindowManager
  Left = 0
  Top = 0
  Align = alLeft
  Caption = 'frmWindowManager'
  ClientHeight = 1166
  ClientWidth = 236
  Color = clBtnFace
  Constraints.MaxWidth = 260
  Constraints.MinHeight = 600
  Constraints.MinWidth = 254
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -17
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = menuWinMan
  WindowState = wsMaximized
  OnCreate = FrmBaseCreate
  OnDestroy = frmBaseDestroy
  Right = 259
  Bottom = 1263
  ShowHardWork = False
  PixelsPerInch = 144
  DesignSize = (
    236
    1166)
  TextHeight = 21
  object panwindows: TPanel
    Left = 12
    Top = 240
    Width = 217
    Height = 914
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Anchors = [akLeft, akTop, akRight, akBottom]
    BevelEdges = []
    BevelOuter = bvNone
    TabOrder = 0
  end
  object tmRearrange: TTimer
    Enabled = False
    Interval = 1
    OnTimer = tmRearrangeTimer
    Left = 48
    Top = 40
  end
  object menuWinMan: TMainMenu
    Left = 88
    Top = 104
    object Monitor1: TMenuItem
      Caption = '&View'
      object Monitor2: TMenuItem
        Caption = '&Monitor'
        OnClick = Monitor2Click
        object N11: TMenuItem
          Caption = '&1'
          OnClick = N51Click
        end
        object N21: TMenuItem
          Tag = 1
          Caption = '&2'
          OnClick = N51Click
        end
        object N31: TMenuItem
          Tag = 2
          Caption = '&3'
          OnClick = N51Click
        end
        object N41: TMenuItem
          Tag = 3
          Caption = '&4'
          OnClick = N51Click
        end
        object N51: TMenuItem
          Tag = 4
          Caption = '&5'
          OnClick = N51Click
        end
      end
    end
  end
end
