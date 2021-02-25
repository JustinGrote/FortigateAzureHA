//Hacky workaround to get the GatewayIP since it is not available as a resource or from a route table as far as I can tell
param subnetAddress string

var IPArray = split(subnetAddress, '.')
var IPArray2ndString = string(IPArray[3])
var IPArray2nd = split(IPArray2ndString, '/')
var IPArray3 = string((int(IPArray2nd[0]) + 1))
var IPArray2 = string(int(IPArray[2]))
var IPArray1 = string(int(IPArray[1]))
var IPArray0 = string(int(IPArray[0]))
var GatewayIP = '${IPArray0}.${IPArray1}.${IPArray2}.${IPArray3}'

output gatewayIP string = GatewayIP