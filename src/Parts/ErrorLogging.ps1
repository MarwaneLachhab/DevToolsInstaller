# Error logging helpers to persist runtime errors to a file
if (-not $script:runtimeErrorTranscriptStarted) { $script:runtimeErrorTranscriptStarted = $false }
if (-not $script:runtimeErrorLogPath) { $script:runtimeErrorLogPath = $null }

function Start-ErrorCapture {
    param(
        [string]$LogDir = (Join-Path $PSScriptRoot "..\\Logs")
    )

    if ($script:runtimeErrorTranscriptStarted) {
        return $script:runtimeErrorLogPath
    }

    $fileName = "runtime_errors_{0}.log" -f (Get-Date -Format "yyyy-MM-dd")
    $logPath = Join-Path $LogDir $fileName

    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        }

        Start-Transcript -Path $logPath -Append -ErrorAction Stop | Out-Null
        $script:runtimeErrorTranscriptStarted = $true
        $script:runtimeErrorLogPath = $logPath
        try { Write-Log "Error capture enabled. Transcript: $logPath" "INFO" } catch { }
    } catch {
        try { Write-Log "Failed to start error capture transcript: $($_.Exception.Message)" "ERROR" } catch { }
    }

    return $script:runtimeErrorLogPath
}

function Stop-ErrorCapture {
    if (-not $script:runtimeErrorTranscriptStarted) { return }
    try { Stop-Transcript | Out-Null } catch { }
    $script:runtimeErrorTranscriptStarted = $false
}

function Report-UnhandledError {
    param(
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    $message = if ($ErrorRecord.Exception) { $ErrorRecord.Exception.Message } else { $ErrorRecord.ToString() }
    try { Write-Log "Unhandled error: $message" "ERROR" } catch { }
}
