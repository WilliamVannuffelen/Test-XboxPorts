#Requires -Version 5.1

[cmdletBinding()]
param (
    [parameter(mandatory=$false)]
    [switch] $tcp,
    [parameter(mandatory=$false)]
    [switch] $udp,
    [parameter(mandatory=$false)]
    [string[]] $ports
)

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
        [int32] $exitCode,
        [object[]] $tcpListeners,
        [object[]] $udpClients
    )
    switch ($exitCode) {
        { $_ -ne 0 } { 
            $log.info("Script terminated due to a fatal exception.")
            $tcpListeners = $tcpPorts.foreach{
                if ($_) {
                    New-TcpListener -tcpPort $_
                }
            }
            $udpClients.foreach{
                if ($_) { 
                    Stop-UdpListener -udpClient $_
                }
            }
            exit 1
        }
        default { 
            $log.info("Script actions complete. Script terminated. Clean exit.")
            $udpClients.foreach{
                if ($_) { 
                    Stop-UdpListener -udpClient $_
                }
            }
            exit 0
        }
    }
}

function New-TcpListener {
    param (
        [string] $tcpPort
    )
    try {
        $endPoint = New-Object System.Net.IPEndpoint([System.Net.IPAddress]::Any, $tcpPort)
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endPoint
        $listener.start()
        $log.info("Started TCP listener on port '$tcpPort'.")
    }
    catch {
        $log.error(@("Failed to stop TCP listener on port '$tcpPort'.", $_.exception.message, $_.scriptStackTrace))
        return
    }

    return $listener
}

function Stop-TcpListener {
    param (
        [object] $tcpListener
    )
    try {
        $tcpPort = $tcpListener.localEndpoint.port
        $tcpListener.Stop()
        $log.info("Stopped TCP listener on port '$tcpPort'.")
    }
    catch {
        $log.error(@("Failed to stop TCP listener on port '$tcpPort'.", $_.exception.message, $_.scriptStackTrace))
    }
}

function New-UdpListener {
    param (
        [string] $udpPort
    )
    try {
        $endPoint = New-Object System.Net.IPEndpoint([System.Net.IPAddress]::Any, $udpPort)
        $udpClient = New-Object System.Net.Sockets.UdpClient -ArgumentList $udpPort
        $udpClient.client.receiveTimeout = 10000
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
        $log.info("Finished listening for data.")
    }
    catch {
        $log.error(@("Failed to listen for data.", $_.exception.message, $_.scriptStackTrace))
    }

    return $receivedData
}

function Stop-UdpListener {
    param (
        [object] $udpClient
    )
    try {
        $udpPort = $udpClient.client.localEndpoint.port
        $udpClient.Close()
        $log.info("Stopped UDP listener on port '$udpPort'.")
    }
    catch {
        $log.error(@("Failed to stop UDP listener on port '$udpPort'.", $_.exception.message, $_.scriptStackTrace))
    }
}

function New-ASCIIEncoding {
    param ()

    try {
        $asciiEncoding = New-Object System.Text.ASCIIEncoding -ErrorAction Stop
        $log.info("Instatiated ASCII encoding object.")
    }
    catch {
        $log.error(@("Failed to instantiate ASCII encoding object.", $_.exception.message, $_.scriptStackTrace))
        Stop-Script -exitCode 1
    }

    return $asciiEncoding
}

function Get-ASCIIString {
    param (
        [object] $asciiEncoding,
        [byte[]] $asciiBytes
    )
    try {
        $asciiString = $asciiEncoding.GetString($asciiBytes)
        $log.info("Converted byte array to ASCII string.")
    }
    catch {
        $log.error(@("Failed to convert byte array to ASCII string.", $_.exception.message, $_.scriptStackTrace))
    }
    
    return $asciiString
}

function Test-PortsInUse {
    param (
        [string[]] $ports,
        [bool] $tcp
    )

    if ($tcp) {
        try {
            $portsInUse = (Get-NetTCPConnection).localPort | Sort-Object -Unique
            $log.info("Queried for active TCP ports.")
        }
        catch {
            $log.error(@("Failed to query for active TCP ports.", $_.exception.message, $_.scriptStackTrace))
        }
    }
    else {
        try {
            $portsInUse = (Get-NetUDPEndpoint).localPort | Sort-Object -Unique
            $log.info("Queried for active UDP ports.")
        }
        catch {
            $log.error(@("Failed to query for active UDP ports.", $_.exception.message, $_.scriptStackTrace))
        }
    }

    $freePorts = New-Object System.Collections.ArrayList
    $ports.foreach{
        if ($_ -in $portsInUse) {
            $log.info("Selected port '$_' is in use, skipping.")
        }
        else {
            $log.info("Selected port '$_' is free.")
            [void]$freePorts.Add($_)
        }
    }

    if ($freePorts) {
        $log.info("Found $(($freePorts | Measure-Object).count) free ports out of selection.")
        $log.info("Tests will run on ports: $($freePorts -Join ', ').")
    }
    else {
        $log.info("None of the selected ports are currently free. Aborting checks.")
        Stop-Script -exitCode 0
    }
    return @($freePorts)
}

# Declare
$logFile = "$psScriptRoot\Logs\test_ports_server_log_$(Get-Date -Format 'yyyyMMdd').log"
$logLevel = "info" # options: debug, info, warn, error
$log = Import-PsLogger -logLevel $logLevel -logFile $logFile

#$tcpPorts = @("53", "80", "3074", "60209")
#$udpPorts = @("53", "88", "500", "3074", "3544", "4500")

# Invoke

if ($tcp) {
    $log.info("TCP switch detected. Running TCP tests.")
    if ($ports) {
        $tcpPorts = @($ports)
    }
    else {
        $tcpPorts = @("53", "80", "3074", "60209")
    }
    $tcpPorts = Test-PortsInUse -ports $tcpPorts -tcp $tcp

    $tcpListeners = $tcpPorts.foreach{
        if ($_) {
            New-TcpListener -tcpPort $_
        }
    }
    $log.info("Sleeping for 20 seconds.")
    Start-Sleep -Seconds 20

    $tcpListeners.foreach{
        Stop-TcpListener -tcpListener $_
    }

    $log.info("Finished with TCP tests.")
}

if ($udp) {
    $log.info("UDP switch detected. Running UDP tests.")
    if ($ports) {
        $udpPorts = @($ports)
    }
    else {
        $udpPorts = @("53", "88", "500", "3074", "3544", "4500")
    }
    $udpPorts = Test-PortsInUse -ports $udpPorts

    $udpClients = New-Object System.Collections.ArrayList
    $endPoints = New-Object System.Collections.ArrayList
    $asciiEncoding = New-ASCIIEncoding

    $udpPorts.foreach{
        $udpClient, $endPoint = New-UdpListener -udpPort $_
        [void]$udpClients.Add($udpClient)
        [void]$endPoints.Add($endPoint)
    }
    
    for ($i=0 ; $i -le $udpClients.Count ; $i++ ) {
        $receivedData = $null

        $endPoint = [ref]$endpoints[$i]
        if ($udpClients[$i]) {
            $log.info("UDP Client is now listening for port $($udpClients[$i].client.localEndpoint.port).")
            $receivedData = Start-UdpListener -udpClient $udpClients[$i] -endPoint $endPoint
            if ($receivedData) {
                $receivedString = Get-ASCIIString -asciiBytes $receivedData -asciiEncoding $asciiEncoding
                $receivedString
                $log.info("Received data: '$receivedString'.")
            }
            else {
                $log.info("Did not receive any data.")
            }
        }
    }
   
    $udpClients.foreach{
        if ($_) { 
            Stop-UdpListener -udpClient $_
        }
    }

    $log.info("Finished with UDP tests.")
}