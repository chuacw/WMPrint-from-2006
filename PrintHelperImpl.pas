{$WRITEABLECONST ON}
{$OPTIMIZATION OFF}
unit PrintHelperImpl;

interface
uses Windows;

procedure CaptureWindow(Wnd: HWND); stdcall; export;

implementation
uses Messages, afxCodeHook, SysUtils;

type
   THookInfo = packed record
     syscallid: Cardinal;
     syscall: Pointer;
     case Integer of
       0: (syscallcode: array[0..4] of Byte);
       1: (Jmp: Byte; Addr: Cardinal);
   end;

   PThunkData = ^TThunkData;
   TThunkData = array[0..13] of Byte;
   TPaintHook = class(TObject)
   private
     //Thunk: array[0..13] of Byte;
     Thunk: PThunkData;
     OldProc: Integer;
     OldDC: Integer;

     FWnd: HWnd;
   public
     function WndProc(Wnd: HWND; Msg, WParam, LParam: Longint): Longint; virtual;
     constructor Create;
     function Within_WM_PRINT: Boolean;
     procedure Subclass(Wnd: HWnd);
     destructor Destroy; override;
     class function NewInstance: TObject; override;
     procedure FreeInstance; override;
   end;

const
  HookInfo_BeginPaint: THookInfo = (syscallid:0; syscall:nil);
  HookInfo_EndPaint: THookInfo = (syscallid:0; syscall:nil);
  WM_HOOKWindowProc: Integer = 0;
  WM_UNHOOKWindowProc: Integer = 0;

  syscall_BeginPaint: Cardinal = 0;
  pBeginPaint: Pointer = nil;
  syscall_EndPaint: Cardinal = 0;
  pEndPaint: Pointer = nil;

function GetTPaintHook(Wnd: HWnd; out PaintHook: TPaintHook): Boolean;
var
  P: Pointer;
begin
  P := Ptr(GetWindowLong(Wnd, GWL_WNDPROC)+5);
  Result := not IsBadCodePtr(P);
  try
    if Result then
      PaintHook := TPaintHook(P^);
  except
    PaintHook := nil;
    Result := False;
  end;
end;

function MyBeginPaintHook(Wnd: HWND; var lpPaint: TPaintStruct): HDC; export; stdcall;
var
  ValidPaintHook: Boolean;
  PaintHook: TPaintHook;
  callid: Cardinal;
  callproc: Pointer;
begin
  Result := 0; // To remove compiler warning
  ValidPaintHook := GetTPaintHook(Wnd, PaintHook);

  if ValidPaintHook and PaintHook.Within_WM_PRINT then
    begin
      FillChar(lpPaint, SizeOf(lpPaint), #0);
      lpPaint.hdc := PaintHook.OldDC;
      GetClientRect(Wnd, lpPaint.rcPaint);
      Result := PaintHook.OldDC;
    end else
    begin
      callid := HookInfo_BeginPaint.syscallid;
      callproc := HookInfo_BeginPaint.syscall;
      asm
        mov   eax, callid
        push  lpPaint
        push  Wnd
        call  callproc
        MOV   Result, EAX
      end;
    end;
end;

function MyBeginPaint(Wnd: HWND; var lpPaint: TPaintStruct): HDC; export; stdcall;
var
  ValidPaintHook: Boolean;
  PaintHook: TPaintHook;
begin
  Result := 0; // To remove compiler warning
  ValidPaintHook := GetTPaintHook(Wnd, PaintHook);

  if ValidPaintHook and PaintHook.Within_WM_PRINT then
    begin
      FillChar(lpPaint, SizeOf(lpPaint), #0);
      lpPaint.hdc := PaintHook.OldDC;
      GetClientRect(Wnd, lpPaint.rcPaint);
      Result := PaintHook.OldDC;
    end else
    begin
      asm
        mov   eax, syscall_BeginPaint
        push  lpPaint
        push  Wnd
        call  pBeginPaint
        MOV   Result, EAX
      end;
    end;
end;

function MyEndPaintHook(Wnd: HWND; const lpPaint: TPaintStruct): BOOL; export; stdcall; 
var
  ValidPaintHook: Boolean;
  PaintHook: TPaintHook;
  callid: Cardinal;
  callproc: Pointer;
begin
  Result := True;
  ValidPaintHook := GetTPaintHook(Wnd, PaintHook);

  if (not ValidPaintHook) or (not PaintHook.Within_WM_PRINT) then
  begin
    callid := HookInfo_EndPaint.syscallid;
    callproc := HookInfo_EndPaint.syscall;
    asm
      mov   eax, callid
      push  lpPaint
      push  Wnd
      call  callproc
      MOV   Result, EAX
    end;
  end;
end;

function MyEndPaint(Wnd: HWND; const lpPaint: TPaintStruct): BOOL; export; stdcall; 
var
  ValidPaintHook: Boolean;
  PaintHook: TPaintHook;
begin
  Result := True;
  ValidPaintHook := GetTPaintHook(Wnd, PaintHook);

  if (not ValidPaintHook) or (not PaintHook.Within_WM_PRINT) then
  asm
    mov   eax, syscall_EndPaint
    push  lpPaint
    push  Wnd
    call  pEndPaint
    MOV   Result, EAX
  end;
end;

function CalcJmpOffset(Src, Dest: Pointer): Longint;
begin
  Result := Longint(Dest) - (Longint(Src) + 5);
end;

function Hook(const Module, Proc: string;
  var HookInfo: THookInfo; const pNewProc: Pointer): Boolean; overload;
type
  PCardinal = ^Cardinal;
var
  TargetModule: THandle;
  flOldProtect: Cardinal;
begin
    TargetModule := GetModuleHandle(PChar(Module));
    HookInfo.syscall := GetProcAddress(TargetModule, PChar(Proc));

    if PByte(HookInfo.syscall)^ = $B8 then
      begin

          HookInfo.syscallid := PCardinal(Cardinal(HookInfo.syscall)+1)^;

          VirtualProtect(HookInfo.syscall, 5, PAGE_EXECUTE_READWRITE, flOldProtect);

          HookInfo.Jmp := PByte(HookInfo.syscall)^;
          HookInfo.Addr := PCardinal(Cardinal(HookInfo.syscall)+1)^;

          PByte(HookInfo.syscall)^ := $E9;
          PCardinal(Cardinal(HookInfo.syscall)+1)^ := CalcJmpOffset(HookInfo.syscall, pNewProc);

          HookInfo.syscall := Pointer(Cardinal(HookInfo.syscall) + 5);

          Result := True;
      end
    else
       Result := False;
end;

procedure Unhook(const HookInfo: THookInfo);
var
  P: Pointer;
begin
  P := Ptr(Cardinal(HookInfo.syscall)-5);

  PByte(P)^ := HookInfo.Jmp;
  PCardinal(Cardinal(P)+1)^ := HookInfo.Addr;
end;

function Hook(const Module, Proc: string; var syscall_id: Cardinal; var PProc: Pointer; const pNewProc: Pointer): Boolean; overload;
type
  PCardinal = ^Cardinal;
var
  TargetModule: THandle;
  flOldProtect: Cardinal;
begin
    TargetModule := GetModuleHandle(PChar(Module));

    pProc := GetProcAddress(TargetModule, PChar(Proc));

    if PByte(pProc)^ = $B8 then
      begin

          syscall_id := PCardinal(Integer(pProc) + 1)^;

          VirtualProtect(pProc, 5, PAGE_EXECUTE_READWRITE, flOldProtect);

          PByte(pProc)^ := $E9;
          // PCardinal(Integer(pProc)+1)^ := Integer(pNewProc);
          PCardinal(Integer(pProc)+1)^ := CalcJmpOffset(pProc, pNewProc);

          PProc := Pointer(Integer(PProc) + 5);

          Result := True;
      end
    else
       Result := False;
end;

function TPaintHook.Within_WM_PRINT: Boolean;
begin
    if IsBadWritePtr(@Thunk[0], 6) or IsBadReadPtr(@Thunk[0], 6) then
      Result := False
    else
    if (PWord(@Thunk[0])^ = $E959) and (PByte(@Thunk[6])^ = $E8) then
      Result := OldDC <> 0 else
      Result := False;
end;

destructor TPaintHook.Destroy;
var
  CurrentProc: Integer;
begin
  if OldProc <> 0 then
    begin
      CurrentProc := GetWindowLong(FWnd, GWL_WNDPROC);
      if CurrentProc = Integer(@Thunk[6]) then
        SetWindowLong(FWnd, GWL_WNDPROC, OldProc);
    end;
  inherited;
end;

class function TPaintHook.NewInstance: TObject;
begin
  Result := InitInstance(
  VirtualAlloc(nil, InstanceSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE));
end;

procedure TPaintHook.FreeInstance;
begin
  CleanupInstance;
  VirtualFree(Self, 0, MEM_RELEASE);
end;

function MyStdWndProc(Window: HWND; Message, WParam: Longint;
  LParam: Longint): Longint; stdcall; //assembler;
// 1, 2, 3, 4
var P: TPaintHook;
begin
  asm
    mov eax, [dword ptr ECX]  // ECX is Self!
    mov P,   eax
  end;
  Result := P.WndProc(Window, Message, WParam, LParam);
end;
{
asm
        PUSH    WParam  // PUSH 3
        PUSH    LParam  // PUSH 4
        MOV     ECX, Message
        MOV     EDX, Window
        MOV     EAX, [ECX] // Self

// Save Self
        MOV     ECX,[EAX]
        CALL    [ECX]
        ADD     ESP,12
        POP     EAX
end; }

const
  HookedPaintProcs: Boolean = False;

procedure HookPaintProcs(var Hooked: Boolean);
begin
  // Tested working...
  // Hook('USER32.DLL', 'BeginPaint', syscall_BeginPaint, pBeginPaint, @MyBeginPaint);
  // Hook('USER32.DLL', 'EndPaint',   syscall_EndPaint,   pEndPaint,   @MyEndPaint);
  if not Hooked then
    begin
      Hook(user32, 'BeginPaint', HookInfo_BeginPaint, @MyBeginPaintHook);
      Hook(user32, 'EndPaint', HookInfo_EndPaint, @MyEndPaintHook);
      Hooked := True;
    end;
end;

procedure UnhookPaintProcs(var Hooked: Boolean);
begin
  if Hooked then
    begin
      Unhook(HookInfo_BeginPaint);
      Unhook(HookInfo_EndPaint);
      Hooked := False;
    end;
end;

function TPaintHook.WndProc(
Wnd: HWND; Msg, WParam, LParam: Longint): Longint;
begin
  if Msg = WM_PRINTCLIENT then
    begin
      OldDC := WParam;
      Msg := WM_PAINT;
    end else
  if Msg = WM_HOOKWindowProc then
    begin
      // Hook Window Proc here
      HookPaintProcs(HookedPaintProcs);
      
      OldDC := 0;
      Result := 0;
      exit;
    end else
  if Msg = WM_UNHOOKWindowProc then
    begin
      // Unhook Window Proc here
      UnhookPaintProcs(HookedPaintProcs);

      OldDC := 0;
      Result := 0;
      exit;
    end;

  Result := CallWindowProc(Ptr(OldProc), Wnd, Msg, WParam, LParam);
  OldDC := 0;
end;

constructor TPaintHook.Create;
begin
   inherited Create;
   // HookPaintProcs(HookedPaintProcs);

   WM_HOOKWindowProc := RegisterWindowMessage('WM_PH_HPP1');
   WM_UNHOOKWindowProc := RegisterWindowMessage('WM_PH_HPP2');
   if (WM_HOOKWindowProc=0) and (WM_UNHOOKWindowProc=0) then
     HookPaintProcs(HookedPaintProcs);

{  asm
    mov Punk, offset @@Asm
    @@Asm:
    mov eax, [ecx]
    mov eax, [eax]
    push ecx // Self
    jmp dword [eax]
    nop;
  end; }
{  asm
     mov dword ptr Punk, offset @caller
     inc [Punk]
     @start: pop ecx
     @jmpinst:
     jmp MyStdWndProc
     @caller: call @start
  end; }
  Thunk := VirtualAlloc(nil, SizeOf(TThunkData), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  FillChar(Thunk[0], SizeOf(TThunkData), $FF);
  PWord(@Thunk[0])^ := $E959;  // @@ThisPop: pop ecx ($59); jmp ($E9) [relative] MyStdWndProc
  PPointer(@Thunk[2])^ := Ptr(CalcJmpOffset(@Thunk[1], @MyStdWndProc));
  PByte(@Thunk[6])^ := $E8;   // call @@ThisPop
  PPointer(@Thunk[7])^ := Ptr(CalcJmpOffset(@Thunk[11], @Thunk[5]));
  PPointer(@Thunk[11])^ := Self;  // Address of Self
{
  Thunk[0] := $B9;                        // mov ecx,
  PPointer(@Thunk[1])^ := @Self;          //         @Self
  PPointer(@Thunk[5])^ := Ptr($008B018B); // mov eax, ecx; jmp [eax]
  PPointer(@Thunk[9])^ := Ptr($9020FF51);
}
//  WndProc(1, 2, 3, 4);
//  TestWndProc(1, 2, 3, 4);
{  TestMyStdWndProc(1, 2, 3, 4);
  asm
    MOV EAX, Self
    PUSH EAX
  end;
  MyStdWndProc(1, 2, 3, 4); }
end;

// Hook BeginPaint and EndPaint when in the GUI thread.
// Doing it outside the GUI thread could be dangerous...
procedure TPaintHook.Subclass(Wnd: HWnd);
var
  PaintHook: TPaintHook;
begin
  FWnd := Wnd;
  OldProc := GetWindowLong(Wnd, GWL_WNDPROC);
//  SetWindowLong(Wnd, GWL_WNDPROC, Integer(@Thunk[0]));
  SetWindowLong(Wnd, GWL_WNDPROC, Integer(@Thunk[6]));

  if (WM_HOOKWindowProc<>0) and (WM_UNHOOKWindowProc<>0) then
    SendMessage(Wnd, WM_HOOKWindowProc, 0, 0);

  if GetTPaintHook(Wnd, PaintHook) then
    Assert(PaintHook=Self, 'Logic error');
end;

// It is not certain when CaptureWindow is called.
// It could be called either when subject application is inside or outside it's GUI thread, since
// CaptureWindow is called in athread injected into the subject application.
procedure CaptureWindow(Wnd: HWND);
var
  hook: TPaintHook;
  DC, DCMem: HDC;
  Rect: TRect;
  Bmp: HBitmap;
  OldGDIObject: HGDIOBJ;
begin
  Hook := TPaintHook.Create;
  OutputDebugString(PChar(Format('BeginPaint at: %p', [@MyBeginPaintHook])));
  OutputDebugString(PChar(Format('EndPaint at: %p', [@MyEndPaintHook])));
  OutputDebugString(PChar(Format('Kernel BeginEndPaint at: %p', [@BeginPaint])));
  OutputDebugString(PChar(Format('Kernel EndPaint at: %p', [@EndPaint])));
  OutputDebugString(PChar(Format('MyStdWinProc at: %p', [@MyStdWndProc])));
  Hook.SubClass(Wnd);

  DCMem := CreateCompatibleDC(0);

  GetWindowRect(Wnd, Rect);

  DC := GetDC(Wnd);
  Bmp := CreateCompatibleBitmap(DC, rect.right - rect.left, rect.bottom - rect.top);
  ReleaseDC(Wnd, DC);

  OldGDIObject := SelectObject(DCMem, Bmp);
  SendMessage(Wnd, WM_PRINT, DCMem, PRF_CHILDREN or PRF_CLIENT or PRF_ERASEBKGND or PRF_NONCLIENT or PRF_OWNED);

  if (WM_HOOKWindowProc<>0) and (WM_UNHOOKWindowProc<>0) then
    SendMessage(Wnd, WM_UNHOOKWindowProc, 0, 0);

  SelectObject(DCMem, OldGDIObject);
  DeleteObject(DCMem);

  OpenClipboard(Wnd);
 
  EmptyClipboard;
  SetClipboardData(CF_BITMAP, Bmp);
  CloseClipboard;

  Hook.Free;
end;

end.
