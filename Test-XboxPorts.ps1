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


function Test-TcpPort {
    param (
        [string] $ipAddress,
        [string] $tcpPort
    )

    try {
        $res = Test-NetConnection -ipAddress $ipAddress -port $tcpPort -ErrorAction Stop
        $log.info("Tested connectivity to port '$tcpPort'.")
    }
    catch {
        $log.error(@("Failed to test connectivity to port '$tcpPort'.", $_.exception.message, $_.scriptStackTrace))
        Stop-Script -exitCode 1
    }
    
    return [psCustomobject]@{
        tcpPort = $res.remotePort
        success = $tcpTestSucceeded
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

function Get-ASCIIBytes { 
    param (
        [object] $asciiEncoding,
        [string] $asciiString
    )
    try {
        $asciiBytes = $asciiEncoding.GetBytes($asciiString)
        $log.info("Converted ASCII string '$asciiString' to byte array.")
    }
    catch {
        $log.error(@("Failed to convert ASCII string to byte array.", $_.exception.message, $_.scriptStackTrace))
        Stop-Script -exitCode 1
    }

    return $asciiBytes
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
        Stop-Script -exitCode 1
    }
    
    return $asciiString
}

function Test-UdpPort { 
    param (
        [string] $ipAddress,
        [string] $udpPort,
        [byte[]] $message,
        [ref] $remoteEndpoint
    )

    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient(11000)
        $udpClient.client.ReceiveTimeout = 10000
        $log.info("Started UDP client with 10 second timeout.")
    }
    catch {
        $log.error(@("Failed to start UDP client.", $_.exception.message, $_.scriptStackTrace))
        Stop-Script -exitCode 1
    }

    try {
        $udpClient.Connect($ipAddress, $udpPort)
        $log.info("Connected to UDP port '$udpPort'.")
    }
    catch {
        $log.error(@("Failed to connect to UDP port '$udpPort'.", $_.exception.message, $_.scriptStackTrace))
        Stop-Script -exitCode 1
    }

    try { 
        [void]$udpClient.Send($message, $message.length)
        $log.info("Sent data to target UDP port '$udpPort'.")
    }
    catch {
        $log.error(@("Failed to send data to target UDP port '$udpPort'.", $_.exception.message, $_.scriptStackTrace))
    }

    try {
        $receivedBytes = $udpClient.Receive($remoteEndpoint)
        $log.info("Successfully sent test data to target UDP endpoint.")
    }
    catch [SocketException] {
        if ($_.excepion.message -match "An existing connection was forcibly closed by the remote host") {
            $log.warn(@("Failed to send data to target UDP port '$udpPort'. This means nothing is listening on the port.", $_.exception.message, $_.scriptStackTrace))
        }
        else {
            $log.error(@("Failed to receive data from target UDP port '$udpPort'.", $_.exception.message, $_.scriptStackTrace))
        }
    }


    return $receivedBytes
}

# Declare
$logFile = "$psScriptRoot\Logs\script_log_$(Get-Date -Format 'yyyyMMdd').log"
$logLevel = "info" # options: debug, info, warn, error
$log = Import-PsLogger -logLevel $logLevel -logFile $logFile

$tcpPorts = @("53", "80", "3074", "60209")
$udpPorts = @("53", "88", "500", "3074", "3544", "4500")

$message = "Hello Bennett, testing UDP!"

# Init
$asciiEncoding = New-ASCIIEncoding
$messageBytes = Get-ASCIIBytes -asciiEncoding $asciiEncoding -asciiString $message
$remoteEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)

# Invoke
$receivedBytes = Test-UdpPort -ipAddress "127.0.0.1" -udpPort '12345' -message $messageBytes -remoteEndpoint ([ref]$remoteEndpoint)
$receivedMessage = Get-ASCIIString -asciiEncoding $asciiEncoding -asciiBytes $receivedBytes


