program PrintHelperTest;

{$R 'FindCursor.res' 'FindCursor.rc'}

uses
  Forms,
  PrintHelperTestImpl in 'PrintHelperTestImpl.pas' {Form1},
  afxCodeHook in '..\AfxCodeHook\afxCodeHook.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
