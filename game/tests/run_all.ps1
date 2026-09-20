$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$game = [System.IO.Path]::GetFullPath((Join-Path $here ".."))
$godot = "E:\Godot\Godot_v4.7.2-stable_win64_console.exe"

$code = 0

Write-Host "=== Scanner (PowerShell/C#) ==="
& "powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "test_scanner.ps1")
$scannerCode = $LASTEXITCODE
Write-Host ("Scanner exit code: {0}" -f $scannerCode)
if ($scannerCode -ne 0) { $code = 1 }

Write-Host ""
Write-Host "=== Godot (pet mechanics + window_manager) ==="
& $godot --headless --path $game "res://tests/run_tests.tscn"
$godotCode = $LASTEXITCODE
Write-Host ("Godot exit code: {0}" -f $godotCode)
if ($godotCode -ne 0) { $code = 1 }

Write-Host ""
if ($code -eq 0) { Write-Host "ALL TEST GROUPS PASSED" } else { Write-Host "TEST FAILURES DETECTED" }
exit $code