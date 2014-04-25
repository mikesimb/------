object IconFrm: TIconFrm
  Left = 1405
  Top = 460
  BorderStyle = bsNone
  ClientHeight = 78
  ClientWidth = 104
  Color = clBlack
  TransparentColor = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnClick = FormDblClick
  OnCreate = FormCreate
  OnDblClick = FormDblClick
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object DrawTime: TTimer
    Enabled = False
    Interval = 400
    OnTimer = DrawTimeTimer
    Left = 40
    Top = 24
  end
end
