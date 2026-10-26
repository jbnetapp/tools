#Requires -Version 5.1
#
# Test court pour valider (3 itérations de 10 s, 4 threads)
# Sim-IOPS.ps1 -Threads 4 -DurationSec 10 -Iterations 3

# Charge type OLTP : blocs de 8 Ko, 70 % lectures, 16 threads, journal CSV
# Sim-IOPS.ps1 -Threads 16 -BlockSizeKB 8 -ReadPercent 70 -LogCsv C:\temp\iops.csv

# Charge séquentielle-like : blocs de 64 Ko, 50/50, en continu
# Sim-IOPS.ps1 -BlockSizeKB 64 -ReadPercent 50 -Iterations 0

param(
    [string]$Path        = "\\svm1\vol29",
    [int]$Threads        = 8,
    [int]$BlockSizeKB    = 8,      # taille d'un IO
    [int]$ReadPercent    = 70,     # % de lectures (le reste = écritures)
    [int]$DurationSec    = 30,     # durée d'une itération
    [int]$Iterations     = 10,     # 0 = infini (Ctrl+C pour arrêter)
    [int]$PauseSec       = 2,      # pause entre itérations
    [int]$ReadSetMB      = 512,    # taille du fichier de lecture
    [int]$WriteFileMB    = 64,     # taille du fichier d'écriture par thread
    [string]$WorkFolder  = "iops_sim",
    [string]$LogCsv      = "",     # ex: C:\temp\iops.csv
    [switch]$KeepReadSet
)

Add-Type -Namespace Win32 -Name Disk -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool GetDiskFreeSpaceEx(string dir, out ulong freeToCaller, out ulong total, out ulong totalFree);
'@

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
using System.Diagnostics;

public static class IoSim {
    public static long RBytes, WBytes, ROps, WOps, Errors;

    public static void Reset() {
        RBytes = 0; WBytes = 0; ROps = 0; WOps = 0; Errors = 0;
    }

    public static void Run(string readFile, string writeDir, int threads, int blockSize,
                           int readPct, int seconds, long writeFileSize) {
        Stopwatch sw = Stopwatch.StartNew();
        Thread[] ts = new Thread[threads];
        for (int t = 0; t < threads; t++) {
            int id = t;
            ts[t] = new Thread(delegate() {
                Worker(id, readFile, writeDir, blockSize, readPct, seconds, writeFileSize, sw);
            });
            ts[t].Start();
        }
        for (int t = 0; t < threads; t++) ts[t].Join();
    }

    static void Worker(int id, string readFile, string writeDir, int blockSize, int readPct,
                       int seconds, long writeFileSize, Stopwatch sw) {
        Random rng = new Random(Environment.TickCount ^ (id * 7919));
        byte[] buf = new byte[blockSize];
        string wf = Path.Combine(writeDir, "w_" + id + ".dat");
        try {
            using (FileStream rf = new FileStream(readFile, FileMode.Open, FileAccess.Read,
                       FileShare.ReadWrite, 4096, FileOptions.RandomAccess))
            using (FileStream wfs = new FileStream(wf, FileMode.Create, FileAccess.ReadWrite,
                       FileShare.None, 4096, FileOptions.WriteThrough | FileOptions.RandomAccess)) {
                wfs.SetLength(writeFileSize);
                long rBlocks = rf.Length / blockSize;
                long wBlocks = writeFileSize / blockSize;
                while (sw.Elapsed.TotalSeconds < seconds) {
                    if (rng.Next(100) < readPct && rBlocks > 0) {
                        rf.Position = (long)(rng.NextDouble() * rBlocks) * blockSize;
                        int n = rf.Read(buf, 0, blockSize);
                        Interlocked.Add(ref RBytes, n);
                        Interlocked.Increment(ref ROps);
                    } else {
                        rng.NextBytes(buf);
                        wfs.Position = (long)(rng.NextDouble() * wBlocks) * blockSize;
                        wfs.Write(buf, 0, blockSize);
                        Interlocked.Add(ref WBytes, blockSize);
                        Interlocked.Increment(ref WOps);
                    }
                }
            }
        } catch (Exception) {
            Interlocked.Increment(ref Errors);
        }
    }
}
'@

function Get-FreeBytes([string]$P) {
    [uint64]$a = 0; [uint64]$b = 0; [uint64]$c = 0
    if (-not [Win32.Disk]::GetDiskFreeSpaceEx($P, [ref]$a, [ref]$b, [ref]$c)) {
        throw "GetDiskFreeSpaceEx a échoué pour $P"
    }
    return [int64]$a
}

if (-not (Test-Path $Path)) { throw "Chemin inaccessible : $Path" }

$blockSize   = $BlockSizeKB * 1KB
$work        = Join-Path $Path $WorkFolder
$writeDir    = Join-Path $work "write"
$readFile    = Join-Path $work "readset.dat"
$maxUsedMB   = $ReadSetMB + ($Threads * $WriteFileMB)
$free        = Get-FreeBytes $Path

if ($free -lt ($maxUsedMB * 1MB * 1.1)) {
    throw ("Espace libre insuffisant : {0:N0} Mo libres, {1:N0} Mo nécessaires (+10 %)" -f ($free/1MB), $maxUsedMB)
}

New-Item -ItemType Directory -Path $writeDir -Force | Out-Null

# --- Création du fichier de lecture (une seule fois, données aléatoires) ---
if (-not (Test-Path $readFile) -or (Get-Item $readFile).Length -lt ($ReadSetMB * 1MB)) {
    Write-Host "Création du fichier de lecture ($ReadSetMB Mo)..." -ForegroundColor Cyan
    $rng = New-Object System.Random
    $chunk = New-Object byte[] (1MB)
    $fs = [System.IO.File]::Open($readFile, 'Create', 'Write', 'None')
    try {
        for ($i = 0; $i -lt $ReadSetMB; $i++) { $rng.NextBytes($chunk); $fs.Write($chunk, 0, $chunk.Length) }
        $fs.Flush($true)
    } finally { $fs.Dispose() }
}

Write-Host ("Cible {0} | {1} threads | bloc {2} Ko | {3}% lectures | {4} s/itération | espace max utilisé {5:N0} Mo" -f `
    $Path, $Threads, $BlockSizeKB, $ReadPercent, $DurationSec, $maxUsedMB) -ForegroundColor Cyan
Write-Host ("{0,5} {1,10} {2,10} {3,10} {4,10} {5,10} {6,8}" -f "Iter","Lect MB/s","Ecr MB/s","Lect IOPS","Ecr IOPS","Libre Go","Erreurs") -ForegroundColor Yellow

$sum = @{ R = 0.0; W = 0.0; RI = 0.0; WI = 0.0; N = 0 }
$i = 0
try {
    while ($Iterations -eq 0 -or $i -lt $Iterations) {
        $i++
        [IoSim]::Reset()
        [IoSim]::Run($readFile, $writeDir, $Threads, $blockSize, $ReadPercent, $DurationSec, [int64]$WriteFileMB * 1MB)

        $rMB  = [IoSim]::RBytes / 1MB / $DurationSec
        $wMB  = [IoSim]::WBytes / 1MB / $DurationSec
        $rIO  = [IoSim]::ROps / $DurationSec
        $wIO  = [IoSim]::WOps / $DurationSec
        $err  = [IoSim]::Errors

        # --- Suppression des fichiers d'écriture entre itérations ---
        Get-ChildItem $writeDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        $freeGB = (Get-FreeBytes $Path) / 1GB

        Write-Host ("{0,5} {1,10:N1} {2,10:N1} {3,10:N0} {4,10:N0} {5,10:N1} {6,8}" -f $i,$rMB,$wMB,$rIO,$wIO,$freeGB,$err)

        if ($LogCsv) {
            [pscustomobject]@{ Time=(Get-Date -Format s); Iter=$i; ReadMBs=[math]::Round($rMB,2); WriteMBs=[math]::Round($wMB,2)
                               ReadIOPS=[int]$rIO; WriteIOPS=[int]$wIO; FreeGB=[math]::Round($freeGB,2); Errors=$err } |
                Export-Csv -Path $LogCsv -Append -NoTypeInformation
        }

        $sum.R += $rMB; $sum.W += $wMB; $sum.RI += $rIO; $sum.WI += $wIO; $sum.N++
        Start-Sleep -Seconds $PauseSec
    }
}
finally {
    # Nettoyage, même en cas de Ctrl+C
    Get-ChildItem $writeDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Remove-Item $writeDir -Force -ErrorAction SilentlyContinue
    if (-not $KeepReadSet) {
        Remove-Item $readFile -Force -ErrorAction SilentlyContinue
        Remove-Item $work -Force -ErrorAction SilentlyContinue
    }
    if ($sum.N -gt 0) {
        Write-Host ("`nMoyenne sur {0} itération(s) : lect {1:N1} MB/s ({2:N0} IOPS) | écr {3:N1} MB/s ({4:N0} IOPS)" -f `
            $sum.N, ($sum.R/$sum.N), ($sum.RI/$sum.N), ($sum.W/$sum.N), ($sum.WI/$sum.N)) -ForegroundColor Green
    }
}
