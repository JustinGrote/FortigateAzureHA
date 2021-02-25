param lbName string {
  metadata: {
    description: 'Base name prefix for the load balancers'
  }
}
param externalSubnet object {
  metadata: {
    description: 'Subnet for the external (port1) interface'
  }
}
param internalSubnet object {
  metadata: {
    description: 'Subnet for the internal (port2) interface'
  }
}
param location string {
  metadata: {
    description: 'Which Azure Location (Region) to deploy to. Defaults to the same region as the resource group'
  }
  default: resourceGroup().location
}

// Optional
param FortinetTags object = {
  provider: '6EB3B02F-50E5-4A3E-8CB8-2E129258317D'
}
param publicIPAddressName string {
  metadata: {
    description: 'Name of Public IP address element.'
  }
  default: lbName
}
//TODO: Change to bool
param publicIpAllocationMethod string {
  allowed: [
    'Static'
    'Dynamic'
  ]
  metadata: {
    description: 'Dynamic public IPs change on reboot'
  }
  default: 'Static'
}
param fgaManagementHttpPort int {
  metadata: {
    description: 'The port to use for accessing the http management interface of the first Fortigate'
  }
  default: 50443
}
param fgbManagementHttpPort int {
  metadata: {
    description: 'The port to use for accessing the http management interface of the second Fortigate'
  }
  default: 51443
}
param fgaManagementSshPort int {
  metadata: {
    description: 'The port to use for accessing the ssh management interface of the first Fortigate'
  }
  default: 50022
}
param fgbManagementSshPort int {
  metadata: {
    description: 'The port to use for accessing the ssh management interface of the first Fortigate'
  }
  default: 51022
}


resource pip 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: lbName
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: publicIpAllocationMethod
    dnsSettings: {
      domainNameLabel: toLower('${lbName}-${substring(uniqueString(lbName), 0, 4)}')
    }
  }
}


var externalLBFEName = 'default'
var externalLBBEName = 'default'
resource externalLB 'Microsoft.Network/loadBalancers@2020-05-01' = {
  name: lbName
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: externalLBFEName
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: externalLBBEName
      }
    ]
    loadBalancingRules: []
    inboundNatRules: [
      {
        name: '${lbName}A-Management-SSH'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: fgaManagementSshPort
          backendPort: 22
          enableFloatingIP: false
        }
      }
      {
        name: '${lbName}A-Management-HTTPS'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: fgaManagementHttpPort
          backendPort: 443
          enableFloatingIP: false
        }
      }
      {
        name: '${lbName}B-Management-SSH'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: fgbManagementSshPort
          backendPort: 22
          enableFloatingIP: false
        }
      }
      {
        name: '${lbName}B-Management-HTTPS'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: fgbManagementHttpPort
          backendPort: 443
          enableFloatingIP: false
        }
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 8008
          intervalInSeconds: 5
          numberOfProbes: 2
        }
        name: 'lbprobe'
      }
    ]
  }
}

var internalLBName = '${lbName}Internal'
var internalLBFEName = 'default'
var internalLBBEName = 'default'
var lbProbeName = 'default'
var lbRuleName = 'default'
resource internalLB 'Microsoft.Network/loadBalancers@2020-05-01' = {
  name: internalLBName
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: internalLBFEName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: internalSubnet.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: internalLBBEName
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', internalLBName, internalLBFEName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLBName, internalLBBEName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', internalLBName, lbProbeName)
          }
          protocol: 'All'
          frontendPort: 0
          backendPort: 0
          enableFloatingIP: true
          idleTimeoutInMinutes: 15
        }
        name: lbRuleName
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 8008
          intervalInSeconds: 5
          numberOfProbes: 2
        }
        name: lbProbeName
      }
    ]
  }
}


resource routeTable2Name 'Microsoft.Network/routeTables@2020-05-01' = {
  name: lbName
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  properties: {
    routes: [
      {
        name: internalLB.name
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: internalLB.properties.frontendIPConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}
output fortigateALoadBalancerInfo object = {
  externalBackendId: externalLB.properties.backendAddressPools[0].id
  internalBackendId: internalLB.properties.backendAddressPools[0].id
  natrules: [
    {
      id: externalLB.properties.inboundNatRules[0].id
    }
    {
      id: externalLB.properties.inboundNatRules[1].id
    }
  ]
}

output fortigateBLoadBalancerInfo object = {
  externalBackendId: externalLB.properties.backendAddressPools[0].id
  internalBackendId: internalLB.properties.backendAddressPools[0].id
  natrules: [
    {
      id: externalLB.properties.inboundNatRules[2].id
    }
    {
      id: externalLB.properties.inboundNatRules[3].id
    }
  ]
}
