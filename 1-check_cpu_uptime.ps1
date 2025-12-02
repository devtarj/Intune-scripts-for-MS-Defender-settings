param([int]$ThresholdHours = 1)

# Keep everything quiet and fast
$ErrorActionPreference = 'SilentlyContinue'

# Try to get the last resume (wake) time from the System log (Power-Troubleshooter, Event ID 1)
$lastResume = $null
try {
    $e = Get-WinEvent -FilterHashtable @{
        LogName='System'
        ProviderName='Microsoft-Windows-Power-Troubleshooter'
        Id=1
    } -MaxEvents 1
    if ($e) { $lastResume = $e.TimeCreated }
} catch {}

# Always get last boot as a fallback/reference
$lastBoot = try { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } catch { $null }

# Choose reference start:
# Prefer lastResume if it exists and is after lastBoot; otherwise use lastBoot; otherwise "now" (to avoid false positives)
$referenceStart = if ($lastResume -and $lastBoot -and ($lastResume -gt $lastBoot)) {
    $lastResume
} elseif ($lastResume) {
    $lastResume
} elseif ($lastBoot) {
    $lastBoot
} else {
    Get-Date
}

$uptimeHours = [math]::Round(((Get-Date) - $referenceStart).TotalHours, 2)

# Label the source used
$source =
    if     ($lastResume -and $referenceStart -eq $lastResume) { "Since last resume" }
    elseif ($lastBoot   -and $referenceStart -eq $lastBoot)   { "Since boot" }
    else                                                      { "Unknown (fallback)" }

# Build output for IME logs / portal
$payload = [pscustomobject]@{
    thresholdHours = $ThresholdHours
    uptimeHours    = $uptimeHours
    lastBoot       = $lastBoot
    lastResume     = $lastResume
    referenceStart = $referenceStart
    overThreshold  = ($uptimeHours -ge $ThresholdHours)
    source         = $source
}

$payload | ConvertTo-Json -Compress | Write-Output

# Exit codes for Intune PR:
# 0 = compliant (< threshold) ; 1 = non-compliant (>= threshold)
if ($payload.overThreshold) { exit 1 } else { exit 0 }
