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
!include "TextFunc.nsh"
!include "FileFunc.nsh"
Name "ots"

; The file to write
OutFile "ots_installer.exe"


; The default installation directory
InstallDir $PROGRAMFILES\ots

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\ots" "Install_Dir"


; Request application privileges for Windows Vista
RequestExecutionLevel admin

;--------------------------------

; Pages

Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles

Function InstallPy34
  SetOutPath $TEMP
  File /r vc_redist.x86.exe
  Call CheckVC2010Redist
  Pop $R0
  StrCmp $R0 "-1" 0 +2  
   ; Set output path to the installation directory.
    ExecWait '$TEMP\vc_redist.x86.exe'

  SetOutPath $INSTDIR
  ; Put file there
  ;    
  File /r py34em
  Rename  $INSTDIR\py34em $INSTDIR\python
FunctionEnd

Function InstallPy35
  SetOutPath $TEMP
  File /r vc_redist.x86.exe
  Call CheckVC2015Redist
  Pop $R0
  StrCmp $R0 "-1" 0 +2  
   ; Set output path to the installation directory.
    ExecWait '$TEMP\vc_redist.x86.exe'
  SetOutPath $INSTDIR
  ; Put file there
  ;    
  File /r py35em
  Rename  $INSTDIR\py35em $INSTDIR\python    
FunctionEnd
 
Function CheckVC2010Redist
   Push $R0
   ClearErrors

   ReadRegDword $R0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{F0C3E5D1-1ADE-321E-8167-68EF0DE699A5}" "Version"

   ; if VS 2010+ redist SP1 not installed, install it
   IfErrors 0 VSRedistInstalled
   StrCpy $R0 "-1"

VSRedistInstalled:
   Exch $R0 
FunctionEnd 

Function CheckVC2015Redist
   Push $R0
   ClearErrors

   ReadRegDword $R0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A2563E55-3BEC-3828-8D67-E5E8B9E8B675}" "Version"

   ; if VS 2005+ redist SP1 not installed, install it
   IfErrors 0 VSRedistInstalled
   StrCpy $R0 "-1"

VSRedistInstalled:
   Exch $R0 
FunctionEnd 

;--------------------------------

; The stuff to install
Section "install (required)"

  SectionIn RO
  
SimpleSC::RemoveService "otsweb"
 
  SetOverwrite off 
  SetOutPath $SYSDIR
  File /r nssm.exe
  SetOverwrite on

  Call InstallPy34

  SetOutPath $INSTDIR
  File /r /x logs\*.* otsweb 
  AccessControl::GrantOnFile \
    $INSTDIR\otsweb\logs "(AU)" "GenericRead + GenericWrite"

  ; Write the installation path into the registry
  ; 
  ExecWait '$SYSDIR\nssm install otsweb "$INSTDIR\python\python" """$INSTDIR\otsweb\waitserver.pyc"""'
  ExecWait '$SYSDIR\nssm set otsweb AppDirectory "$INSTDIR\otsweb"'
  ;SimpleSC::InstallService "otsweb" "ots webservice" "16" "2" "'$INSTDIR\python\python' '$INSTDIR\otsweb\server.py'" "" "" ""
  
  File version
  ${LineRead} "$INSTDIR\version" "1" $R0
  ${StrRep} $0 $R0 "otsversion=" "" 

  WriteRegStr HKLM "SOFTWARE\ots" "Install_Dir" "$INSTDIR"
  WriteRegStr HKLM "SOFTWARE\ots" "otsweb_version" $0
  
  ${GetFileVersion} "$INSTDIR\python\python.exe" $R0 
  WriteRegStr HKLM "SOFTWARE\ots" "py_version" "$R0"
  WriteRegStr HKLM "SOFTWARE\ots" "displayname" "油库自动计量监管系统"

  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ots" "DisplayName" "ots"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ots" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ots" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ots" "NoRepair" 1
  WriteUninstaller "uninstall.exe"
  ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\python\" ; Append  
  
  Delete $TEMP\vc_redist.x86.exe
  Delete $INSTDIR\version
  
  SetOutPath $INSTDIR\otsweb
  ExecWait '$INSTDIR\python\python manage.py migrate'
  RMDir /r $INSTDIR\otsweb\ots\migrations
SectionEnd



; Uninstaller
Section "Uninstall"
   
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ots"
  DeleteRegKey HKLM SOFTWARE\ots

  ; Remove files and uninstaller
  Delete $INSTDIR\uninstall.exe
  ; Remove directories used
  RMDir /r "$INSTDIR"

  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\python"
  ExecWait '$SYSDIR\nssm remove otsweb confirm'

SectionEnd


