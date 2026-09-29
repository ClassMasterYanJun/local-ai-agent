Option Explicit

Dim shell, fileSystem, projectPath, command
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")
projectPath = fileSystem.GetParentFolderName(WScript.ScriptFullName)
command = "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & projectPath & "\Control-LocalAI.ps1""" -Action Tray"
shell.Run command, 0, False
