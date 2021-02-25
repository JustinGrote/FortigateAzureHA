// Mandatory Parameters
param vmName string {
  metadata: {
    description: 'Username for the Fortigate virtual appliances.'
  }
}
param adminUsername string {
  metadata: {
    description: 'Username for the Fortigate virtual appliances.'
  }
}
param adminPassword string {
  metadata: {
    description: 'Password for the Fortigate virtual appliances.'
  }
  secure: true
}
param adminNsgId string {
  metadata: {
    description: 'Resource ID for the admin access Network Security Group'
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
param availabilitySetId string {
  metadata: {
    description: 'Availability Set that the fortigate should belong to'
  }
  default: ''
}
param loadBalancerInfo object {
  metadata: {
    description: 'Load balancer information from the fortigate loadbalancer module'
  }
}

// Optional Parameters
param location string {
  metadata: {
    description: 'Which Azure Location (Region) to deploy to. Defaults to the same region as the resource group'
  }
  default: resourceGroup().location
}
param adminPublicKey string {
  metadata: {
    description: 'SSH Public Key for the virtual machine. Format: https://www.ssh.com/ssh/key/'
  }
  default: ''
}
param FortigateImageSKU string {
  allowed: [
    'fortinet_fg-vm'
    'fortinet_fg-vm_payg_20190624'
  ]
  metadata: {
    description: 'Identifies whether to to use PAYG (on demand licensing) or BYOL license model (where license is purchased separately)'
  }
  default: 'fortinet_fg-vm'
}
param FortigateImageVersion string {
  metadata: {
    description: 'Select image version.'
  }
  default: 'latest'
}
param FortiGateAdditionalConfig string {
  metadata: {
    description: 'FortiGate CLI configuration items to add to the basic configuration. You should use the \\n character to delimit newlines, though a multiline string should generally be OK as well'
  }
  default: ''
}
param vmSize string {
  metadata: {
    description: 'Virtual Machine size selection'
  }
  default: 'Standard_DS3_v2'
}
param FortinetTags object = {
  provider: '6EB3B02F-50E5-4A3E-8CB8-2E129258317D'
}
param vmLogDiskSizeGB int {
  metadata: {
    description: 'Size of the log disk for the virtual appliances. Defaults to 30GB'
  }
  default: 30
}
var vmDiagnosticStorageName = toLower(vmName)
var vmPublicKeyConfiguration = {
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPublicKey
      }
    ]
  }
}


resource nic1 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: '${vmName}-port1'
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  properties: {
    ipConfigurations: [
      {
        name: internalSubnet.name
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: internalSubnet.id
          }
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancerInfo.externalBackendId
            }
          ]
          loadBalancerInboundNatRules: [
            {
              id: loadBalancerInfo.natrules[0].id
            }
            {
              id: loadBalancerInfo.natrules[1].id
            }
          ]
        }
      }
    ]
    enableIPForwarding: true
    enableAcceleratedNetworking: true
    networkSecurityGroup: {
      id: adminNsgId
    }
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: '${vmName}-port2'
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  properties: {
    ipConfigurations: [
      {
        name: externalSubnet.Name
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: externalSubnet.Id
          }
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancerInfo.internalBackendId
            }
          ]
        }
      }
    ]
    enableIPForwarding: true
    enableAcceleratedNetworking: true
  }
}

resource diagStorage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: toLower('${vmName}')
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
}

// Unnecessary due to DHCP. Maybe add option for vNet route?
// module externalGateway './getSubnetGateway.bicep' = {
//   name: '${deployment().name}-getSubnet-externalGateway'
//   params: {
//     subnetAddress: externalSubnet.properties.addressPrefix
//   }
// }

// module internalGateway './getSubnetGateway.bicep' = {
//   name: '${deployment().name}-getSubnet-internalGateway'
//   params: {
//     subnetAddress: internalSubnet.properties.addressPrefix
//   }
// }

//FIXME: Needs multiline syntax from .3
var fortigateConfig = base64('config system probe-response\n set mode http-probe\nend\nconfig system interface\n edit port1\n  set description ${externalSubnet.name}\n  append allowaccess probe-response\n next\n edit port2\n  set description ${internalSubnet.name}\n  set allowaccess ping probe-response\n next\nend\nconfig sys admin\n edit admin\n  set password ${adminPassword}\n next\nend\n${FortiGateAdditionalConfig}')

var availabilitySet = {
  id: availabilitySetId
}
resource vmFortigate 'Microsoft.Compute/virtualMachines@2019-07-01' = {
  name: vmName
  location: location
  tags: {
    provider: toUpper(FortinetTags.provider)
  }
  plan: {
    name: FortigateImageSKU
    publisher: 'fortinet'
    product: 'fortinet_fortigate-vm_v5'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    //Spot instance settings
    priority: empty(availabilitySetId) ? 'Spot' : 'Regular' 
    evictionPolicy: empty(availabilitySetId) ? 'Deallocate' : json('null')
    billingProfile: {
      maxPrice: empty(availabilitySetId) ? -1 : json('null')
    }
    availabilitySet: empty(availabilitySetId) ? json('null') : availabilitySet
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: empty(adminPublicKey) ? json('null') : vmPublicKeyConfiguration
      customData: fortigateConfig
    }
    storageProfile: {
      imageReference: {
        publisher: 'fortinet'
        offer: 'fortinet_fortigate-vm_v5'
        sku: FortigateImageSKU
        version: FortigateImageVersion
      }
      osDisk: {
        name: vmName
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          name: '${vmName}-data'
          diskSizeGB: vmLogDiskSizeGB
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorage.properties.primaryEndpoints.blob
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          properties: {
            primary: true
          }
          id: nic1.id
        }
        {
          properties: {
            primary: false
          }
          id: nic2.id
        }
      ]
    }
  }
}