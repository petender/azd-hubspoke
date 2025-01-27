targetScope = 'resourceGroup'

param tags object
param environmentName string



@description('The Windows version for Windows Jump-host VM.')
param windowsOSVersion string = '2022-Datacenter'

@description('Size for Windows jump-host VM')
param winVmSize string = 'Standard_D4_v3'

@description('Username for Windows jump-host VM')
param winVmUser string

@description('Password for Windows jump-host VM. The password must be between 6-72 characters long and must satisfy at least 3 of password complexity requirements from the following: 1) Contains an uppercase character 2) Contains a lowercase character 3) Contains a numeric digit 4) Contains a special character 5) Control characters are not allowed')
@secure()
param winVmPassword string

@description('DNS Label for Windows jump-host VM.')
param winVmDnsPrefix string

@description('Whether or not to deploy a VPN Gateway in the Hub')
param deployVpnGateway string = 'Yes'

@description('The SKU of the Gateway, if deployed')
@allowed([
  'Basic'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
])
param gatewaySku string = 'VpnGw2AZ'

@description('Location for all resources.')
param location string = resourceGroup().location

var hubVnetName = 'hubVnet'
var hubVnetPrefix = '192.168.0.0/20'
var dmzSubnetName = 'DMZSubnet'
var dmzSubnetPrefix = '192.168.0.0/25'
var mgmtSubnetName = 'ManagementSubnet'
var mgmtSubnetPrefix = '192.168.1.0/24'
var sharedSubnetName = 'SharedSubnet'
var sharedSubnetPrefix = '192.168.4.0/22'
var gatewaySubnetName = 'GatewaySubnet'
var gatewaySubnetPrefix = '192.168.15.224/27'
var gatewayName = 'hubVpnGateway'
var gatewayPIPName = 'hubVpnGatewayPublicIp'
var subnetGatewayId = hubVnetName_gatewaySubnet.id
var winJmphostName = 'winJmphostVm'
var devSpokeVnetName = 'spokeDevVnet'
var devSpokeVnetPrefix = '10.10.0.0/16'
var prodSpokeVnetName = 'spokeProdVnet'
var prodSpokeVnetPrefix = '10.100.0.0/16'
var spokeWorkloadSubnetName = 'WorkloadSubnet'
var devSpokeWorkloadSubnetPrefix = '10.10.0.0/16'
var prodSpokeWorkloadSubnetPrefix = '10.100.0.0/16'
var hubID = hubVnet.id
var devSpokeID = devSpokeVnet.id
var prodSpokeID = prodSpokeVnet.id
var winVmNicName = '${winJmphostName}NIC'
var winVmStorageName = 'hubwinvm${uniqueString(resourceGroup().id)}'
var winNsgName = 'winJmpHostNsg'
var winJmphostPublicIpName = 'winJmphostVmPublicIp'

resource hubVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: hubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetPrefix
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource hubVnetName_mgmtSubnet 'Microsoft.Network/virtualNetworks/subnets@2019-11-01' = {
  parent: hubVnet
  name: '${mgmtSubnetName}'
  properties: {
    addressPrefix: mgmtSubnetPrefix
  }
}

resource hubVnetName_sharedSubnet 'Microsoft.Network/virtualNetworks/subnets@2019-11-01' = {
  parent: hubVnet
  name: '${sharedSubnetName}'
  properties: {
    addressPrefix: sharedSubnetPrefix
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
  ]
}

resource hubVnetName_dmzSubnet 'Microsoft.Network/virtualNetworks/subnets@2019-11-01' = {
  parent: hubVnet
  name: '${dmzSubnetName}'
  properties: {
    addressPrefix: dmzSubnetPrefix
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
  ]
}

resource hubVnetName_gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2019-11-01' = if (deployVpnGateway == 'Yes') {
  parent: hubVnet
  name: '${gatewaySubnetName}'
  properties: {
    addressPrefix: gatewaySubnetPrefix
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet
  ]
}

resource devSpokeVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: devSpokeVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        devSpokeVnetPrefix
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource devSpokeVnetName_spokeWorkloadSubnet 'Microsoft.Network/virtualNetworks/subnets@2019-11-01' = {
  parent: devSpokeVnet
  name: '${spokeWorkloadSubnetName}'
  properties: {
    addressPrefix: devSpokeWorkloadSubnetPrefix
  }
}

resource prodSpokeVnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: prodSpokeVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        prodSpokeVnetPrefix
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource prodSpokeVnetName_spokeWorkloadSubnet 'Microsoft.Network/virtualNetworks/subnets@2019-11-01' = {
  parent: prodSpokeVnet
  name: '${spokeWorkloadSubnetName}'
  properties: {
    addressPrefix: prodSpokeWorkloadSubnetPrefix
  }
}

resource hubVnetName_gwPeering_hubVnetName_devSpokeVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'Yes') {
  parent: hubVnet
  name: 'gwPeering_${hubVnetName}_${devSpokeVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: devSpokeID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet
    hubVnetName_gatewaySubnet

    devSpokeVnetName_spokeWorkloadSubnet
  ]
}

resource hubVnetName_peering_hubVnetName_devSpokeVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'No') {
  parent: hubVnet
  name: 'peering_${hubVnetName}_${devSpokeVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: devSpokeID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet

    devSpokeVnetName_spokeWorkloadSubnet
  ]
}

resource hubVnetName_gwPeering_hubVnetName_prodSpokeVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'Yes') {
  parent: hubVnet
  name: 'gwPeering_${hubVnetName}_${prodSpokeVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: prodSpokeID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet
    hubVnetName_gatewaySubnet

    prodSpokeVnetName_spokeWorkloadSubnet
  ]
}

resource hubVnetName_peering_hubVnetName_prodSpokeVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'No') {
  parent: hubVnet
  name: 'peering_${hubVnetName}_${prodSpokeVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: prodSpokeID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet

    prodSpokeVnetName_spokeWorkloadSubnet
  ]
}

resource devSpokeVnetName_gwPeering_devSpokeVnetName_hubVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'Yes') {
  parent: devSpokeVnet
  name: 'gwPeering_${devSpokeVnetName}_${hubVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet
    hubVnetName_gatewaySubnet

    devSpokeVnetName_spokeWorkloadSubnet
    gateway
  ]
}

resource devSpokeVnetName_peering_devSpokeVnetName_hubVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'No') {
  parent: devSpokeVnet
  name: 'peering_${devSpokeVnetName}_${hubVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet

    devSpokeVnetName_spokeWorkloadSubnet
  ]
}

resource prodSpokeVnetName_gwPeering_prodSpokeVnetName_hubVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'Yes') {
  parent: prodSpokeVnet
  name: 'gwPeering_${prodSpokeVnetName}_${hubVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet
    hubVnetName_gatewaySubnet

    prodSpokeVnetName_spokeWorkloadSubnet
    gateway
  ]
}

resource prodSpokeVnetName_peering_prodSpokeVnetName_hubVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2019-11-01' = if (deployVpnGateway == 'No') {
  parent: prodSpokeVnet
  name: 'peering_${prodSpokeVnetName}_${hubVnetName}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubID
    }
  }
  dependsOn: [
    hubVnetName_mgmtSubnet
    hubVnetName_sharedSubnet
    hubVnetName_dmzSubnet

    prodSpokeVnetName_spokeWorkloadSubnet
  ]
}

resource winJmphost 'Microsoft.Compute/virtualMachines@2019-12-01' = {
  name: winJmphostName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: winVmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          diskSizeGB: 20
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    osProfile: {
      computerName: winJmphostName
      adminUsername: winVmUser
      adminPassword: winVmPassword
      windowsConfiguration: {
        provisionVMAgent: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: winVmNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(winVmStorageName, '2019-06-01').primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    winVmStorage
  ]
}

resource winVmNic 'Microsoft.Network/networkInterfaces@2019-11-01' = {
  name: winVmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'winJmpHostIpConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: winJmphostPublicIp.id
          }
          subnet: {
            id: hubVnetName_mgmtSubnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: winNsg.id
    }
    primary: true
  }
}

resource winNsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: winNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'NSG_RULE_INBOUND_RDP'
        properties: {
          description: 'Allow inbound RDP'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
    defaultSecurityRules: [
      {
        name: 'AllowVnetInBound'
        properties: {
          description: 'Allow inbound traffic from all VMs in VNET'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 65000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInBound'
        properties: {
          description: 'Allow inbound traffic from azure load balancer'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 65001
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          description: 'Deny all inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 65500
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowVnetOutBound'
        properties: {
          description: 'Allow outbound traffic from all VMs to all VMs in VNET'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 65000
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowInternetOutBound'
        properties: {
          description: 'Allow outbound traffic from all VMs to Internet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 65001
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          description: 'Deny all outbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 65500
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource winJmphostPublicIp 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  name: winJmphostPublicIpName
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: toLower(winVmDnsPrefix)
    }
  }
}

resource winVmStorage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  sku: {
    name: 'Standard_GRS'
    tier: 'Standard'
  }
  kind: 'Storage'
  name: winVmStorageName
  location: location
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: false
    encryption: {
      services: {
        file: {
          enabled: true
        }
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource gatewayPIP 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: gatewayPIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2019-11-01' = if (deployVpnGateway == 'Yes') {
  name: gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetGatewayId
          }
          publicIPAddress: {
            id: gatewayPIP.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
  }
}

output Jumphost_VM_IP_address string = winJmphostPublicIp.properties.ipAddress
output winVmUser string = winVmUser

