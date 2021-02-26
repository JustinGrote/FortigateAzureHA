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
param lbInternalSubnetIP string {
  metadata: {
    description: 'The port to use for accessing the http management interface of the first Fortigate'
  }
  default: ''
}
param fortimanagerFqdn string {
  metadata: {
    description: 'Fully Qualified DNS Name of the Fortimanager appliance. The fortigates will auto-register with this fortigate upon startup'
  }
  default: ''
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
param publicIPID string {
  metadata: {
    description: 'Resource ID of the Public IP to use for the outbound traffic and inbound management. A standard static SKU Public IP is required. Default is to generate a new one'
  }
  default: ''
}


resource pip 'Microsoft.Network/publicIPAddresses@2020-05-01' = if (empty(publicIPID)) {
  name: lbName
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
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
            id: empty(publicIPID) ? pip.id : publicIPID
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
          privateIPAllocationMethod: empty(lbInternalSubnetIP) ? 'Dynamic' : 'Static'
          privateIPAddress: empty(lbInternalSubnetIP) ? json('null') : lbInternalSubnetIP
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

output publicIpFqdn string = empty(publicIPID) ? pip.properties.dnsSettings.fqdn : reference(publicIPID,'2020-05-01').dnsSettings.fqdn