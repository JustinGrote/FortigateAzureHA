//Hacky workaround to get various IPs since it is not available as a resource or from a route table as far as I can tell
param subnetAddress string
//Optionally specify what the last octet should be. If not specified gets the first address in the range
param lastOctet int = -1

var IPArray = split(subnetAddress, '.')
var IPArray2ndString = string(IPArray[3])
var IPArray2nd = split(IPArray2ndString, '/')

var IPArray0 = string(int(IPArray[0]))
var IPArray1 = string(int(IPArray[1]))
var IPArray2 = string(int(IPArray[2]))
var IPArray3 = lastOctet == -1 ? string((int(IPArray2nd[0]) + 1)) : lastOctet

var ResultIP = '${IPArray0}.${IPArray1}.${IPArray2}.${IPArray3}'

output IP string = ResultIP