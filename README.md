------------------------------------------------------------------

 This is a perl discovery agent that discovers the connectivity
 between a VMWare ESXi host system and the guests that are
 running on it.  


 v1.1 release 9/14/14
 v1.5 release 10/6/16

 Jason Cress - IBM C&SI SWG
 jcress@us.ibm.com

 Special thanks to Jim Kovach at Allstate for providing assistance
 in building and testing this agent.

 This agent employs the CiscoSwitchInPerl agent as a template for
 its structure.

------------------------------------------------------------------


Requirements
============

This agent has been tested with VMWare ESXi Server 5.1, 5.5, and 6.5.

The ESXi hosts must have SNMP enabled. Refer to the VMWare ESXi Server Documentation on how to enable SNMP. You
must have the correct SNMP community string configured in the "Passwords" section of the ITNM discovery configuration.

The MacFromArpCache ITNM discovery agent must be enabled.

Obtain and install the following VMWare SNMP MIB files into the $NCHOME/precision/mibs directory:

VMWARE-ENV-MIB.mib
VMWARE-PRODUCTS-MIB.mib
VMWARE-ROOT-MIB.mib
VMWARE-SYSTEM-MIB.mib
VMWARE-TC-MIB.mib
VMWARE-VMINFO-MIB.mib

You can obtain these mibs from vmware.com

After copying these files to the $NCHOME/precision/mibs directory be sure to run the command "ncp_mib" to
ensure that the MIB is available to the ITNM SNMP processes.


Installation
============

Shut down the ITNM processes.

Run the "install.sh" command to install the agent. Follow the prompts to install the agent.

The installation script will replace the default PostLayerProcessing.stch file. If the default PostLayerProcessing
stitcher has been modified or customized, you will be notified of this fact. If this is the case, you will need to 
manually modify the PostLayerProcessing.stch file and add the call to the VMWareESXiSnmp stitcher.  

Example:

---------------- begin example snippet ----------------
        ExecuteStitcher('RemoveOutOfBandConnectivity' , isRediscovery);

        // This stitcher is not essential, and is therefore commented out.
        // Uncomment it only if there is problem of RCA due to the
        // SUBNET_OBJECT connections to the devices.
        //
        //ExecuteStitcher('RemoveExcessSubnetLinks' , isRediscovery);

--->    ExecuteStitcher('VMWareESXiSnmp', isRediscovery);


        if (inferPEsUsingBGP == 1)
        {
            ExecuteStitcher('CreateMPLSPE' , isRediscovery);
        }
	}
---------------- end example snippet ----------------


The agent installation package also includes a VMWareESXi active object class (aoc) file, and will prompt you to install it.
The AOC file is not required, but recommended if you don't already have an active object class for VMWare ESXi devices.


After completion of the install, restart the ITNM processes.


Configuring the agent
=====================

The VMWare Host machine and any guest machine IP addresses must be in the discovery scope.

To enable the discovery agent, log into the TIP or DASH as a user with discovery configuration rights, 
and navigate to Discovery->Network Discovery Configuration. Click on the "Full Discovery Agents" tab, and enable the
"VMWareESXiSnmp" agent.

Running discovery
=================

Perform a full discovery and verify connectivity.

A note on object classes
========================
The default ITNM configuration contains the VMWare sysObjectId is listed in the EndNode.aoc (1.3.6.1.4.1.6876). This 
entry should be removed if you wish to leverage the aoc file included with this distribution, because if it is not
removed the EndNode.aoc file will take precedence.

