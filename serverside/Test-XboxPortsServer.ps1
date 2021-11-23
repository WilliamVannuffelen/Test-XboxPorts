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
        return
    }

    return $listener
}

function New-UdpListener {
    param (
        [string] $udpPort
    )
    try {
        $endPoint = New-Object System.Net.IPEndpoint([System.Net.IPAddress]::Any, $udpPort)
        $udpClient = New-Object System.Net.Sockets.UdpClient -ArgumentList $udpPort
        $udpClient.client.receiveTimeout = 100000
        #$udpClient.client.blocking = $false
        $log.info("Created UDP listener on port '$udpPort'.")
    }
    catch {
        $log.error(@("Failed to create listener on UDP port '$udpPort'.", $_.exception.message, $_.scriptStackTrace))
        return
    }

    return $udpClient, $endPoint
}

function Start-UdpListener {
    param (
        [object] $udpClient,
        [ref] $endPoint
    )

    $log.info("Starting UDP listener on port '$($udpClient.client.localEndpoint.port)'.")
    try {
        $receivedData = $udpClient.Receive($endPoint)
        $log.info("Received data.")
    }
    catch {
        $log.error(@("Failed to receive data.", $_.exception.message, $_.scriptStackTrace))
    }

    return $receivedData
}

# Declare
$logFile = "$psScriptRoot\Logs\script_log_$(Get-Date -Format 'yyyyMMdd').log"
$logLevel = "info" # options: debug, info, warn, error
$log = Import-PsLogger -logLevel $logLevel -logFile $logFile

$tcpPorts = @("53", "80", "3074", "60209")
$udpPorts = @("53", "88", "500", "3074", "3544", "4500")

<#
$tcpListeners = $tcpPorts.foreach{
    New-TcpListener -tcpPort $_
}
#>

$udpClients = New-Object System.Collections.ArrayList
$endPoints = New-Object System.Collections.ArrayList

$udpPorts[0..1].foreach{
    $udpClient, $endPoint = New-UdpListener -udpPort $_
    [void]$udpClients.Add($udpClient)
    [void]$endPoints.Add($endPoint)
}

for ($i=0 ; $i -le $udpClients.Count ; $i++ ) {
    $endPoint = [ref]$endpoints[$i]
    $receivedData = Start-UdpListener -udpClient $udpClients[$i] -endPoint $endPoint
    [Text.Encoding]::ASCII.GetString($receivedData)
} 


$udpClients.foreach{$_.Close()}