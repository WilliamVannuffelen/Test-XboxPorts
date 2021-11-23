function Import-PsLogger {
    param(
        [string] $logLevel,
        [string] $logFile
    )
    $PSDefaultParameterValues = @{'Out-File:Encoding' = 'utf8'}
    try {
        $log = Import-Module -Name "$psScriptRoot\Lib\PsLogger_legacy.psm1" -AsCustomObject -ArgumentList ($logLevel, $logFile) -Force -ErrorAction Stop
        "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss -') INFO: Imported legacy psLogger module." | Out-File -FilePath $logFile -Append
    }
    catch {
        "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss -') ERROR: Failed to import legacy psLogger. Terminating." | Tee-Object -FilePath $logFile -Append | Out-Host
        $_.exception.message | Tee-Object -FilePath $logFile -Append | Out-Host
        exit
    }
    return $log
}

function Stop-Script {
    param(
        [int32] $exitCode
    )
    switch ($exitCode) {
        { $_ -ne 0 } { 
            $log.info("Script terminated due to a fatal exception.")
            exit 1 
        }
        default { 
            $log.info("Script actions complete. Script terminated. Clean exit.")
            exit 0
        }
    }
}

function New-TcpListener {
    param (
        [string] $tcpPort
    )
    try {
        $endPoint = New-Object System.Net.Endpoint([System.Net.IPAddress]::Any, $tcpPort)
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endPoint
        $listener.start()
        $log.info("Started listener on TCP port '$tcpPort'.")
    }
    catch {
        $log.error(@("Failed to start listener on TCP port '$tcpPort'.", $_.exception.message, $_.scriptStackTrace))
    }

    return $listener
}

# Declare
$logFile = "$psScriptRoot\Logs\script_log_$(Get-Date -Format 'yyyyMMdd').log"
$logLevel = "info" # options: debug, info, warn, error
$log = Import-PsLogger -logLevel $logLevel -logFile $logFile

$tcpPorts = @("53", "80", "3074", "60209")
$udpPorts = @("53", "88", "500", "3074", "3544", "4500")


$port = 2020
$endpoint = new-object System.Net.IPEndPoint ([IPAddress]::Any,$port)
$udpclient = new-Object System.Net.Sockets.UdpClient $port
$content = $udpclient.Receive([ref]$endpoint)
[Text.Encoding]::ASCII.GetString($content)