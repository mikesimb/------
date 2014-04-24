unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CommCtrl, GIFImage, IniFiles, GetIconInfo, ExtCtrls;

const
  C_CAPTION = 'DF498035-EAF3-441E-842E-98A6D64029FD';
  SE_DEBUG_PRIVILEGE = $14;

type
  TIconFrm = class(TForm)
    IconLab: TLabel;
    IconImg: TImage;
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
  public
    { Public declarations }
    // 获取桌面指定名字的图标位置
 //   function GetDeskIconPos(AIconName: String): TPoint;
    function GetDeskIconPos(hDeskWnd: HWND; strIconName: String; var lpRect: TRECT; var lpPos: TPoint): Boolean;
    // 加载需要显示的图标资源
    function LoadIconRes(AResName: String): Boolean;
    // 从配置文件获取图标相关配置信息
    function GetIconName(AIniFile: String): Boolean;
    // 运行图标对应的程序
    function RunApp(const AExe, AParam, APath: string; AFlags: Integer; AWait: Cardinal): THandle;

    procedure DoDrawIcon();
  end;

  //function RtlAdjustPrivilege(Privilege : ULONG; Enable : BOOLEAN; CurrentThread : BOOLEAN; Enabled : PBOOLEAN): DWORD; stdcall; external 'ntdll';
  function RtlAdjustPrivilege(Privilege: ULONG; Enable: BOOL; CurrentThread: BOOL; var Enabled: BOOL): DWORD; stdcall; external 'ntdll';

var
  IconFrm: TIconFrm;

implementation

{$R *.dfm}
{$R GifRes.RES}              // 打包资源

function TIconFrm.GetDeskIconPos(hDeskWnd: HWND; strIconName: String; var lpRect: TRECT; var lpPos: TPoint): Boolean;
var
  vItemCount: Integer;
  I: Integer;
  vBuffer: array[0..255] of Char;
  vProcessId: DWORD;
  vProcess: THandle;
  vPointer: Pointer;
  vNumberOfBytesRead: Cardinal;
  vItem: TLVItem;
begin
  Result := False;
  lpPos := Point(0, 0);
  lpRect := Rect(48, 48, 48, 48);

  vItemCount := ListView_GetItemCount(hDeskWnd);
  if (vItemCount > 0) then
  begin
    GetWindowThreadProcessId(hDeskWnd, @vProcessId);
    vProcess := OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_READ or PROCESS_VM_WRITE, False, vProcessId);
    vPointer := VirtualAllocEx(vProcess, nil, 4096, MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);

    OutputDebugString('GetDeskIconPos');
    try
      for I := 0 to vItemCount - 1 do
      begin

        with vItem do
        begin
          mask := LVIF_TEXT;
          iItem := I;
          iSubItem := 0;
          cchTextMax := SizeOf(vBuffer);
          pszText := Pointer(Cardinal(vPointer) + SizeOf(TLVItem));
        end;

        WriteProcessMemory(vProcess, vPointer, @vItem, SizeOf(TLVItem), vNumberOfBytesRead);
        SendMessage(hDeskWnd, LVM_GETITEM, I, lparam(vPointer));
        ReadProcessMemory(vProcess, Pointer(Cardinal(vPointer) + SizeOf(TLVItem)), @vBuffer[0], SizeOf(vBuffer), vNumberOfBytesRead);

        if SameText(strIconName, vBuffer) then
        begin
        //  SendMessage(hDeskWnd, LVM_GETITEMRECT, I, LPARAM(vPointer));
       //   ReadProcessMemory(vProcess, vPointer, @lpRect, sizeof(TRECT), vNumberOfBytesRead);

          ListView_GetItemPosition(hDeskWnd, I, PPoint(vPointer)^);
          ReadProcessMemory(vProcess, vPointer, @lpPos, SizeOf(TPoint), vNumberOfBytesRead);

          Result := True;

          Break;
        end;

      end;
    finally
      VirtualFreeEx(vProcess, vPointer, 0, MEM_RELEASE);
      CloseHandle(vProcess);
    end;
  end;

end;

function TIconFrm.LoadIconRes(AResName: String): Boolean;
var
  vStream: TResourceStream;
begin
  Result := False;

  vStream := TResourceStream.Create(HInstance, AResName, RT_RCDATA);
  try
    FGifImg.LoadFromStream(vStream);
    Result := True;
  except
  end;
  vStream.Free;
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

procedure TIconFrm.DoDrawIcon;
var
  vHandle: THandle;
  vPt: TPoint;
  vRect: TRECT;
  bFlag: Boolean;
begin
  vHandle := GetDesktopLvHand();
  if (vHandle <> 0) then
  begin
    if IsWin64 then
      bFlag := GetIconRect64(vHandle, FIconName, vRect, vPt)
    else
     //  bFlag := GetDeskIconPos(vHandle, FIconName, vRect, vPt);
      bFlag :=  GetIconRect32(vHandle, FIconName, vRect, vPt);


    if bFlag and (vPt.X >= 0) and (vPt.Y >= 0) then
    begin
      Self.Width := vRect.Right-vRect.left;
      Self.Height := vRect.Bottom - vRect.Top;
      Self.Left :=  vPt.X;
      Self.Top :=  vPt.Y;


      IconImg.Left := (Self.Width - IconImg.Width) div 2;
      IconImg.Top := 0;

    //  IconLab.Caption := FIconName;
    //  IconLab.Left := (Self.Width - IconLab.Width) div 2;

     // if LoadIconRes('DrawIcon') then
        //FGifImg.Paint(IconImg.Canvas, IconImg.ClientRect, [goAsync, goLoop, goAnimate]);
    end;
  end;
 // else
 //   ShowMessage('获取名称为：' + sName + ' 的桌面图标失败！');
end;

procedure TIconFrm.FormCreate(Sender: TObject);
var
  bEnabled: BOOL;
begin
  FRunPath := ExtractFilePath(Application.ExeName);
  Self.Caption := C_CAPTION;

  SetWindowLong(Application.Handle, GWL_EXSTYLE, WS_EX_TOOLWINDOW);
  
  if not RtlAdjustPrivilege(SE_DEBUG_PRIVILEGE, true, false, bEnabled) = 0 then
  begin
    ShowMessage('权限提升失败！');
    Application.Terminate;
  end;

  FGifImg := TGifImage.Create;
 // FGifImg.Transparent := True;
end;

procedure TIconFrm.FormShow(Sender: TObject);
var
  sName: String;
begin
  if GetIconName(FRunPath + 'user.ini') then
  begin
    DrawTime.Enabled := True;
  end
  else
    ShowMessage('没找到配置：' + FRunPath + 'user.ini');
end;

procedure TIconFrm.FormDestroy(Sender: TObject);
begin
  FGifImg.Free;
end;

function TIconFrm.GetIconName(AIniFile: String): Boolean;
var
  vIni: TIniFile;
begin
  Result := False;
  if FileExists(AIniFile) then
  begin
    vIni := TIniFile.Create(AIniFile);
    try
      FIconExe := vIni.ReadString('Settings', 'IconRun', '');
      FIconExeParam := vIni.ReadString('Settings', 'IconRunParam', '');
      FIconName := vIni.ReadString('Settings', 'IconName', '');
      Result := True;
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
  DoDrawIcon;
end;

end.



{

function TIconFrm.GetDeskIconPos(hDeskWnd: HWND; strIconName:String; var lpRect:TRECT; var lpPos :TPoint): Boolean;
var
  vHandle: THandle;
var
  vItemCount: Integer;
  I: Integer;
  vBuffer: array[0..255] of Char;
  vProcessId: DWORD;
  vProcess: THandle;
  vPointer: Pointer;
  vNumberOfBytesRead: Cardinal;
  vItem: TLVItem;
begin
  Result := Point(0, 0);
  vHandle := FindWindow('Progman',   nil);
  if vHandle = 0 then begin ShowMessage('Find Progman Fail!'); Exit; end;

  vHandle := FindWindowEx(vHandle, 0, 'SHELLDLL_DefView', nil);
  if vHandle = 0 then begin ShowMessage('Find SHELLDLL_DefView Fail!'); Exit; end;

  vHandle := FindWindowEx(vHandle, 0, 'SysListView32',   nil);
  if vHandle = 0 then begin ShowMessage('Find SysListView32 Fail!'); Exit; end;

  vItemCount := ListView_GetItemCount(vHandle);
  if (vItemCount > 0) then
  begin
    GetWindowThreadProcessId(vHandle, @vProcessId);
    vProcess := OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_READ or PROCESS_VM_WRITE, False, vProcessId);
    vPointer := VirtualAllocEx(vProcess, nil, 4096, MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);

    ShowMessage(AIconName + ' - 1');
    try
      for I := 0 to vItemCount - 1 do
      begin

        with vItem do
        begin
          mask := LVIF_TEXT;
          iItem := I;
          iSubItem := 0;
          cchTextMax := SizeOf(vBuffer);
          pszText := Pointer(Cardinal(vPointer) + SizeOf(TLVItem));
        end;

        WriteProcessMemory(vProcess, vPointer, @vItem, SizeOf(TLVItem), vNumberOfBytesRead);
        SendMessage(vHandle, LVM_GETITEM, I, lparam(vPointer));
        ReadProcessMemory(vProcess, Pointer(Cardinal(vPointer) + SizeOf(TLVItem)), @vBuffer[0], SizeOf(vBuffer), vNumberOfBytesRead);

        ShowMessage(vBuffer);
        if SameText(AIconName, vBuffer) then
        begin
          ListView_GetItemPosition(vHandle, I, PPoint(vPointer)^);
          ReadProcessMemory(vProcess, vPointer, @Result, SizeOf(TPoint), vNumberOfBytesRead);

          Break;
        end;

      end;
    finally
      VirtualFreeEx(vProcess, vPointer, 0, MEM_RELEASE);
      CloseHandle(vProcess);
    end;
  end;

end;
}
