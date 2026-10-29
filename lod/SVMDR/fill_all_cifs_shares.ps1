#Requires -Version 5.1
param(
    [string]$Server    = "svm1",
    [int]$MinSizeKB    = 1,        # taille mini d'un fichier
    [int]$MaxSizeMB    = 5,        # taille maxi d'un fichier
    [string]$SubFolder = "fill_test",
    [switch]$WhatIf
)

# --- API Win32 : espace libre d'un chemin UNC (tient compte des quotas) ---
Add-Type -Namespace Win32 -Name Disk -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool GetDiskFreeSpaceEx(string dir, out ulong freeToCaller, out ulong total, out ulong totalFree);
'@

function Get-FreeBytes([string]$Path) {
    [uint64]$free = 0; [uint64]$total = 0; [uint64]$tfree = 0
    if (-not [Win32.Disk]::GetDiskFreeSpaceEx($Path, [ref]$free, [ref]$total, [ref]$tfree)) {
        throw "GetDiskFreeSpaceEx a échoué pour $Path (erreur $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
    }
    return [int64]$free
}

# --- Liste des partages \\svm1\* connectés (avec ou sans lettre) ---
$escaped = [regex]::Escape("\\$Server\")
$shares = net use |
    Select-String -Pattern "$escaped[^\s]+" -AllMatches |
    ForEach-Object { $_.Matches.Value } |
    Sort-Object -Unique

if (-not $shares) { Write-Warning "Aucun partage connecté sous \\$Server\*"; return }
Write-Host "$($shares.Count) partage(s) détecté(s)" -ForegroundColor Cyan

$rng    = New-Object System.Random
$minB   = [int64]$MinSizeKB * 1KB
$maxB   = [int64]$MaxSizeMB * 1MB
$buffer = New-Object byte[] (1MB)

function Write-RandomFile([string]$File, [int64]$Size) {
    $fs = [System.IO.File]::Open($File, 'Create', 'Write', 'None')
    try {
        $left = $Size
        while ($left -gt 0) {
            $n = [int][Math]::Min($left, $buffer.Length)
            $rng.NextBytes($buffer)          # contenu aléatoire renouvelé à chaque bloc
            $fs.Write($buffer, 0, $n)
            $left -= $n
        }
        $fs.Flush($true)
    }
    finally { $fs.Dispose() }
}

foreach ($share in $shares) {
    $dir = Join-Path $share $SubFolder
    Write-Host "`n=== $share ===" -ForegroundColor Yellow

    try {
        $free0 = Get-FreeBytes $share
        Write-Host ("Espace libre initial : {0:N0} octets" -f $free0)
        if ($WhatIf) { continue }

        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

        $count = 0
        $cap   = $maxB
        while ($true) {
            $free = Get-FreeBytes $share
            if ($free -le 0) { break }

            $size = if ($free -le $minB) { $free } else { [int64]$rng.NextDouble() * 0 + $rng.Next([int]$minB, [int]([Math]::Min($cap, [Math]::Min($free, [int]::MaxValue)))) }
            $size = [Math]::Min($size, $free)
            $file = Join-Path $dir ("rnd_{0:D6}_{1}.bin" -f $count, [guid]::NewGuid().ToString("N").Substring(0,8))

            try {
                Write-RandomFile $file $size
                $count++
            }
            catch [System.IO.IOException] {
                # disque plein : on supprime le fichier partiel puis on réduit la taille
                if (Test-Path $file) { Remove-Item $file -Force -ErrorAction SilentlyContinue }
                if ($cap -le 1) { break }
                $cap = [Math]::Max(1, [int64]($cap / 2))
            }

            if ($count % 20 -eq 0) {
                $f = Get-FreeBytes $share
                Write-Progress -Activity "Remplissage $share" -Status ("{0} fichiers, {1:N0} octets libres" -f $count, $f) `
                    -PercentComplete ([Math]::Min(100, [int](100 * (1 - $f / [double]$free0))))
            }
        }
        Write-Progress -Activity "Remplissage $share" -Completed
        Write-Host ("Terminé : {0} fichiers créés, espace libre restant : {1:N0} octets" -f $count, (Get-FreeBytes $share)) -ForegroundColor Green
    }
    catch {
        Write-Warning "Erreur sur $share : $($_.Exception.Message)"
    }
}
