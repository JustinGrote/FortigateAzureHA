param vnetName string = resourceGroup().name
param location string = resourceGroup().location

@description('Virtual Network Address prefix')
param vnetAddressPrefixes array = [
  '10.0.0.0/16'
]

@description('Subnet 1 Name')
param externalSubnetName string = 'External'

@description('Subnet 1 Prefix')
param externalSubnetPrefix string = '10.0.1.0/24'

@description('Subnet 2 Name')
param internalSubnetName string = 'Transit'

@description('Subnet 2 Prefix')
param internalSubnetPrefix string = '10.0.2.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [
      {
        name: externalSubnetName
        properties: {
          addressPrefix: externalSubnetPrefix
        }
      }
      {
        name: internalSubnetName
        properties: {
          addressPrefix: internalSubnetPrefix
        }
      }
    ]
  }
}

output externalSubnet object = vnet.properties.subnets[0]
output internalSubnet object = vnet.properties.subnets[1]