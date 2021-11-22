# udp 88
# udp 3074
# udp 53
# udp 500
# udp 3544
# udp 4500

# tcp 3074
# tcp 53
# tcp 80
# tcp 60209


function Test-TcpPort {
    param(
        [string] $ipAddress,
        [string] $tcpPort
    )

    $res = Test-NetConnection -ipAddress $ipAddress -port $tcpPort

    return [psCustomobject]@{
        tcpPort = $res.remotePort
        success = $tcpTestSucceeded
    }
}

$tcpPorts = @("53", "80", "3074", "60209")
$udpPorts = @("53", "88", "500", "3074", "3544", "4500")