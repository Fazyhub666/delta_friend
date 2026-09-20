$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$scanPath = [System.IO.Path]::GetFullPath((Join-Path $here "..\tools\window_scan.ps1"))

$lines = Get-Content -LiteralPath $scanPath
$startIdx = -1
$endIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\$src = @"') { $startIdx = $i }
    if ($startIdx -ge 0 -and $i -gt $startIdx -and $lines[$i].TrimEnd() -eq '"@') { $endIdx = $i; break }
}
if ($startIdx -lt 0) { Write-Error "No se encontro el bloque C# en window_scan.ps1" }

$src = ($lines[$startIdx..$endIdx] | Select-Object -Skip 1) -join "`n"
$src = $src.Substring(0, $src.LastIndexOf('"@'))

Add-Type -TypeDefinition $src -Language CSharp
$type = [WinScan]

$pass = 0
$fail = 0
function Check([bool]$cond, [string]$name) {
    if ($cond) { $script:pass++; Write-Host "PASS: $name" }
    else       { $script:fail++; Write-Host "FAIL: $name" }
}

# PS aplana "array dentro de array literal" (@(...)). Si el parametro
# llega como 4 escalares es un único rect aplanado; si llega como array de
# arrays es una lista de rects. Normalizamos ambos casos.
function MakeList($items) {
    $list = New-Object 'System.Collections.Generic.List[long[]]'
    $flat = @($items)
    if ($flat.Count -gt 0 -and $flat[0] -isnot [array]) {
        $list.Add([long[]]$flat)
    } else {
        foreach ($f in $flat) { [long[]]$fl = $f; $list.Add($fl) }
    }
    return , $list
}

$nonPublic = [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::Public
function GetM([string]$name) { return $type.GetMethod($name, $script:nonPublic) }

function IsCovered($w, $front) {
    $invokeArgs = [object[]]::new(2)
    $invokeArgs[0] = [long[]]$w
    $invokeArgs[1] = [System.Collections.Generic.List[long[]]](MakeList $front)
    return (GetM "IsFullyCovered").Invoke($null, $invokeArgs)
}
function IsTopCovered($w, $front) {
    $invokeArgs = [object[]]::new(2)
    $invokeArgs[0] = [long[]]$w
    $invokeArgs[1] = [System.Collections.Generic.List[long[]]](MakeList $front)
    return (GetM "TopEdgeCovered").Invoke($null, $invokeArgs)
}

# --- IsFullyCovered ---
Check (IsCovered @(100,100,100,100) @(@(80,80,150,150)))            "fully: w dentro de frontal -> cubierto"
Check (IsCovered @(100,100,50,50) @(@(100,100,50,50)))              "fully: w igual a frontal -> cubierto"
Check (-not (IsCovered @(100,100,200,200) @(@(120,120,50,50))))     "fully: w sobresale -> no cubierto"
Check (-not (IsCovered @(100,100,50,50) @(@(160,100,50,50))))       "fully: w en otra posicion -> no cubierto"
Check (-not (IsCovered @(100,100,100,100) @(@(100,100,50,50))))     "fully: frontal cubre parte -> no cubierto"
Check (IsCovered @(200,200,40,40) @(@(0,0,40,40), @(190,190,60,60))) "fully: alguna frontal cubre -> cubierto"
Check (-not (IsCovered @(200,200,40,40) @(@(0,0,40,40), @(600,600,60,60)))) "fully: ningun frontal cubre -> no cubierto"

# --- TopEdgeCovered ---
$bigTop  = @(-100,45,500,20)
$smallTop = @(0,45,100,20)
$midTop  = @(100,45,200,20)
$below   = @(0,100,500,10)
$w       = @(60,50,200,100)

Check (IsTopCovered $w @($bigTop))                  "top: borde cubierto por una frontal -> cubierto"
Check (-not (IsTopCovered $w @($smallTop)))         "top: borde cubierto en parte -> no cubierto"
Check (IsTopCovered $w @($smallTop, $midTop))       "top: dos frontales cubren todo el borde -> cubierto"
Check (-not (IsTopCovered $w @($below)))            "top: frontal por debajo del borde -> no cubierto"
Check (-not (IsTopCovered $w @($smallTop, $below))) "top: frontal baja no completa cobertura -> no cubierto"
Check (-not (IsTopCovered $w @(@(60,50,80,10), @(180,50,80,10)))) "top: hueco central -> no cubierto"
Check (IsTopCovered $w @(@(60,50,200,10)))          "top: cobertura exacta del borde -> cubierto"
Check (-not (IsTopCovered $w @(@(0,50,150,10))))    "top: cubre desde antes hasta el medio -> no cubierto"
Check (IsTopCovered $w @(@(-10,50,80,10), @(70,50,190,10))) "top: frontales encadenadas cubren el borde -> cubierto"

# --- Scan integra ---
$rows = [WinScan]::Scan(0)
Check ($null -ne $rows) "scan: devuelve resultados"

$valid = $true
foreach ($r in $rows) {
    for ($k = 0; $k -lt $r.Count; $k++) { if ($r[$k] -isnot [long]) { $valid = $false } }
}
Check (($rows.Count -eq 0 -or $valid)) "scan: todos los rects tienen 4 enteros"

$invar = $true
for ($i = 0; $i -lt $rows.Count; $i++) {
    for ($j = $i + 1; $j -lt $rows.Count; $j++) {
        if (IsCovered $rows[$i] @($rows[$j])) { $invar = $false }
        if (IsCovered $rows[$j] @($rows[$i])) { $invar = $false }
    }
}
Check $invar "scan: ningun rect cubre a otro (invariante de oclusion)"

Write-Host ""
Write-Host ("scanner: {0} passed, {1} failed" -f $pass, $fail)
exit $(if ($fail -eq 0) { 0 } else { 1 })