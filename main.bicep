param location string {
  metadata: {
    description: 'Which Azure Location (Region) to deploy to. Defaults to the same region as the resource group'
  }
  default: resourceGroup().location
}
param fgNamePrefix string {
  metadata: {
    description: 'Name for FortiGate virtual appliances (A & B will be appended to the end of each respectively).'
  }
}
param adminUsername string {
  metadata: {
    description: 'Username for the Fortigate virtual appliances.'
  }
  default: 'fgadmin'
}
param adminPassword string {
  metadata: {
    description: 'Password for the Fortigate virtual appliances.'
  }
  secure: true
}
param bringYourOwnLicense bool {
  metadata: {
    description: 'Specify true for a Bring Your Own License (BYOL) deployment, otherwise the fortigate license will be included in the VM subscription cost'
  }
  default: false
}
param useSpotInstances bool {
  metadata: {
    description: 'Use spot instances to save cost at the expense of potential reduced availability. Availability set will be disabled with this option'
  }
  default: false
}
param fgVersion string {
  metadata: {
    description: 'Specify the version to use e.g. 6.4.2. Defaults to latest version'
  }
  default: 'latest'
}
param FortinetTags object = {
  provider: '6EB3B02F-50E5-4A3E-8CB8-2E129258317D'
}

var deploymentName = deployment().name

resource fgAdminNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: fgNamePrefix
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  properties: {
    securityRules: [
      {
        name: 'AllowAllInbound'
        properties: {
          description: 'Allow all in'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all out'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 105
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource fgSet 'Microsoft.Compute/availabilitySets@2019-07-01' = if (!useSpotInstances) {
  name: fgNamePrefix
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 2
  }
}

module network './network.bicep' = {
  name: '${deploymentName}-network'
}

module loadbalancer './loadbalancer.bicep' = {
  name: '${deploymentName}-loadbalancer'
  params: {
    lbName: fgNamePrefix
    internalSubnet: network.outputs.internalSubnet
    externalSubnet: network.outputs.externalSubnet
  }
}

var fgImageSku = bringYourOwnLicense ? 'fortinet_fg-vm' : 'fortinet_fg-vm_payg_20190624'
module fortigateA './fortigate.bicep' = {
  name: '${deploymentName}-fortigateA'
  params: {
    location: location
    vmName: '${fgNamePrefix}A'
    adminUsername: adminUsername
    adminPassword: adminPassword
    FortigateImageSKU: fgImageSku
    FortigateImageVersion: fgVersion
    adminNsgId: fgAdminNsg.id
    availabilitySetId: empty(fgSet.id) ? fgSet.id : ''
    loadBalancerInfo: loadbalancer.outputs.fortigateALoadBalancerInfo
    externalSubnet: network.outputs.externalSubnet
    internalSubnet: network.outputs.internalSubnet
  }
}
module fortigateB './fortigate.bicep' = {
  name: '${deploymentName}-fortigateB'
  params: {
    location: location
    vmName: '${fgNamePrefix}B'
    adminUsername: adminUsername
    adminPassword: adminPassword
    FortigateImageSKU: fgImageSku
    FortigateImageVersion: fgVersion
    adminNsgId: fgAdminNsg.id
    availabilitySetId: empty(fgSet.id) ? fgSet.id : ''
    loadBalancerInfo: loadbalancer.outputs.fortigateBLoadBalancerInfo
    externalSubnet: network.outputs.externalSubnet
    internalSubnet: network.outputs.internalSubnet
  }
}
