param VnetName string = resourceGroup().name
param Location string = resourceGroup().location

@description('Virtual Network Address prefix')
param VnetAddressPrefixes array = [
  '10.0.0.0/16'
]

@description('Subnet 1 Name')
param ExternalSubnetName string = 'External'

@description('Subnet 1 Prefix')
param ExternalSubnetPrefix string = '10.0.1.0/24'

@description('Subnet 2 Name')
param InternalSubnetName string = 'Transit'

@description('Subnet 2 Prefix')
param InternalSubnetPrefix string = '10.0.2.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: VnetName
  location: Location
  properties: {
    addressSpace: {
      addressPrefixes: VnetAddressPrefixes
    }
    subnets: [
      {
        name: ExternalSubnetName
        properties: {
          addressPrefix: ExternalSubnetPrefix
        }
      }
      {
        name: InternalSubnetName
        properties: {
          addressPrefix: InternalSubnetPrefix
        }
      }
    ]
  }
}

output externalSubnet object = vnet.properties.subnets[0]
output internalSubnet object = vnet.properties.subnets[1]