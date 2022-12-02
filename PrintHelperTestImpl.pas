{$A8,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N+,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}
{$MINSTACKSIZE $00004000}
{$MAXSTACKSIZE $00100000}
{$IMAGEBASE $00400000}
{$APPTYPE GUI}
{$WARN SYMBOL_DEPRECATED OFF}
{$WARN SYMBOL_LIBRARY ON}
{$WARN SYMBOL_PLATFORM ON}
{$WARN UNIT_LIBRARY ON}
{$WARN UNIT_PLATFORM ON}
{$WARN UNIT_DEPRECATED ON}
{$WARN HRESULT_COMPAT ON}
{$WARN HIDING_MEMBER ON}
{$WARN HIDDEN_VIRTUAL ON}
{$WARN GARBAGE ON}
{$WARN BOUNDS_ERROR ON}
{$WARN ZERO_NIL_COMPAT ON}
{$WARN STRING_CONST_TRUNCED ON}
{$WARN FOR_LOOP_VAR_VARPAR ON}
{$WARN TYPED_CONST_VARPAR ON}
{$WARN ASG_TO_TYPED_CONST ON}
{$WARN CASE_LABEL_RANGE ON}
{$WARN FOR_VARIABLE ON}
{$WARN CONSTRUCTING_ABSTRACT ON}
{$WARN COMPARISON_FALSE ON}
{$WARN COMPARISON_TRUE ON}
{$WARN COMPARING_SIGNED_UNSIGNED ON}
{$WARN COMBINING_SIGNED_UNSIGNED ON}
{$WARN UNSUPPORTED_CONSTRUCT ON}
{$WARN FILE_OPEN ON}
{$WARN FILE_OPEN_UNITSRC ON}
{$WARN BAD_GLOBAL_SYMBOL ON}
{$WARN DUPLICATE_CTOR_DTOR ON}
{$WARN INVALID_DIRECTIVE ON}
{$WARN PACKAGE_NO_LINK ON}
{$WARN PACKAGED_THREADVAR ON}
{$WARN IMPLICIT_IMPORT ON}
{$WARN HPPEMIT_IGNORED ON}
{$WARN NO_RETVAL ON}
{$WARN USE_BEFORE_DEF ON}
{$WARN FOR_LOOP_VAR_UNDEF ON}
{$WARN UNIT_NAME_MISMATCH ON}
{$WARN NO_CFG_FILE_FOUND ON}
{$WARN MESSAGE_DIRECTIVE ON}
{$WARN IMPLICIT_VARIANTS ON}
{$WARN UNICODE_TO_LOCALE ON}
{$WARN LOCALE_TO_UNICODE ON}
{$WARN IMAGEBASE_MULTIPLE ON}
{$WARN SUSPICIOUS_TYPECAST ON}
{$WARN PRIVATE_PROPACCESSOR ON}
{$WARN UNSAFE_TYPE OFF}
{$WARN UNSAFE_CODE OFF}
{$WARN UNSAFE_CAST OFF}
{$WRITEABLECONST ON}
{$OPTIMIZATION OFF}
unit PrintHelperTestImpl;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Menus, StdCtrls, Buttons;

type
  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    Screen1: TMenuItem;
    Image1: TImage;
    estDLLCapture1: TMenuItem;
    DLLCaptureSpecificWindow1: TMenuItem;
    SpeedButton1: TSpeedButton;
    Timer1: TTimer;
    Memo1: TMemo;
    bitbtnCapture: TBitBtn;
    btnLaunch: TButton;
    OpenDialog1: TOpenDialog;
    procedure Capture1Click(Sender: TObject);
    procedure TestDLLCapture1Click(Sender: TObject);
    procedure SpeedButton1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SpeedButton1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure Timer1Timer(Sender: TObject);
    procedure bitbtnCaptureClick(Sender: TObject);
    procedure btnLaunchClick(Sender: TObject);
  private
    { Private declarations }
    IsCapturing: Boolean;
    FindCursor: HCursor;
    crFindCursor: TCursor;
    HWndCapture, LastWindowUnderCursor: HWnd;
  protected
    procedure MouseMove(Shift: TShiftState; X: Integer; Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X: Integer;
      Y: Integer); override;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses PrintHelperSampleForm, TlHelp32, afxCodeHook;

{$R *.dfm}

procedure ScreenShot(hWindow: HWND; bm: TBitmap);
var
  Left, Top, Width, Height: Word;
  R: TRect;
  dc: HDC;
  lpPal: PLOGPALETTE;
  PaletteSize: Integer;
begin
  {Check if valid window handle}
  if not IsWindow(hWindow) then Exit;
  {Retrieves the rectangular coordinates of the specified window}
  GetWindowRect(hWindow, R);
  Left := R.Left;
  Top := R.Top;
  Width := R.Right - R.Left;
  Height := R.Bottom - R.Top;

  bm.Width := Width;
  bm.Height := Height;
  {get the screen dc}
  DC := GetDC(0);
  if DC = 0 then
  begin
    Exit;
  end;
  {do we have a palette device?}
  if (GetDeviceCaps(dc, RASTERCAPS) and
    RC_PALETTE = RC_PALETTE) then
  begin
    PaletteSize := SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY));
    {allocate memory for a logical palette}
    GetMem(lpPal, PaletteSize);
    {zero it out to be neat}
    FillChar(lpPal^, PaletteSize, #0);
    {fill in the palette version}
    lpPal^.palVersion := $300;
    {grab the system palette entries}
    lpPal^.palNumEntries := GetSystemPaletteEntries(DC, 0, 256,
      lpPal^.palPalEntry);
    if (lpPal^.PalNumEntries <> 0) then
    begin
      {create the palette}
      bm.Palette := CreatePalette(lpPal^);
    end;
    FreeMem(lpPal, PaletteSize);
  end;
  {copy from the screen to the bitmap}
  BitBlt(bm.Canvas.Handle, 0, 0, Width, Height, DC, Left, Top, SRCCOPY);
  {release the screen dc}
  ReleaseDC(0, DC);
end;

procedure RemoteThread(RemoteInfo: Pointer); stdcall; forward;

procedure TForm1.btnLaunchClick(Sender: TObject);
var
  ExecFile: string;
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
begin
  if OpenDialog1.Execute then
    begin
      ExecFile := OpenDialog1.FileName;
      FillChar(StartInfo, SizeOf(TStartupInfo), 0);
      StartInfo.cb := SizeOf(TStartupInfo);
      CreateProcess(PChar(ExecFile), nil, nil, nil, False, 0, nil, nil, StartInfo, ProcInfo);
    end;
end;

procedure TForm1.Capture1Click(Sender: TObject);
var
  Wnd: THandle;
  Rect: TRect;
  W, H: Integer;
begin
  Wnd := Form2.Handle;
  GetWindowRect(Wnd, Rect);
  W := Rect.Right - Rect.Left;
  H := Rect.Bottom - Rect.Top;
  Image1.Width := W;
  Image1.Height := H;
  ClientHeight := H;
  ClientWidth := W;
  ScreenShot(Wnd, Image1.Picture.Bitmap);
end;

type
  TRemoteInfo = packed record
    MessageBox: function(hWnd: HWND; lpText, lpCaption: PChar; uType: UINT): Integer; stdcall;
    GetModuleHandle: function(lpModuleName: PChar): HMODULE; stdcall;
    pLoadLibrary: function(lpLibFileName: PChar): HMODULE; stdcall;
    GetProcAddress: function(hModule: HMODULE; lpProcName: LPCSTR): FARPROC; stdcall;
    ExitProcess: procedure(uExitCode: UINT); stdcall;
    User32: PChar;
    MessageBoxA: PChar;
    Text: PChar;
    Title: PChar;
    Button: Cardinal;
    CaptureWindow: PChar;
    CaptureModule: THandle;
  end;

  TGetModuleHandle = function(lpModuleName: PChar): HMODULE; stdcall;
  TLoadLibrary = function(lpLibFileName: PChar): HMODULE; stdcall;
  TGetProcAddress = function(hModule: HMODULE; lpProcName: LPCSTR): FARPROC; stdcall;

  TCaptureWindowInfo = packed record
    MessageBoxA: PChar;
    MessageBox: function(hWnd: HWND; lpText, lpCaption: PChar; uType: UINT): Integer; stdcall;
    pExitThread: procedure (ExitCode: DWORD); stdcall;
    pGetProcAddress: TGetProcAddress;
    pGetModuleHandle: TGetModuleHandle;
    pLoadLibrary: TLoadLibrary;
    lpModuleName: Pointer;
    lpProcName: Pointer;
    AWnd: THandle;
    AHelloMsg: Pointer;
    lpUser32, lpKernel, lpMessageBox, lpCaptureWindow, lpExitThread: Pointer;
    lpMessageBoxName, Text, Title: PChar;
    CaptureWindowDLL: PChar;
    CaptureModule: THandle;
    CaptureWindow: procedure (Wnd: HWnd); stdcall;
  end;

  TGetProcAddrExInfo = packed record
    pExitThread: Pointer;
    pGetProcAddress: Pointer;
    pGetModuleHandle: Pointer;
    lpModuleName: Pointer;
    lpProcName: Pointer;
  end;

//procedure that runs injected inside another process
procedure RemoteThread(RemoteInfo: Pointer); stdcall;
begin
  with TRemoteInfo(RemoteInfo^) do
  begin
    @MessageBox := GetProcAddress(GetModuleHandle(User32), MessageBoxA);
    if @MessageBox = nil then @MessageBox := GetProcAddress(LoadLibrary(User32), MessageBoxA);
    CaptureModule := LoadLibrary(CaptureWindow);
    Button := MessageBox(0, Text, Title, MB_YESNO);
  end;
end;

procedure CaptureWindowThread(RemoteInfo: Pointer); stdcall;
begin
  with TCaptureWindowInfo(RemoteInfo^) do
  begin
    @MessageBox := pGetProcAddress(pGetModuleHandle(lpUser32), MessageBoxA);
    if @MessageBox = nil then @MessageBox := pGetProcAddress(pLoadLibrary(lpUser32), MessageBoxA);
    MessageBox(0, Text, Title, MB_YESNO);
    @CaptureWindow := pGetProcAddress(pLoadLibrary(CaptureWindowDLL), lpCaptureWindow);
    if @CaptureWindow <> nil then
      CaptureWindow(AWnd);
    MessageBox(0, Text, Title, MB_YESNO);
    @pExitThread := pGetProcAddress(pGetModuleHandle(lpKernel), lpExitThread);
    pExitThread(0);
  end;
end;

procedure CaptureWindowEx(lpParameter: Pointer); stdcall;
begin
  asm int 3; end;
  with TCaptureWindowInfo(lpParameter^) do
    begin
      @MessageBox := pGetProcAddress(GetModuleHandle(lpUser32), MessageBoxA);
      if @MessageBox = nil then
        @MessageBox := pGetProcAddress(pLoadLibrary(lpUser32), MessageBoxA);
      MessageBox(0, Text, Title, MB_YESNO);
      CaptureModule := pLoadLibrary(CaptureWindowDLL);
    end;
end;

procedure TForm1.bitbtnCaptureClick(Sender: TObject);
const
  User32: PChar = 'user32';
  MessageBoxA: PChar = 'MessageBoxA';
  Title: PChar = 'afxCodeHook';
  Text: PChar = 'hello from notepad :)';
var
  CaptureWindowInfo: TCaptureWindowInfo;
  AWnd: THandle;
  NewProcessID, ProcessID, Process: Cardinal;
  P: string;
  RemoteInfo: TRemoteInfo;
begin
  P := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'PrintHelperDLL.dll';

  AWnd := HWndCapture;
  if AWnd <> 0 then
    begin
      FillChar(CaptureWindowInfo, SizeOf(CaptureWindowInfo), 0);
      FillChar(RemoteInfo, SizeOf(RemoteInfo), 0);
      GetWindowThreadProcessId(AWnd, ProcessID);
      NewProcessID := OpenProcess(PROCESS_ALL_ACCESS, False, ProcessID);
      Process := NewProcessID;
      InjectLibrary(NewProcessID, P);

      CaptureWindowInfo.pGetModuleHandle := GetProcAddress(GetModuleHandle('KERNEL32.DLL'), 'GetModuleHandleA');
      CaptureWindowInfo.pLoadLibrary := GetProcAddress(GetModuleHandle('KERNEL32.DLL'), 'LoadLibraryA');
      CaptureWindowInfo.pGetProcAddress := GetProcAddress(GetModuleHandle('KERNEL32.DLL'), 'GetProcAddress');
      CaptureWindowInfo.lpModuleName := InjectString(NewProcessID, PChar(P));
      CaptureWindowInfo.lpProcName := InjectString(NewProcessID, PChar('CaptureWindow'));
      CaptureWindowInfo.AHelloMsg := InjectString(NewProcessID, PChar('Hello world'));
      CaptureWindowInfo.lpUser32 := InjectString(NewProcessID, PChar('user32.dll'));
      CaptureWindowInfo.Text := InjectString(NewProcessID, Text);
      CaptureWindowInfo.Title := InjectString(NewProcessID, Title);
      CaptureWindowInfo.lpMessageBoxName := InjectString(NewProcessId, PChar('MessageBoxA'));
      CaptureWindowInfo.MessageBoxA := InjectString(NewProcessID, MessageBoxA);
      CaptureWindowInfo.lpCaptureWindow := InjectString(NewProcessID, 'CaptureWindow');
      CaptureWindowInfo.CaptureWindowDLL := InjectString(NewProcessID, PChar(P));
      CaptureWindowInfo.AWnd := AWnd;
      CaptureWindowInfo.lpKernel := InjectString(NewProcessID, 'KERNEL32.DLL');
      CaptureWindowInfo.lpExitThread := InjectString(NewProcessID, 'ExitThread');

      InjectThread(Process, @CaptureWindowThread, @CaptureWindowInfo, SizeOf(CaptureWindowInfo), True);
      UninjectLibrary(Process, P);
    end;
end;

type
  TWindowInfo = packed record
    Handle: THandle;
    Caption,
    ClassName: string;
    Style: Cardinal;
    Rect: TRect;
  end;

  TDisplayDC = class
  private
    FDC: HDC;
    FOldPen, FPen: HPEN;
  public
    constructor Create;
    procedure HighlightWindow(Window: HWND); 
    destructor Destroy; override;
  end;

var  DoBreak: Boolean = False;

procedure GetWindowInfo(HWnd: THandle; out WindowInfo: TWindowInfo);
var
  Len: Integer;
  Buffer: array[0..255] of Char;
begin
  WindowInfo.Handle := HWnd;
  FillChar(Buffer, SizeOf(Buffer), 0);
  Len := SendMessage(HWnd, WM_GETTEXTLENGTH, 0, 0);
  if Len = 0 then // SendMessage returns 0 on a TEdit
    Len := 4096;
  SetLength(WindowInfo.Caption, Len);
  SendMessage(HWnd, WM_GETTEXT, Len+1, Integer(PChar(WindowInfo.Caption)));
  SetString(WindowInfo.ClassName, Buffer, GetClassName(HWnd, Buffer, SizeOf(Buffer)));
  GetWindowRect(HWnd, WindowInfo.Rect);
  WindowInfo.Style := GetWindowLong(HWnd, GWL_STYLE);
end;

function IsMouseButtonDown(MouseButton: Integer): Boolean;
var
  Swapped: WordBool;
  Button: Integer;
begin
  Swapped := WordBool(GetSystemMetrics(SM_SWAPBUTTON));
  if Swapped then
    case MouseButton of
      VK_LBUTTON: MouseButton := VK_RBUTTON;
      VK_RBUTTON: MouseButton := VK_LBUTTON;
    end;
  Button := GetAsyncKeyState(MouseButton);
  Result := Button and $8000<>0;
end;

procedure TForm1.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  ChildWindow, WindowUnderCursor: HWND;
  DisplayDC: TDisplayDC;
  S: string;
  ScreenPoint: TPoint;
  WindowInfo: TWindowInfo;
begin
  if IsCapturing then
    begin
      ScreenPoint := Mouse.CursorPos;

      WindowUnderCursor := WindowFromPoint(ScreenPoint);
      if (WindowUnderCursor <> 0) and (WindowUnderCursor <> LastWindowUnderCursor) then
        ChildWindow := ChildWindowFromPoint(WindowUnderCursor, ScreenPoint);

      if WindowUnderCursor = LastWindowUnderCursor then
        exit;
      DisplayDC := TDisplayDC.Create;
      DisplayDC.HighlightWindow(WindowUnderCursor);

      if LastWindowUnderCursor<>0 then
        begin
          DisplayDC.HighlightWindow(LastWindowUnderCursor);
        end;

      DisplayDC.Free;
      LastWindowUnderCursor := WindowUnderCursor;

    Memo1.Lines.Clear;
    GetWindowInfo(WindowUnderCursor, WindowInfo);
    S := Format('Class Name: %s', [WindowInfo.ClassName]);
    Memo1.Lines.Add(S);
    Memo1.Lines.Add(Format('Style: %x', [WindowInfo.Style]));
    Memo1.Lines.Add(Format('Caption: %s', [WindowInfo.Caption]));
    end else inherited;
end;

procedure TForm1.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
  DisplayDC: TDisplayDC;
begin
  if IsCapturing then
    begin
      IsCapturing := False;
      Screen.Cursor := crDefault;
      Cursor := Screen.Cursor;
      Mouse.Capture := 0;

      if LastWindowUnderCursor <> 0 then
        begin
          DisplayDC := TDisplayDC.Create;
          DisplayDC.HighlightWindow(LastWindowUnderCursor);
          DisplayDC.Free;
          HWndCapture := LastWindowUnderCursor;
          LastWindowUnderCursor := 0;
        end;


    end else
  inherited;

end;

procedure TForm1.SpeedButton1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if IsCapturing then
    exit;
  if FindCursor = 0 then
    begin
      FindCursor := LoadCursor(HInstance, PChar(1));
      crFindCursor := Screen.CursorCount+1;
      Screen.Cursors[crFindCursor] := FindCursor;
    end;
  Screen.Cursor := crFindCursor;
  Cursor := Screen.Cursor;
// http://support.microsoft.com/kb/q135865/
  Mouse.Capture := Handle;
  IsCapturing := True;
  Timer1.Enabled := True;
end;

procedure TForm1.SpeedButton1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  MouseMove(Shift, X, Y);
end;

procedure TForm1.TestDLLCapture1Click(Sender: TObject);
var
  CaptureWindow: procedure(Wnd: HWnd); stdcall;
  Module: THandle;
begin
  Module := LoadLibrary('PrintHelperDLL.dll');
  @CaptureWindow := GetProcAddress(Module, 'CaptureWindow');
  CaptureWindow(Form2.Handle);
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
 KeyState: TKeyboardState;
 Shift: TShiftState;
 X, Y: Integer;
begin
  GetKeyboardState(KeyState);
  if KeyState[VK_CONTROL] and $80 <> 0 then
    begin
      DoBreak := True; X := 0; Y := 0;
      MouseMove(Shift, X, Y);
    end else
  DoBreak := False;
  if IsCapturing then
    if not IsMouseButtonDown(VK_LBUTTON) then
      begin
        MouseUp(mbLeft, [], 0, 0);
        Timer1.Enabled := False;
      end;
end;

{ TDisplayDC }

constructor TDisplayDC.Create;
begin
  FDC := CreateDC('DISPLAY', nil, nil, nil);
  SetROP2(FDC, R2_NOTXORPEN);
  FPen := CreatePen(PS_SOLID, 2, 0);
  FOldPen := SelectObject(FDC, FPen);
end;

destructor TDisplayDC.Destroy;
begin
  SelectObject(FDC, FOldPen);
  DeleteObject(FPen);
  DeleteDC(FDC);
  inherited;
end;

procedure TDisplayDC.HighlightWindow(Window: HWND); 
var
  R: TRect;
begin
  GetWindowRect(Window, R);
  Rectangle(FDC, R.Left, R.Top, R.Right, R.Bottom);
end;

end.
