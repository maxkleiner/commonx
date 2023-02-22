object dmMotherShip: TdmMotherShip
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 402
  Width = 778
  PixelsPerInch = 192
  object tmMainThread: TTimer
    OnTimer = tmMainThreadTimer
    Left = 302
    Top = 138
  end
end
