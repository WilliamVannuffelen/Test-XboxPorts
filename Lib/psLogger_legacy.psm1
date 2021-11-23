#Requires -Version 4.0
<#
.SYNOPSIS
Basic module to make boilerplate code required for logging cleaner.
Intended to be similar in usage to python's logging.
.PARAMETER logLevel
Determines what messages are to be logged.
Options: debug, info, warn, error
Default: info
.PARAMETER logFile
The full path of the file to which the logs should be written.
.EXAMPLE
Basic example
1. Import the module as a custom object.
$logLevel = "debug"
$logFile = "$psScriptRoot\Logs\example_log.txt"
$log = Import-Module -Name "$psScriptRoot\PsLogger_legacy.psm1" -AsCustomObject -ArgumentList ($logLevel, $logFile) -Force -ErrorAction Stop
2. Use script methods on the object to log. Can take a string or an array of strings.
$log.debug("Trying to do a thing.")
$log.info("Successfully did a thing.")
$log.warn("Doing a thing is taking longer than expected.")
$log.error(@("Failed to do a thing..", $_.exception.message, $_.scriptStackTrace))
.EXAMPLE
Full code snippet to import module:
function Import-PsLogger {
    param(
        [string] $logLevel,
        [string] $logFile
    )
    $PSDefaultParameterValues = @{'Out-File:Encoding' = 'utf8'}
    try {
        $log = Import-Module -Name "$psScriptRoot\PsLogger_legacy.psm1" -AsCustomObject -ArgumentList ($logLevel, $logFile) -Force -ErrorAction Stop
        "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss -') INFO: Imported legacy psLogger module." | Out-File -FilePath $logFile -Append
    }
    catch {
        "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss -') ERROR: Failed to import legacy psLogger. Terminating." | Tee-Object -FilePath $logFile -Append | Out-Host
        $_.exception.message | Tee-Object -FilePath $logFile -Append | Out-Host
        exit
    }
    return $log
}
$logFile = "$psScriptRoot\Logs\script_log_$(Get-Date -Format 'yyyyMMdd').log"
$logLevel = "info" # options: debug, info, warn, error
$log = Import-PsLogger -logLevel $logLevel -logFile $logFile
#>

[cmdletBinding()]
param (
    [parameter(mandatory=$false)]
    [validateSet('debug', 'info', 'warn', 'error')]
    [string] $logLevel = "info",

    [parameter(mandatory=$true)]
    [validateScript({
        if ((Test-Path ([System.IO.DirectoryInfo]$_).parent.fullName) -and (-not (Test-Path -Path $_ -PathType Container))) {
            $true
        }
        else {
            throw "InvalidPathError - Either full path to file does not exist, or a directory was specified."
        }
    })]
    [string] $logFile
)

function Get-TimeStamp {
    [cmdletBinding()]
    param(
        [string] $logLevel
    )
    return "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($logLevel.ToUpper()):"
}


function Write-LogEntry {
    [cmdletBinding()]
    param(
        [string] $logString
    )
    
    try {
        $logString | Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        throw
    }
}

function debug {
    [cmdletBinding()]
    param(
        [string[]] $messages
    )
    
    if ($logLevel -in @("debug")) {
        $messages.foreach{
            Write-LogEntry "$(Get-TimeStamp -logLevel 'debug') $_"
        }
    }
}

function info {
    [cmdletBinding()]
    param(
        [string[]] $messages
    )

    if ($logLevel -in @("debug", "info")) {
        $messages.foreach{
            Write-LogEntry "$(Get-TimeStamp -logLevel 'info') $_"
        }
    }
}

function warn {
    [cmdletBinding()]
    param(
        [string[]] $messages
    )
    
    if ($logLevel -in @("debug", "info", "warn")) {
        $messages.foreach{
            Write-LogEntry "$(Get-TimeStamp -logLevel 'warn') $_"
        }
    }
}

function error {
    [cmdletBinding()]
    param(
        [string[]] $messages
    )

    if ($logLevel -in @("debug", "info", "warn", "error")) {
        $messages.foreach{
            Write-LogEntry "$(Get-TimeStamp -logLevel 'error') $_"
        }
    }
}

Export-ModuleMember -Function debug, info, warn, error