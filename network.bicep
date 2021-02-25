param vnetName string = 'TestVNet'
param location string = resourceGroup().location
param vnetAddressPrefixes array {
  metadata: {
    description: 'Virtual Network Address prefix'
  }
  default: [
    '10.0.0.0/16'
  ]
}
param externalSubnetName string {
  metadata: {
    description: 'Subnet 1 Name'
  }
  default: 'External'
}
param externalSubnetPrefix string {
  metadata: {
    description: 'Subnet 1 Prefix'
  }
  default: '10.0.1.0/24'
}
param internalSubnetName string {
  metadata: {
    description: 'Subnet 2 Name'
  }
  default: 'Transit'
}
param internalSubnetPrefix string {
  metadata: {
    description: 'Subnet 2 Prefix'
  }
  default: '10.0.2.0/24'
}

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