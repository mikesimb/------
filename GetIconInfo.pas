unit GetIconInfo;

interface

uses
  windows,CommCtrl;

const cchTextMax=512;

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

function GetDesktopLvHand: THandle;
function IsWin64: Boolean; 
function GetIconRect32(hDeskWnd:HWND ;strIconName:String;var lpRect:TRECT;var lpPos :TPoint):Boolean;
function GetIconRect64(hDeskWnd:HWND ;strIconName:String;var lpRect:TRECT;var lpPos:TPoint):Boolean;


implementation

function GetDesktopLvHand: THandle;
begin
  Result := FindWindow('progman', nil);
  Result := GetWindow(Result, GW_Child);
  Result := GetWindow(Result, GW_Child);
end;

//32位系统------
function GetIconRect32(hDeskWnd:HWND ;strIconName:String;var lpRect:TRECT;var lpPos :TPoint):Boolean;
var
  ItemBuf: array [0 .. 512] of char;
  pszText: PChar;
  LVItem: TLVItem;
  ProcessID, ProcessHD, drTmp: DWORD;
  pLVITEM: Pointer;
  pItemRc: ^TRect;
  nCount,iItem:Integer;
  PItemPos:^TPoint;
  defItemRc: TRect;
  cxScreen, cyScreen: Integer;
begin
  Result :=False;
  GetWindowThreadProcessId(hDeskWnd, ProcessID);
  ProcessHD := OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_READ or PROCESS_VM_WRITE, False,ProcessID);
  if (ProcessHD=0) then Exit
  else begin

    pLVITEM := VirtualAllocEx(ProcessHD, nil, SizeOf(TLVItem),MEM_COMMIT, PAGE_READWRITE);
    pszText:=VirtualAllocEx(ProcessHD,nil,cchTextMax,MEM_COMMIT,PAGE_READWRITE);
    pItemRc:=VirtualAllocEx(ProcessHD,nil,sizeof(TRECT),MEM_COMMIT,PAGE_READWRITE);
    pItemPos:= VirtualAllocEx(ProcessHD,nil,sizeof(TPoint),MEM_COMMIT,PAGE_READWRITE);

    OutputDebugString('GetIconRect32');

    if (pLVITEM=nil) then
    else begin
      LVItem.mask := LVIF_TEXT;
      LVItem.iItem := 0;
      LVItem.iSubItem := 0;
      LVItem.cchTextMax := cchTextMax;
      LVItem.pszText := PChar(Integer(pLVITEM) + SizeOf(TLVItem));

      WriteProcessMemory(ProcessHD, pLVITEM, @LVItem, SizeOf(TLVItem), drTmp);
      nCount:=SendMessage(hDeskWnd,LVM_GETITEMCOUNT,0,0);
      for iItem := 0 to nCount - 1 do begin
        SendMessage(hDeskWnd, LVM_GETITEMTEXT, iItem, Integer(pLVITEM));
        //ReadProcessMemory(ProcessHD,pszText,@ItemBuf,cchTextMax,drTmp);
        ReadProcessMemory(ProcessHD,Pointer(Integer(pLVITEM) + SizeOf(TLVItem)),@ItemBuf, cchTextMax, drTmp);

        if (ItemBuf=strIconName) then begin
         SendMessage(hDeskWnd,LVM_GETITEMRECT,iItem, LPARAM(pLVITEM)); //  LPARAM(pItemRc));
         ReadProcessMemory(ProcessHD,pLVITEM,@lpRect,sizeof(TRECT),drTmp);
        // ReadProcessMemory(ProcessHD,pItemRc,@lpRect,sizeof(TRECT),drTmp);

          ListView_GetItemPosition(hDeskWnd,iItem, PPoint(pLVITEM)^); //TPoint(pItemPos^));
          ReadProcessMemory(ProcessHD,pLVITEM,@lpPos,sizeof(TPoint),drTmp);
         // ReadProcessMemory(ProcessHD,pItemPos,@lpPos,sizeof(TPoint),drTmp);

          Result :=True ;
          Break ;
        end;
      end;
      VirtualFreeEx(ProcessHD,pLVITEM,0,MEM_RELEASE);
      VirtualFreeEx(ProcessHD,PItemPos,0,MEM_RELEASE);
      VirtualFreeEx(ProcessHD,pLVITEM, SizeOf(TLVItem) + cchTextMax,MEM_DECOMMIT);
   //   VirtualFreeEx(ProcessHD,pszText,0,MEM_RELEASE);
      VirtualFreeEx(ProcessHD,pItemRc,0,MEM_RELEASE);//释放内存
    end;
    CloseHandle(ProcessHD);
  end;
end;
//64位系统------
function GetIconRect64(hDeskWnd:HWND ;strIconName:String;var lpRect:TRECT;var lpPos:TPoint):Boolean;
var
  ItemBuf: array [0 .. 512] of char;
  pszText: PChar;
  LVItem: TLVItem64;
  ProcessID, ProcessHD, drTmp: DWORD;
  pLVITEM: Pointer;
  pItemRc:^TRect;
  PItemPos:^TPoint;
  nCount,iItem:Integer;
begin
  Result :=False ;
  GetWindowThreadProcessId(hDeskWnd, ProcessID);
  ProcessHD := OpenProcess(PROCESS_VM_OPERATION or PROCESS_VM_READ or PROCESS_VM_WRITE, False,ProcessID);
  if (ProcessHD=0) then Exit
  else begin
    pLVITEM := VirtualAllocEx(ProcessHD, nil, SizeOf(TLVItem64),MEM_COMMIT, PAGE_READWRITE);
    pszText:=VirtualAllocEx(ProcessHD,nil,cchTextMax,MEM_COMMIT,PAGE_READWRITE);
    pItemRc:=VirtualAllocEx(ProcessHD,nil,sizeof(TRECT),MEM_COMMIT,PAGE_READWRITE);
    pItemPos:= VirtualAllocEx(ProcessHD,nil,sizeof(TPoint),MEM_COMMIT,PAGE_READWRITE);
    if (pLVITEM=nil) then
    else begin
      LVItem.iSubItem := 0;
      LVItem.cchTextMax := cchTextMax;
      LVItem.pszText := Int64(pszText);
      WriteProcessMemory(ProcessHD, pLVITEM, @LVItem, SizeOf(TLVItem64), drTmp);

      nCount:=SendMessage(hDeskWnd,LVM_GETITEMCOUNT,0,0);
       for iItem := 0 to nCount - 1 do begin
        SendMessage(hDeskWnd, LVM_GETITEMTEXT, iItem, Integer(pLVITEM));
        //ReadProcessMemory(ProcessHD,pszText,@ItemBuf,cchTextMax,drTmp);
        ReadProcessMemory(ProcessHD,Pointer(LVITem.pszText),@ItemBuf, cchTextMax, drTmp);

        if (ItemBuf=strIconName) then begin
          SendMessage(hDeskWnd,LVM_GETITEMRECT,iItem, LPARAM(pLVITEM)); //  LPARAM(pItemRc));
          ReadProcessMemory(ProcessHD,pLVITEM,@lpRect,sizeof(TRECT),drTmp);
//        //  ReadProcessMemory(ProcessHD,pItemRc,@lpRect,sizeof(TRECT),drTmp);

          ListView_GetItemPosition(hDeskWnd,iItem, PPoint(pLVITEM)^); //TPoint(pItemPos^));
          ReadProcessMemory(ProcessHD,pLVITEM,@lpPos,sizeof(TPoint),drTmp);
         // ReadProcessMemory(ProcessHD,pItemPos,@lpPos,sizeof(TPoint),drTmp);

          Result :=True ;
          Break ;
        end;
      end;
//      for iItem := 0 to nCount - 1 do begin
//        SendMessage(hDeskWnd, LVM_GETITEMTEXT, iItem, Integer(pLVITEM));
//        ReadProcessMemory(ProcessHD,pszText,@ItemBuf,cchTextMax,drTmp);
//        if (ItemBuf=strIconName) then begin
//          SendMessage(hDeskWnd,LVM_GETITEMRECT,iItem,LPARAM(pItemRc));
//          ReadProcessMemory(ProcessHD,pItemRc,@lpRect,sizeof(TRECT),drTmp);
//
//          ListView_GetItemPosition(hDeskWnd,iItem,TPoint(pItemPos^));
//          ReadProcessMemory(ProcessHD,pItemRc,@lpPos,sizeof(TPoint),drTmp);
//          Result :=True ;
//          Break;
//        end;
//      end;
      VirtualFreeEx(ProcessHD,PItemPos,0,MEM_RELEASE);
      VirtualFreeEx(ProcessHD,pLVITEM,0,MEM_RELEASE);
      VirtualFreeEx(ProcessHD,pszText,0,MEM_RELEASE);
      VirtualFreeEx(ProcessHD,pItemRc,0,MEM_RELEASE);//释放内存
    end;
    CloseHandle(ProcessHD);
  end;
end;

function IsWin64: Boolean;
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


end.
