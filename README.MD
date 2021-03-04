# Fortigate Azure Load-Balancing HA Bicep Template

This is a reimplementation of the [Fortigate Azure Load-Balancing HA](https://github.com/fortinetsolutions/Azure-Templates/tree/master/FortiGate/Azure%20Active-Active%20LoadBalancer%20HA-Ports) ARM template in bicep format, with significant improvements and cleanup.

This is optimized for performing UDR from subnets and other vnets to the "transit" port to provide a central hub in a cost effective way (without using Virtual WAN)

![Diagram](images/AADesign.png)

## Modules
1. main: the controller module that you should compile
2. network: provisions a vnet and related subnets if you do not supply your own
3. loadbalancer: provisions the internal and external "sandwich" load balancers for the fortigate
4. fortigate: provisions the two fortigate VM instances

## New Features
1. Simplified license, image, and size selection
1. Loads of intelligent defaults, only mandatory parameter is the admin password for security
1. [Azure Serial Console](https://docs.microsoft.com/en-us/troubleshoot/azure/virtual-machines/serial-console-overview) Support
1. Specify an Azure SSH Key resource for fortigate login
1. Spot instance support for devtest or low-cost deployments
1. [CloudInit](https://docs.fortinet.com/document/fortigate/6.2.0/aws-cookbook/760385/cloud-init) initial setup of common features and ability to specify custom initial startup configuration
1. Automated Fortimanager Connection Process
1. Automatically generated SSH config and URI to quickly access your deployed fortigate

## Notes
1. `admin` is deliberately configured as a fortimanager-only user and cannot be logged into remotely

## Fortimanager Low Touch Configuration
This template supports automatic connection to a Fortimanager instance and enables authorization with a single command (due to a limitation in Fortimanager)
1. Specify the FortimanagerFqdn and (optionally) the Fortimanager Password to use. If you do not specify a password it will generate one automatically
1. Upon deployment you should see the fortigates connected to the relevant fortimanager
1. Connect to the fortimanager and run the commands specified by the `fgaFortimanagerSharedKeyCommand` and `fgbFortimanagerSharedKeyCommand`
1. Click `Authorize` and fortimanager should now connect and be able to manage the nodes.
TODO: Automate this process with a Powershell Deployment Script Maybe?