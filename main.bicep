// Mandatory Parameters
param fgNamePrefix string {
  metadata: {
    description: 'Name for FortiGate virtual appliances (A & B will be appended to the end of each respectively).'
  }
}
param adminPassword string {
  metadata: {
    description: 'Password for the Fortigate virtual appliances.'
  }
  secure: true
}

// Optional Parameters
param location string {
  metadata: {
    description: 'Which Azure Location (Region) to deploy to. Defaults to the same region as the resource group'
  }
  default: resourceGroup().location
}
param publicIPID string {
  metadata: {
    description: 'Resource ID of the Public IP to use for the outbound traffic and inbound management. A standard static SKU Public IP is required. Default is to generate a new one'
  }
  default: ''
}
param fortimanagerFqdn string {
  metadata: {
    description: 'Fully Qualified DNS Name of the Fortimanager appliance. The fortigates will auto-register with this fortigate upon startup'
  }
  default: ''
}
param adminUsername string {
  metadata: {
    description: 'Username for the Fortigate virtual appliances. Defaults to fgadmin'
  }
  default: 'fgadmin'
}
param adminPublicKey string {
  metadata: {
    description: 'SSH Public Key for the virtual machine. Format: https://www.ssh.com/ssh/key/'
  }
  default: ''
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
param vmSize string {
  metadata: {
    description: 'Specify an alternate VM size. The VM size must allow for at least two NICs, and four are recommended'
  }
  default: 'Standard_DS3_v2'
}
param FortinetTags object = {
  provider: '6EB3B02F-50E5-4A3E-8CB8-2E129258317D'
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
  params: {
    vnetName: fgNamePrefix
  }
}

module loadbalancer './loadbalancer.bicep' = {
  name: '${deploymentName}-loadbalancer'
  params: {
    lbName: fgNamePrefix
    fgaManagementHttpPort: fgaManagementHttpPort
    fgaManagementSshPort: fgaManagementSshPort
    fgbManagementHttpPort: fgbManagementHttpPort
    fgbManagementSshPort: fgbManagementSshPort
    internalSubnet: network.outputs.internalSubnet
    externalSubnet: network.outputs.externalSubnet
    publicIPID: publicIPID
  }
}

var fgImageSku = bringYourOwnLicense ? 'fortinet_fg-vm' : 'fortinet_fg-vm_payg_20190624'

// TODO: Build both with a loop once bicep 0.4 is released
module fortigateA './fortigate.bicep' = {
  name: '${deploymentName}-fortigateA'
  params: {
    location: location
    vmName: '${fgNamePrefix}A'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    adminPublicKey: adminPublicKey
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
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    adminPublicKey: adminPublicKey
    FortigateImageSKU: fgImageSku
    FortigateImageVersion: fgVersion
    adminNsgId: fgAdminNsg.id
    availabilitySetId: empty(fgSet.id) ? fgSet.id : ''
    loadBalancerInfo: loadbalancer.outputs.fortigateBLoadBalancerInfo
    externalSubnet: network.outputs.externalSubnet
    internalSubnet: network.outputs.internalSubnet
  }
}

var fqdn = loadbalancer.outputs.publicIpFqdn
var baseUri = 'https://${fqdn}'
var baseSsh = 'ssh ${adminUsername}@${fqdn}'
output fgManagementUser string = adminUsername
output fgaManagementUri string = '${baseUri}:${fgaManagementHttpPort}'
output fgbManagementUri string = '${baseUri}:${fgbManagementHttpPort}'
output fgaManagementSshCommand string = '${baseSsh} -p ${fgaManagementSshPort}' 
output fgbManagementSshCommand string = '${baseSsh} -p ${fgbManagementSshPort}'
// TODO: fgaManagementSSHConfig once multiline support is added
// "fgaManagementSSHConfig": {
//   "type": "String",
//   "value": "[concat(
//       'Host ', variables('compute_VM_fga_Name'), '\n',
//       '  HostName ', reference(variables('publicIPId')).dnsSettings.fqdn, '\n',
//       '  Port ', parameters('fgaManagementSshPort'),'\n',
//       '  User ', parameters('adminUsername')
//   )]"
// },
// "fgbManagementSSHConfig": {
//   "type": "String",
//   "value": "[concat(
//       'Host ', variables('compute_VM_fgb_Name'), '\n',
//       '  HostName ', reference(variables('publicIPId')).dnsSettings.fqdn, '\n',
//       '  Port ', parameters('fgbManagementSshPort'),'\n',
//       '  User ', parameters('adminUsername')
//   )]"
// }