# Fortigate Azure Load-Balancing HA Bicep Template

This is a reimplementation of the [Fortigate Azure Load-Balancing HA](https://github.com/fortinetsolutions/Azure-Templates/tree/master/FortiGate/Azure%20Active-Active%20LoadBalancer%20HA-Ports) ARM template in bicep format, with significant improvements and cleanup.

This is optimized for performing UDR from subnets and other vnets to the "transit" port to provide a central hub in a cost effective way (without using Virtual WAN)

![Diagram](images/AADesign.png)

## New Features
1. Spot instance support for devtest
1. Simplified license, image, and size selection