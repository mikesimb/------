program DrawIcon;

uses
  Forms,
  Unit1 in 'Unit1.pas' {IconFrm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TIconFrm, IconFrm);
  Application.Run;
end.
