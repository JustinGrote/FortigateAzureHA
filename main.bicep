targetScope = 'resourceGroup' 
// Mandatory Parameters
@secure()
@description('Password for the user defined by AdminUsername')
param AdminPassword string

// Optional Parameters
@description('Name for FortiGate virtual appliances (A & B will be appended to the end of each respectively). Defaults to the same name as the resource group.')
param FgNamePrefix string = resourceGroup().name

@description('Which Azure Location (Region) to deploy to. Defaults to the same location as the resource group')
param Location string = resourceGroup().location

@description('Resource ID of the Public IP to use for the outbound traffic and inbound management. A standard static SKU Public IP is required. Default is to generate a new one')
param PublicIPID string = ''

@description('Fully Qualified DNS Name of the Fortimanager appliance. The fortigates will auto-register with this fortimanager upon startup')
param FortimanagerFqdn string = ''

@secure()
@description('Password to use for Fortimanager connectivity, similar to a pre-shared key. Once the appliance registers with the fortimanager you will need to run "exec dev replace pw <Hostname> <ThisPassword>" at the fortimanager command line for each fortigate before clicking "Authorize". This will default to a random string that will show in the outputs upon deployment')
param FortimanagerPassword string = ''

@description('Username for the Fortigate virtual appliances. Defaults to fgadmin. NOTE: This must be something other than "admin" or the process will fail because admin is used exclusively for fortimanager communication')
param AdminUsername string = 'fgadmin'

@description('Id of an SSH public key resource stored in Azure to be used for SSH login to the user defined by AdminUsername. The public key is not sensitive information.')
param AdminSshPublicKeyId string = ''

@description('Specify true for a Bring Your Own License (BYOL) deployment, otherwise the fortigate license will be included in the VM subscription cost')
param BringYourOwnLicense bool = false

@description('Use spot instances to save cost at the expense of potential reduced availability. Availability set will be disabled with this option')
param UseSpotInstances bool = false

@description('Specify the version to use e.g. 6.4.2. Defaults to latest version')
param FgVersion string = 'latest'

@description('Specify an alternate VM size. The VM size must allow for at least two NICs, and four are recommended')
param VmSize string = 'Standard_DS3_v2'

@description('IP address of the internal load balancer port. This normally does not need to be configured but it is where all traffic flows to via the route table rule')
param LbInternalSubnetIP string = ''

@description('The port to use for accessing the http management interface of the first Fortigate')
param FgaManagementHttpPort int = 50443

@description('The port to use for accessing the http management interface of the second Fortigate')
param FgbManagementHttpPort int = 51443

@description('The port to use for accessing the ssh management interface of the first Fortigate')
param FgaManagementSshPort int = 50022

@description('The port to use for accessing the ssh management interface of the first Fortigate')
param FgbManagementSshPort int = 51022

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param FgaExternalSubnetIP string = ''

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param FgaInternalSubnetIP string = ''

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param FgbExternalSubnetIP string = ''

@description('IP Address for the external (port1) interface in 1.2.3.4 format. This should normally not be set as only the LB addresses matters')
param FgbInternalSubnetIP string = ''

@description('Specify the ID of an existing vnet to use. You must specify the internalSubnetName and externalSubnetName options if you specify this option')
param ExternalSubnetName string = 'External'

@description('Specify the name of the internal subnet. The port1 interface will be given this name')
param InternalSubnetName string = 'Transit'

param FortinetTags object = {
  provider: '6EB3B02F-50E5-4A3E-8CB8-2E129258317D'
}



// New vNet Scenario parameters
@description('vNet Address Prefixes to allocate to the vNet')
param VnetAddressPrefixes array = [
  '10.0.0.0/16'
]

@description('Subnet range for the external network.')
param ExternalSubnetPrefix string = '10.0.1.0/24'

@description('Subnet range for the internal (transit) network. There typically will be no other devices in this subnet besides the internal load balancer, it is just used as a UDR target')
param InternalSubnetPrefix string = '10.0.2.0/24'

// Existing vNet Scenario parameters
@description('Specify the name of an existing vnet within the subscription to use. You must specify the internalSubnetName and externalSubnetName options if you specify this option, as well as vnetResourceGroupName if the vnet is not in the same resource group as this deployment')
param ExistingVNetId string = ''

var deploymentName = deployment().name

resource fgAdminNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: FgNamePrefix
  location: Location
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

resource fgSet 'Microsoft.Compute/availabilitySets@2019-07-01' = if (!UseSpotInstances) {
  name: FgNamePrefix
  location: Location
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
    VnetName: FgNamePrefix
    VnetAddressPrefixes: VnetAddressPrefixes
    InternalSubnetPrefix: InternalSubnetPrefix
    ExternalSubnetPrefix: ExternalSubnetPrefix
    InternalSubnetName: InternalSubnetName
    ExternalSubnetName: ExternalSubnetName
  }
}

var internalSubnetInfo = {
  id: empty(ExistingVNetId) ? network.outputs.internalSubnet.id : '${ExistingVNetId}/subnets/${InternalSubnetName}'
  name: !empty(network.outputs.internalSubnet.name) ? network.outputs.internalSubnet.name : InternalSubnetName
}
var externalSubnetInfo = {
  id: empty(ExistingVNetId) ? network.outputs.externalSubnet.id : '${ExistingVNetId}/subnets/${ExternalSubnetName}'
  name: !empty(network.outputs.externalSubnet.name) ? network.outputs.externalSubnet.name : ExternalSubnetName
}

var externalSubnetId = empty(ExistingVNetId) ? network.outputs.externalSubnet.id : '${ExistingVNetId}/subnets/${ExternalSubnetName}'

module loadbalancer './loadbalancer.bicep' = {
  name: '${deploymentName}-loadbalancer'
  params: {
    LbName: FgNamePrefix
    FgaManagementHttpPort: FgaManagementHttpPort
    FgaManagementSshPort: FgaManagementSshPort
    FgbManagementHttpPort: FgbManagementHttpPort
    FgbManagementSshPort: FgbManagementSshPort
    InternalSubnetId: internalSubnetInfo.id
    PublicIPID: PublicIPID
    LbInternalSubnetIP: LbInternalSubnetIP
  }
}

var fgImageSku = BringYourOwnLicense ? 'fortinet_fg-vm' : 'fortinet_fg-vm_payg_20190624'

module fortigateA 'fortigate.bicep' = {
  name: '${deploymentName}-fortigateA'
  params: {
    //Fortigate Instance-Specific Parameters
    VmName: '${FgNamePrefix}A'
    LoadBalancerInfo: loadbalancer.outputs.fortigateALoadBalancerInfo
    ExternalSubnetIP: !empty(FgaExternalSubnetIP) ? FgaExternalSubnetIP : ''
    InternalSubnetIP: !empty(FgaInternalSubnetIP) ? FgaInternalSubnetIP : ''

    //Fortigate Common Parameters
    Location: Location
    VmSize: VmSize
    AdminUsername: AdminUsername
    AdminPassword: AdminPassword
    AdminSshPublicKeyId: AdminSshPublicKeyId
    FortigateImageSKU: fgImageSku
    FortigateImageVersion: FgVersion
    FortimanagerFqdn: FortimanagerFqdn
    FortimanagerPassword: FortimanagerPassword
    AdminNsgId: fgAdminNsg.id
    AvailabilitySetId: empty(fgSet.id) ? fgSet.id : ''
    ExternalSubnet: externalSubnetInfo
    InternalSubnet: internalSubnetInfo
  }
}

module fortigateB 'fortigate.bicep' = {
  name: '${deploymentName}-fortigateB'
  params: {
    //Fortigate Instance-Specific Parameters
    VmName: '${FgNamePrefix}B'
    LoadBalancerInfo: loadbalancer.outputs.fortigateBLoadBalancerInfo
    ExternalSubnetIP: !empty(FgbExternalSubnetIP) ? FgbExternalSubnetIP : ''
    InternalSubnetIP: !empty(FgbInternalSubnetIP) ? FgbInternalSubnetIP : ''

    //Fortigate Common Parameters
    Location: Location
    VmSize: VmSize
    AdminUsername: AdminUsername
    AdminPassword: AdminPassword
    AdminSshPublicKeyId: AdminSshPublicKeyId
    FortigateImageSKU: fgImageSku
    FortigateImageVersion: FgVersion
    FortimanagerFqdn: FortimanagerFqdn
    FortimanagerPassword: FortimanagerPassword
    AdminNsgId: fgAdminNsg.id
    AvailabilitySetId: empty(fgSet.id) ? fgSet.id : ''
    ExternalSubnet: externalSubnetInfo
    InternalSubnet: internalSubnetInfo
  }
}

var fqdn = loadbalancer.outputs.publicIpFqdn
var baseUri = 'https://${fqdn}'
var baseSsh = 'ssh ${AdminUsername}@${fqdn}'
output fgManagementUser string = AdminUsername
output fgaManagementUri string = '${baseUri}:${FgaManagementHttpPort}'
output fgbManagementUri string = '${baseUri}:${FgbManagementHttpPort}'
output fgaManagementSshCommand string = '${baseSsh} -p ${FgaManagementSshPort}' 
output fgbManagementSshCommand string = '${baseSsh} -p ${FgbManagementSshPort}'

var fgManagementSSHConfigTemplate = '''

Host {0}  
  HostName {1}
  Port {2}
  User {3}
'''
output fgaManagementSSHConfig string = format(fgManagementSSHConfigTemplate, fortigateA.outputs.fgName, fqdn, FgaManagementSshPort, AdminUsername)
output fgbManagementSSHConfig string = format(fgManagementSSHConfigTemplate, fortigateB.outputs.fgName, fqdn, FgbManagementSshPort, AdminUsername)

output fgaFortimanagerSharedKeyCommand string = fortigateA.outputs.fortimanagerSharedKey
output fgbFortimanagerSharedKeyCommand string = fortigateB.outputs.fortimanagerSharedKey