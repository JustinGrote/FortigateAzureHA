// Mandatory Parameters

@description('Name for FortiGate virtual appliances (A & B will be appended to the end of each respectively).')
param fgNamePrefix string = resourceGroup().name

@secure()
@description('Password for the Fortigate virtual appliances.')
param adminPassword string

// Optional Parameters
@description('Which Azure Location (Region) to deploy to. Defaults to the same region as the resource group')
param location string = resourceGroup().location

@description('Resource ID of the Public IP to use for the outbound traffic and inbound management. A standard static SKU Public IP is required. Default is to generate a new one')
param publicIPID string = ''

@description('Fully Qualified DNS Name of the Fortimanager appliance. The fortigates will auto-register with this fortigate upon startup')
param fortimanagerFqdn string = ''

@description('Username for the Fortigate virtual appliances. Defaults to fgadmin')
param adminUsername string = 'fgadmin'

@description('SSH Public Key for the virtual machine. Format: https://www.ssh.com/ssh/key/')
param adminPublicKey string = ''

@description('Specify true for a Bring Your Own License (BYOL) deployment, otherwise the fortigate license will be included in the VM subscription cost')
param bringYourOwnLicense bool = false

@description('Use spot instances to save cost at the expense of potential reduced availability. Availability set will be disabled with this option')
param useSpotInstances bool = false

@description('Specify the version to use e.g. 6.4.2. Defaults to latest version')
param fgVersion string = 'latest'

@description('Specify an alternate VM size. The VM size must allow for at least two NICs, and four are recommended')
param vmSize string = 'Standard_DS3_v2'

@description('IP address of the internal load balancer port. This normally does not need to be configured but it is where all traffic flows to via the route table rule')
param lbInternalSubnetIP string = ''

@description('The port to use for accessing the http management interface of the first Fortigate')
param fgaManagementHttpPort int = 50443

@description('The port to use for accessing the http management interface of the second Fortigate')
param fgbManagementHttpPort int = 51443

@description('The port to use for accessing the ssh management interface of the first Fortigate')
param fgaManagementSshPort int = 50022

@description('The port to use for accessing the ssh management interface of the first Fortigate')
param fgbManagementSshPort int = 51022

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param fgaExternalSubnetIP string = ''

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param fgaInternalSubnetIP string = ''

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param fgbExternalSubnetIP string = ''

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param fgbInternalSubnetIP string = ''

@description('Specify the ID of an existing vnet to use. You must specify the internalSubnetName and externalSubnetName options if you specify this option')
param externalSubnetName string = 'External'

@description('Specify the name of the internal subnet. The port1 interface will be given this name')
param internalSubnetName string = 'Transit'

param FortinetTags object = {
  provider: '6EB3B02F-50E5-4A3E-8CB8-2E129258317D'
}



// New vNet Scenario parameters
@description('vNet Address Prefixes to allocate to the vNet')
param vnetAddressPrefixes array = [
  '10.0.0.0/16'
]

@description('Subnet range for the external network.')
param externalSubnetPrefix string = '10.0.1.0/24'

@description('Subnet range for the internal (transit) network. There typically will be no other devices in this subnet besides the internal load balancer, it is just used as a UDR target')
param internalSubnetPrefix string = '10.0.2.0/24'

// Existing vNet Scenario parameters
@description('Specify the name of an existing vnet within the subscription to use. You must specify the internalSubnetName and externalSubnetName options if you specify this option, as well as vnetResourceGroupName if the vnet is not in the same resource group as this deployment')
param ExistingVNetId string = ''

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

module network 'network.bicep' = if (empty(ExistingVNetId)) {
  name: '${deploymentName}-network'
  params: {
    vnetName: fgNamePrefix
    vnetAddressPrefixes: vnetAddressPrefixes
    internalSubnetPrefix: internalSubnetPrefix
    externalSubnetPrefix: externalSubnetPrefix
    internalSubnetName: internalSubnetName
    externalSubnetName: externalSubnetName
  }
}


//FIXME: Bicep 0.4 should have external references to use instead of this
var internalSubnetInfo = {
  id: empty(ExistingVNetId) ? network.outputs.internalSubnet.id : '${ExistingVNetId}/subnets/${internalSubnetName}'
  name: !empty(network.outputs.internalSubnet.name) ? network.outputs.internalSubnet.name : internalSubnetName
}
var externalSubnetInfo = {
  id: empty(ExistingVNetId) ? network.outputs.externalSubnet.id : '${ExistingVNetId}/subnets/${externalSubnetName}'
  name: !empty(network.outputs.externalSubnet.name) ? network.outputs.externalSubnet.name : externalSubnetName
}

var externalSubnetId = empty(ExistingVNetId) ? network.outputs.externalSubnet.id : '${ExistingVNetId}/subnets/${externalSubnetName}'

module loadbalancer './loadbalancer.bicep' = {
  name: '${deploymentName}-loadbalancer'
  params: {
    lbName: fgNamePrefix
    fgaManagementHttpPort: fgaManagementHttpPort
    fgaManagementSshPort: fgaManagementSshPort
    fgbManagementHttpPort: fgbManagementHttpPort
    fgbManagementSshPort: fgbManagementSshPort
    internalSubnetId: internalSubnetInfo.id
    publicIPID: publicIPID
    lbInternalSubnetIP: lbInternalSubnetIP
  }
}

var fgImageSku = bringYourOwnLicense ? 'fortinet_fg-vm' : 'fortinet_fg-vm_payg_20190624'

module fortigateA 'fortigate.bicep' = {
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
    fortimanagerFqdn: fortimanagerFqdn
    adminNsgId: fgAdminNsg.id
    availabilitySetId: empty(fgSet.id) ? fgSet.id : ''
    loadBalancerInfo: loadbalancer.outputs.fortigateALoadBalancerInfo
    externalSubnet: externalSubnetInfo
    internalSubnet: internalSubnetInfo
    externalSubnetIP: !empty(fgaExternalSubnetIP) ? fgaExternalSubnetIP : ''
    internalSubnetIP: !empty(fgaInternalSubnetIP) ? fgaInternalSubnetIP : ''
  }
}

module fortigateB 'fortigate.bicep' = {
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
    fortimanagerFqdn: fortimanagerFqdn
    adminNsgId: fgAdminNsg.id
    availabilitySetId: empty(fgSet.id) ? fgSet.id : ''
    loadBalancerInfo: loadbalancer.outputs.fortigateBLoadBalancerInfo
    externalSubnet: externalSubnetInfo
    internalSubnet: internalSubnetInfo
    externalSubnetIP: !empty(fgbExternalSubnetIP) ? fgbExternalSubnetIP : ''
    internalSubnetIP: !empty(fgbInternalSubnetIP) ? fgbInternalSubnetIP : ''
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

var fgManagementSSHConfigTemplate = '''

Host {0}  
  HostName {1}
  Port {2}
  User {3}
'''
output fgaManagementSSHConfig string = format(fgManagementSSHConfigTemplate, fortigateA.outputs.fgName, fqdn, fgaManagementSshPort, adminUsername)
output fgbManagementSSHConfig string = format(fgManagementSSHConfigTemplate, fortigateB.outputs.fgName, fqdn, fgbManagementSshPort, adminUsername)
