unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CommCtrl, GIFImage, IniFiles, ExtCtrls;

const
  C_CAPTION = 'DF498035-EAF3-441E-842E-98A6D64029FD';
  SE_DEBUG_PRIVILEGE = $14;

type
  TLVItem64 = packed record
    mask: UINT;
    iItem: Integer;
    iSubItem: Integer;
    state: UINT;
    stateMask: UINT;
    _align: LongInt;
    pszText: Int64;
    cchTextMax: Integer;
    iImage: Integer;
    lParam: LPARAM;
  end;

  TIconFrm = class(TForm)
    DrawTime: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormDblClick(Sender: TObject);
    procedure DrawTimeTimer(Sender: TObject);
  private
    { Private declarations }
    FGifImg: TGIFImage;
    FRunPath: String;
    FIconName: String;
    FIconExe: String;
    FIconExeParam: String;
    FPlayIconFile: String;
    FIconFiles: TStringList;

    FWin64: Boolean;
    FViewHandle: THandle;
    FViewProcess: THandle;

    procedure OnAppException(Sender: TObject; E: Exception);
  public
    { Public declarations }
    // 加载需要显示的图标资源
    function LoadIconFile(AFileName: String): Boolean;
    // 从配置文件获取图标相关配置信息
    function GetIconName(AIniFile: String): Boolean;
    // 运行图标对应的程序
    function RunApp(const AExe, AParam, APath: string; AFlags: Integer; AWait: Cardinal): THandle;
    // 获取桌面SysListView32控件的句柄
    function GetDesktopLvHand: THandle;
    // 初始化绘制准备
    procedure DoDrawIconBegin;
    // 绘制结束
    procedure DoDrawIconEnd;
    // 取绘制图标位置信息
    procedure DoDrawIcon;
    // 32位系统取位置
    function GetDeskIcon32(hDeskWnd: HWND; hProcess: THandle; strIconName: String; var lpRect: TRECT): Boolean;
    // 64位系统取位置
    function GetDeskIcon64(hDeskWnd: HWND; hProcess: THandle; strIconName: String; var lpRect: TRECT): Boolean;
    // 检测系统环境
    function IsWin64: Boolean; 
  end;

  // 提升程序应用级别
  function RtlAdjustPrivilege(Privilege: ULONG; Enable: BOOL; CurrentThread: BOOL; var Enabled: BOOL): DWORD; stdcall; external 'ntdll';

var
  IconFrm: TIconFrm;

implementation

{$R *.dfm}
//{$R GifRes.RES}              // 打包资源

function TIconFrm.IsWin64: Boolean;
var  
  Kernel32Handle: THandle;   
  IsWow64Process: function(Handle: Windows.THandle; var Res: Windows.BOOL): Windows.BOOL; stdcall;   
  GetNativeSystemInfo: procedure(var lpSystemInfo: TSystemInfo); stdcall;
  isWoW64: Bool;   
  SystemInfo: TSystemInfo;   
const  
  PROCESSOR_ARCHITECTURE_AMD64 = 9;   
  PROCESSOR_ARCHITECTURE_IA64 = 6;   
begin  
  Kernel32Handle := GetModuleHandle('KERNEL32.DLL');   
  if Kernel32Handle = 0 then  
    Kernel32Handle := LoadLibrary('KERNEL32.DLL');
  if Kernel32Handle <> 0 then  
  begin
    IsWOW64Process := GetProcAddress(Kernel32Handle,'IsWow64Process');   
    GetNativeSystemInfo := GetProcAddress(Kernel32Handle,'GetNativeSystemInfo');
    if Assigned(IsWow64Process) then  
    begin  
      IsWow64Process(GetCurrentProcess,isWoW64);   
      Result := isWoW64 and Assigned(GetNativeSystemInfo);   
      if Result then
      begin  
        GetNativeSystemInfo(SystemInfo);   
        Result := (SystemInfo.wProcessorArchitecture = PROCESSOR_ARCHITECTURE_AMD64) or  
                  (SystemInfo.wProcessorArchitecture = PROCESSOR_ARCHITECTURE_IA64);   
      end;   
    end  
    else Result := False;   
  end  
  else Result := False; 
end;

function TIconFrm.LoadIconFile(AFileName: String): Boolean;
begin
  Result := False;

  AFileName := FRunPath + AFileName;
  if FileExists(AFileName) then
    try
      FGifImg.PaintStop;
      FGifImg.Clear;
      Self.Repaint;

      FGifImg.LoadFromFile(AFileName);

      Result := True;
    except
    end;
end;

function TIconFrm.RunApp(const AExe, AParam, APath: string; AFlags: Integer; AWait: Cardinal): THandle;
var
  si: TStartupInfo;
  pi: TProcessInformation;
  sCmd: string;
begin
  FillChar(si, SizeOf(si), 0);
  si.cb := SizeOf(si);

  FillChar(pi, SizeOf(pi), 0);
  Result := 0;

  if AParam <> '' then
    sCmd := AnsiQuotedStr(AExe, '"') + ' ' + AParam
  else
    sCmd := AExe;

  if CreateProcess(nil, PChar(sCmd), nil, nil, false, AFlags, nil, Pointer(APath), si, pi) then
  begin
    CloseHandle(pi.hThread);
    Result := pi.hProcess;
    if AWait <> 0 then
      WaitForSingleObject(pi.hProcess, AWait);
  end;
end;

procedure TIconFrm.FormCreate(Sender: TObject);
var
  bEnabled: BOOL;
begin
  Application.OnException := OnAppException;
  FRunPath := ExtractFilePath(Application.ExeName);
  Self.Caption := C_CAPTION;
  FPlayIconFile := '';
  FIconFiles := TStringList.Create;

  FGifImg := TGifImage.Create;              // GIF显示组件
 // FGifImg.Transparent := True;

  SetWindowLong(Application.Handle, GWL_EXSTYLE, WS_EX_TOOLWINDOW);                  // 隐藏任务栏
  if not RtlAdjustPrivilege(SE_DEBUG_PRIVILEGE, true, false, bEnabled) = 0 then      // 提升特权级别
  begin
    Application.Terminate;
  end;

  FWin64 := IsWin64;                        // 取系统类型
  FViewHandle := GetDesktopLvHand;          // 取桌面SysListView32句柄
  if FViewHandle = 0 then
    Application.Terminate;

  windows.SetParent(Application.Handle, FViewHandle);
  DoDrawIconBegin;
end;

procedure TIconFrm.FormShow(Sender: TObject);
begin
  if GetIconName(FRunPath + 'user.ini') then
  begin
    DrawTime.Enabled := True;
  end
  else
    Application.Terminate;
end;

procedure TIconFrm.FormDestroy(Sender: TObject);
begin
  try
    RunApp(Application.ExeName, '', FRunPath, 0, 0);          // 如果异常，再把自已加载起来
  except
    DrawTime.Enabled := False;
    FIconFiles.Free;
    DoDrawIconEnd;
    FGifImg.Free;
  end;
end;

function TIconFrm.GetIconName(AIniFile: String): Boolean;
var
  vIni: TIniFile;
  sValue: String;
begin
  Result := False;
  if FileExists(AIniFile) then
  begin
    vIni := TIniFile.Create(AIniFile);
    try
      FIconExe := vIni.ReadString('DrawIcon', 'IconRun', '');
      FIconExeParam := vIni.ReadString('DrawIcon', 'IconRunParam', '');
      FIconName := vIni.ReadString('DrawIcon', 'IconName', '');

      sValue := vIni.ReadString('DrawIcon', 'IconMinFile', '');
      if Trim(sValue) <> '' then FIconFiles.Add(sValue);

      sValue := vIni.ReadString('DrawIcon', 'IconNormalFile', '');
      if Trim(sValue) <> '' then FIconFiles.Add(sValue);

      sValue := vIni.ReadString('DrawIcon', 'IconMaxFile', '');
      if Trim(sValue) <> '' then FIconFiles.Add(sValue);

      Result := (FIconFiles.Count > 0);
    finally
      vIni.Free;
    end;
  end;
end;

procedure TIconFrm.FormDblClick(Sender: TObject);
begin
  if FileExists(FIconExe) then
  begin
    RunApp(FIconExe, FIconExeParam, ExtractFilePath(FIconExe), 0, 0);
  end;
end;

procedure TIconFrm.DrawTimeTimer(Sender: TObject);
begin
  try
    try
      DoDrawIconBegin;
      DoDrawIcon;
      DoDrawIconEnd;
    except
    end;
  finally
  end;
end;

function TIconFrm.GetDesktopLvHand: THandle;
begin
  Result := FindWindow('Progman', nil);
  if Result = 0 then begin Application.Terminate; end;

  Result := FindWindowEx(Result, 0, 'SHELLDLL_DefView', nil);
  if Result = 0 then begin Application.Terminate; end;

  Result := FindWindowEx(Result, 0, 'SysListView32', nil);
  if Result = 0 then begin Application.Terminate; end;
end;

procedure TIconFrm.DoDrawIconBegin;
var
  vProcessId: DWORD;
begin
  if FViewHandle <> 0 then
  begin
    GetWindowThreadProcessId(FViewHandle, @vProcessId);
    FViewProcess := OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_READ or PROCESS_VM_WRITE, False, vProcessId);
  end;
end;

procedure TIconFrm.DoDrawIconEnd;
begin
  try
    CloseHandle(FViewProcess);
  except
  end;
end;

procedure TIconFrm.DoDrawIcon;
var
  vRect: TRECT;
  bFlag: Boolean;
  sIconFile: String;
begin
  if (FViewHandle <> 0) and (FViewProcess <> 0) then
  begin
    if FWin64 then
      bFlag := GetDeskIcon64(FViewHandle, FViewProcess, FIconName, vRect)
    else
      bFlag := GetDeskIcon32(FViewHandle, FViewProcess, FIconName, vRect);

    if bFlag and (vRect.Left >= 0) and (vRect.Top >= 0) then
    begin
      Self.Width := vRect.Right - vRect.Left;
      Self.Height := vRect.Bottom - vRect.Top;
      Self.Left := vRect.Left;
      Self.Top := vRect.Top;

      if (Self.Height in [0..63]) then           // 74 * 63
        sIconFile := FIconFiles.Strings[0]
      else if (Self.Height in [80..127]) then    // 110 * 127
        sIconFile := FIconFiles.Strings[2]
      else
        sIconFile := FIconFiles.Strings[1];      // 74 * 79

      if (Trim(sIconFile) <> '') and (FPlayIconFile <> sIconFile) then
        if LoadIconFile(sIconFile) then
        begin
          FPlayIconFile := sIconFile;
          FGifImg.Paint(Self.Canvas, Self.ClientRect, [goAsync, goAnimate, goLoop, goLoopContinously]); // [goAsync, goLoop, goAnimate]);     goTransparent,
        end;
    end
    else
      Application.Terminate;
  end;

end;

function TIconFrm.GetDeskIcon32(hDeskWnd: HWND; hProcess: THandle; strIconName: String; var lpRect: TRECT): Boolean;
var
  i, iCount: Integer;
  vItem: TLVItem;
  vBuffer: array[0..255] of Char;
  vNumberOfBytesRead: Cardinal;
  vItemPointer: Pointer;
  vRectPointer: Pointer;
begin
  Result := False;

  if (hDeskWnd <> 0) and (hProcess <> 0) then
    try
      vItemPointer := VirtualAllocEx(hProcess, nil, SizeOf(TLVItem), MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);
      vRectPointer := VirtualAllocEx(hProcess, nil, sizeof(TRect), MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);
      try
        iCount := ListView_GetItemCount(hDeskWnd);
        for i := 0 to iCount -1 do
        begin
          with vItem do
          begin
            mask := LVIF_TEXT;
            iItem := i;
            iSubItem := 0;
            cchTextMax := SizeOf(vBuffer);
            pszText := Pointer(Cardinal(vItemPointer) + SizeOf(TLVItem));
          end;

          WriteProcessMemory(hProcess, vItemPointer, @vItem, SizeOf(TLVItem), vNumberOfBytesRead);
          SendMessage(hDeskWnd, LVM_GETITEM, i, lparam(vItemPointer));
          ReadProcessMemory(hProcess, Pointer(Cardinal(vItemPointer) + SizeOf(TLVItem)), @vBuffer[0], SizeOf(vBuffer), vNumberOfBytesRead);

          if SameText(strIconName, vBuffer) then
          begin
            SendMessage(hDeskWnd, LVM_GETITEMRECT, i, LPARAM(vRectPointer));
            ReadProcessMemory(hProcess, vRectPointer, @lpRect, sizeof(TRECT), vNumberOfBytesRead);

            Result := True;
            Break;
          end;
        end;
      finally
        VirtualFreeEx(hProcess, vItemPointer, 0, MEM_RELEASE);
        VirtualFreeEx(hProcess, vRectPointer, 0, MEM_RELEASE);
      end;
    except
    end;

end;

function TIconFrm.GetDeskIcon64(hDeskWnd: HWND; hProcess: THandle; strIconName: String; var lpRect: TRECT): Boolean;
var
  i, iCount: Integer;
  vItem: TLVItem64;
  vBuffer: array[0..255] of Char;
  vNumberOfBytesRead: Cardinal;
  vItemPointer: Pointer;
  vRectPointer: Pointer;
begin
  Result := False;

  if (hDeskWnd <> 0) and (hProcess <> 0) then
    try
      vItemPointer := VirtualAllocEx(hProcess, nil, SizeOf(TLVItem64), MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);
      vRectPointer := VirtualAllocEx(hProcess, nil, sizeof(TRect), MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);
      try
        OutputDebugString('ttttttttttt');

        iCount := ListView_GetItemCount(hDeskWnd);
        for i := 0 to iCount -1 do
        begin
          with vItem do
          begin
            mask := LVIF_TEXT;
            iItem := i;
            iSubItem := 0;
            cchTextMax := SizeOf(vBuffer);
            pszText := Int64(Cardinal(vItemPointer) + SizeOf(TLVItem64));
          end;

          WriteProcessMemory(hProcess, vItemPointer, @vItem, SizeOf(TLVItem64), vNumberOfBytesRead);
          SendMessage(hDeskWnd, LVM_GETITEM, i, lparam(vItemPointer));
          ReadProcessMemory(hProcess, Pointer(Cardinal(vItemPointer) + SizeOf(TLVItem64)), @vBuffer[0], SizeOf(vBuffer), vNumberOfBytesRead);

          if SameText(strIconName, vBuffer) then
          begin
            SendMessage(hDeskWnd, LVM_GETITEMRECT, i, LPARAM(vRectPointer));
            ReadProcessMemory(hProcess, vRectPointer, @lpRect, sizeof(TRECT), vNumberOfBytesRead);

            Result := True;
            Break;
          end;
        end;
      finally
        VirtualFreeEx(hProcess, vItemPointer, 0, MEM_RELEASE);
        VirtualFreeEx(hProcess, vRectPointer, 0, MEM_RELEASE);
      end;
    except
    end;

end;

procedure TIconFrm.OnAppException(Sender: TObject; E: Exception);
begin
end;

end.

