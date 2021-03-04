@description('SubnetId for the internal (port2) interface')
param InternalSubnetId string

// Optional
@description('Base name prefix for the load balancers')
param LbName string = resourceGroup().name

@description('Deployment location')
param Location string = resourceGroup().location

@description('The IP address that the load balancer should request on the internal subnet. This address will be used for User Defined Routes. It does not explicitly need to be specified unless you are replacing an existing installation.')
param LbInternalSubnetIP string = ''

@description('The port to use for accessing the http management interface of the first Fortigate')
param FgaManagementHttpPort int = 50443

@description('The port to use for accessing the http management interface of the second Fortigate')
param FgbManagementHttpPort int = 51443

@description('The port to use for accessing the ssh management interface of the first Fortigate')
param FgaManagementSshPort int = 50022

@description('The port to use for accessing the ssh management interface of the second Fortigate')
param FgbManagementSshPort int = 51022

@description('Resource ID of the Public IP to use for the outbound traffic and inbound management. A standard static SKU Public IP is required. Default is to generate a new one')
param PublicIPID string = ''

param FortinetTags object = {
  provider: '6EB3B02F-50E5-4A3E-8CB8-2E129258317D'
}

resource pip 'Microsoft.Network/publicIPAddresses@2020-05-01' = if (empty(PublicIPID)) {
  name: LbName
  location: Location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${LbName}-${substring(uniqueString(LbName), 0, 4)}')
    }
  }
}

var externalLBFEName = 'default'
var externalLBBEName = 'default'
resource externalLB 'Microsoft.Network/loadBalancers@2020-05-01' = {
  name: LbName
  location: Location
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
            id: empty(PublicIPID) ? pip.id : PublicIPID
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
    outboundRules: [
      {
        name: 'default'
        properties: {
          allocatedOutboundPorts: 0
          protocol: 'All'
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', LbName, externalLBBEName)
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', LbName, externalLBFEName)
            }
          ]
        }
      }
    ]
    inboundNatRules: [
      {
        name: '${LbName}A-Management-SSH'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', LbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: FgaManagementSshPort
          backendPort: 22
          enableFloatingIP: false
        }
      }
      {
        name: '${LbName}A-Management-HTTPS'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', LbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: FgaManagementHttpPort
          backendPort: 443
          enableFloatingIP: false
        }
      }
      {
        name: '${LbName}B-Management-SSH'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', LbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: FgbManagementSshPort
          backendPort: 22
          enableFloatingIP: false
        }
      }
      {
        name: '${LbName}B-Management-HTTPS'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', LbName, externalLBFEName)
          }
          protocol: 'Tcp'
          frontendPort: FgbManagementHttpPort
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

var internalLBName = '${LbName}Internal'
var internalLBFEName = 'default'
var internalLBBEName = 'default'
var lbProbeName = 'default'
var lbRuleName = 'default'
resource internalLB 'Microsoft.Network/loadBalancers@2020-05-01' = {
  name: internalLBName
  location: Location
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
          privateIPAllocationMethod: empty(LbInternalSubnetIP) ? 'Dynamic' : 'Static'
          privateIPAddress: empty(LbInternalSubnetIP) ? json('null') : LbInternalSubnetIP
          subnet: {
            id: InternalSubnetId
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
  name: LbName
  location: Location
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

output publicIpFqdn string = empty(PublicIPID) ? pip.properties.dnsSettings.fqdn : reference(PublicIPID,'2020-05-01').dnsSettings.fqdn