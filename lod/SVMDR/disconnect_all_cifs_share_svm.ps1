#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Server = "svm1",       # NetBIOS name, FQDN or IP used in net use
    [string[]]$Shares = @()         # optionnel : limite à ces partages (ex: vol29,vol59)
)

$escaped = [regex]::Escape("\\$Server\")
$targets = @{}   # chemin UNC -> lettre de lecteur éventuelle (liste)

# --- 1. Connexions avec lettre de lecteur (Get-SmbMapping) ---
Get-SmbMapping -ErrorAction SilentlyContinue |
    Where-Object { $_.RemotePath -match "^$escaped" } |
    ForEach-Object {
        if (-not $targets.ContainsKey($_.RemotePath)) { $targets[$_.RemotePath] = @() }
        if ($_.LocalPath) { $targets[$_.RemotePath] += $_.LocalPath }
    }

# --- 2. Connexions sans lettre (sortie de net use) ---
net use 2>$null |
    Select-String -Pattern "$escaped[^\s]+" -AllMatches |
    ForEach-Object { $_.Matches.Value } |
    ForEach-Object { if (-not $targets.ContainsKey($_)) { $targets[$_] = @() } }

# --- 3. Filtre éventuel sur une liste de partages et exclusion de IPC$ ---
$paths = $targets.Keys | Where-Object { $_ -notmatch '\\IPC\$$' }
if ($Shares.Count -gt 0) {
    $paths = $paths | Where-Object { $Shares -contains ($_ -split '\\')[-1] }
}
$paths = $paths | Sort-Object

if (-not $paths) { Write-Warning "Aucune connexion trouvée vers \\$Server\*"; return }
Write-Host "$(@($paths).Count) connexion(s) vers \\$Server\* à déconnecter" -ForegroundColor Cyan

$ok = 0; $ko = @()
foreach ($p in $paths) {
    if ($PSCmdlet.ShouldProcess($p, "Déconnecter")) {
        # Lettres de lecteur d'abord, puis le chemin UNC
        foreach ($letter in $targets[$p]) {
            net use $letter /delete /y 2>&1 | Out-Null
        }
        $out = net use $p /delete /y 2>&1
        if ($LASTEXITCODE -eq 0) {
            $ok++
            Write-Host "  OK   $p"
        } else {
            $ko += $p
            Write-Host "  ECHEC $p : $($out -join ' ')" -ForegroundColor Red
        }
    }
}

Write-Host "`nDéconnectés : $ok | Échecs : $($ko.Count)" -ForegroundColor Green
if ($ko.Count -gt 0) {
    Write-Warning "Des handles sont probablement encore ouverts (script en cours, Explorateur, antivirus). Fermez-les puis relancez."
}

# Contrôle final
$left = net use 2>$null | Select-String -Pattern "$escaped" 
if ($left) { Write-Warning "Connexions restantes :"; $left | ForEach-Object { $_.Line } }
else { Write-Host "Aucune connexion restante vers \\$Server\*." -ForegroundColor Green }
