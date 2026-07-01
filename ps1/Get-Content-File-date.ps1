param(
    [Parameter(Mandatory=$true)]
    [string]$logfile,
    [Parameter(Mandatory=$true)]
    [datetime]$startdate,
    [Parameter(Mandatory=$true)]
    [datetime]$enddate
)

$regex = '^(?<date>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'
Get-Content $logfile | ForEach-Object {
    if ($_ -match $regex) {
        $logDate = [datetime]::ParseExact($matches['date'], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($logDate -ge $startdate -and $logDate -le $enddate) {
            $_
        }
    }
}