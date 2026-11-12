@echo off

rem Si AppScreen.ps1 a ete copie avec une marque BOM en double (copie depuis un navigateur, certains editeurs),
rem PowerShell n'en retire qu'une et signale une erreur sur la ligne 1 : le fichier est d'abord remis en UTF-8
rem avec une seule marque BOM, puis lance normalement.
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$f = '%~dp0AppScreen.ps1'; $t = [IO.File]::ReadAllText($f); if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { [IO.File]::WriteAllText($f, $t.TrimStart([char]0xFEFF), (New-Object Text.UTF8Encoding $true)) }; & $f"
