# Test-XboxPorts

## Overview- General

Designed to test TCP and UDP ports requiring to be forwarded for Xbox Live - specifically Forza Horizon 5.

Consists of a client-side and server-side script.

Run the server-side script which:
- creates TCP listeners for 20 seconds, then terminates them
- creates a UDP listener for 10 seconds, then terminates it

Then run the client-side script within those timeframes to validate.


## Usage & Examples

First clone the repo to your client and server. The script expects the logging module in Lib/ and the Logs directory to be present.

You can provide a specific port, or list of ports to check for TCP. If nothing is specified the default ports required for FH5 will be checked:
"53", "80", "3074". 

In addition to the above you need to choose a port from the dynamic high range which is to be defined by your teredo adapter. In this case the default used is "60209".

Currently there's no support for testing multiple UDP ports at once. Please test the following ports 1-by-1:
"53", "88", "500", "3074", "3544", "4500"

### Server-side
```ps
# Test default TCP ports
.\Test-XboxPortsServer.ps1 -tcp
# No output will be shown. Successful connection to be verified client-side.

# Test custom TCP ports
.\Test-XboxPortsServer.ps1 -tcp -ports 53,80,49999
# No output will be shown. Successful connection to be verified client-side.

# Test custom UDP port
.\Test-XboxPortsServer.ps1 -udp -ports 53
# If successful, you should see the following output in your terminal:
"Hello Bennett - Testing UDP port '53'."
```

### Client-side

```ps
# Test default TCP ports
.\Test-XboxPorts.ps1 -tcp
# Check the log file in ./Logs/ for the results.

# Test custom TCP ports
.\Test-XboxPorts.ps1 -tcp -ports 53,80
# Check the log file in ./Logs/ for the results.

# Test UDP port
.\Test-XboxPorts.ps1 -udp -ports 53
# Validation of successful UDP datagram delivery to be done server-side.

```