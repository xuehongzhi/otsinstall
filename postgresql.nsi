; example2.nsi
;
; This script is based on example1.nsi, but it remember the directory, 
; has uninstall support and (optionally) installs start menu shortcuts.
;
; It will install example2.nsi into a directory that the user selects,

;--------------------------------

; The name of the installer
;
!include "LogicLib.nsh"
!include "EnvVarUpdate.nsh"
Name "postgresql"

; The file to write
OutFile "postgresql_installer.exe"


; The default installation directory
InstallDir $PROGRAMFILES\postgresql

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\postgresql" "Install_Dir"


; Request application privileges for Windows Vista
RequestExecutionLevel admin

;--------------------------------

; Pages

Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles
Var SERVICE_NAME 
  

;--------------------------------

; The stuff to install
Section "postgresql (required)"

  SectionIn RO
  
   StrCpy $SERVICE_NAME "wyzxdbservice"
   SetOutPath $SYSDIR
   SetOverwrite off

   File pgsql\msvc*120.dll 
   ; Set output path to the installation directory.
  SetOverwrite on 
  SetOutPath $INSTDIR
  
  ; Put file there
  ;   
  
  File /r /x msvc*120.dll pgsql\*.*
  ; Write the installation path into the registry
  ;

  WriteRegStr HKLM SOFTWARE\postgresql "Install_Dir" "$INSTDIR"
  WriteRegStr HKLM SOFTWARE\postgresql "version" "9.5.6"
  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\postgresql" "DisplayName" "postgresql"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\postgresql" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\postgresql" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\postgresql" "NoRepair" 1
  WriteUninstaller "uninstall.exe"
  ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\bin" ; Append  
 
  CreateShortCut '$DESKTOP\pgadmin3.lnk' '$INSTDIR\bin\pgadmin3.exe'

SectionEnd

!macro ExecPsql db usr cmd
  DetailPrint "$INSTDIR\psql -d ${db} -U ${usr} -c ${cmd}"
  ExecWait "$INSTDIR\psql -d ${db} -U ${usr} -c ${cmd}"
!macroend

Function .onInstSuccess
  Var /GLOBAL datadir
  StrCpy $datadir "$INSTDIR\data"

  CreateDirectory $datadir
  Push $0 ; save 
 
  Push "Marker" 
  AccessControl::GrantOnFile \
    $datadir "(AU)" "GenericRead + GenericWrite"
  Pop $0 ; get "Marker" or error msg
  StrCmp $0 "ok" Continue
  MessageBox MB_OK|MB_ICONSTOP "Error setting access control for $datadir: $0"
  Pop $0 ; pop "Marker"
  Goto done
Continue:
  Pop $0 ; restore
 
  ExecWait '$INSTDIR\bin\initdb -E utf8 -U postgres --pwfile="$INSTDIR\password" -D "$datadir"'
  ExecWait '$INSTDIR\bin\pg_ctl register -N $SERVICE_NAME -U "NT AUTHORITY\NETWORK SERVICE" -D  "$datadir" -S auto' 
  Exec '$INSTDIR\bin\pg_ctl start -D  "$datadir"' 
  Delete "$INSTDIR\password" 
  Sleep 6000
  ExecWait "$INSTDIR\create.bat"
  ExecWait '$INSTDIR\bin\pg_ctl stop -D  "$datadir"' 
  reboot
done:
FunctionEnd


; Uninstaller

Section "Uninstall"
   
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\postgresql"
  DeleteRegKey HKLM SOFTWARE\postgresql

  ExecWait '$INSTDIR\bin\pg_ctl unregister -N $SERVICE_NAME' 
  ; Remove files and uninstaller
  Delete $INSTDIR\uninstall.exe
  ; Remove directories used
  RMDir /r "$INSTDIR"

  Delete "$DESKTOP\pgadmin3.lnk" 
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\bin"
SectionEnd

Function un.onUninstSuccess
  RMDir /r "$INSTDIR\data" 
FunctionEnd

