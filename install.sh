#!/bin/bash

##########################
#
# Installation for the VMWareSnmpEsxi agent
#
# 8/29/16
# Jason Cress
# jcress@us.ibm.com 
#
###########################################################

##########################
#
# Subroutines
#
###########################################################
docopy()
{
	if [ -f "$2/$1" ];
	then

		while true; do
			read -p "Warning: $2/$1 already exists, overwrite? ([y]es/[n]o/[c]ancel)" YESNO
			case $YESNO in
				[Yy]* ) echo "Overwriting $2/$1"; cp data/$VERDIR/$1 $2/$1; break;; 
				[Nn]* ) echo "Skipping install of $1"; break;;
				[Cc]* ) echo "Cancelling install"; exit;;
				* ) echo "Please answer y, n, or c";;
			esac
		done
	else
		cp data/$VERDIR/$1 $2
	fi
}

############################
#
# Set up environment
#
#############################################################

if [ -n "$NCHOME" ]
then
	echo "Setting up environment"
	. $NCHOME/env.sh
else
	echo "NCHOME not set, attempting to locate"
	if [ -f /opt/IBM/tivoli/netcool/env.sh ]
	then
		. /opt/IBM/tivoli/netcool/env.sh
	elif [ -f /opt/IBM/netcool/env.sh ] 
	then
		. /opt/IBM/netcool/env.sh
	elif [ -f /opt/IBM/netcool/core/env.sh ]
	then
		. /opt/IBM/netcool/core/env.sh
	else
		echo "Unable to find env.sh environment file for ITNM. Set NCHOME environment variable to env.sh location and rerun this script"
		exit
	fi
	echo "Found environment file, NCHOME is $NCHOME"
fi

ITNM_BIN_DIR=${PRECISION_HOME}/bin
    ITNM_CONTROL_FUNCS=${ITNM_BIN_DIR}/itnm_control_functions.sh

    if [ -z "$PRECISION_DOMAIN" ]; then
        PRECISION_DOMAIN=NCOMS
    fi


############################
#
# Obtain ITNM version
#
#######################################################

ITNMVER=`$PRECISION_HOME/bin/ncp_ctrl -version | grep Version |awk '{print $6}'`
echo "ITNM is version $ITNMVER"

case $ITNMVER in
	4.2) 
		CHK=abc329972cec173d4131902bf9bc6c9f
		VERDIR=42
		;;
	4.1.1) 
		CHK=852cc31e13a6c2292ceb8ef8bdb7c073
		VERDIR=41
		;; 
	4.1) 
		CHK=852cc31e13a6c2292ceb8ef8bdb7c073
		VERDIR=41
		;;
	3.9) 
		CHK=2a70dae75d6f798c6e97f4562c35e32d
		VERDIR=39
		;;
	* ) 
		echo "This version of ITNM is not supported at this time"
		exit
		;;

esac

############################
#
# Begin installation...
#
#############################################################

while true; do
	read -p "This installation program will install the VMWare ESXi perl-based discovery agent. Do you wish to continue? ([y]yes/[n]o)" INST
	case $INST in
                        [Yy]* ) echo "Installing....."; break;;
                        [Nn]* ) echo "Cancelling install"; exit;;
                        * ) echo "Please answer y or n";;
        esac
done

###########################
#
# Verify required MIBs are installed
#
####################################

if [ -f "$PRECISION_HOME/mibs/VMWARE-TC-MIB.mib" ] && [ -f "$PRECISION_HOME/mibs/VMWARE-PRODUCTS-MIB.mib" ] && [ -f "$PRECISION_HOME/mibs/VMWARE-VMINFO-MIB.mib" ]  && [ -f "$PRECISION_HOME/mibs/VMWARE-ROOT-MIB.mib" ] && [ -f "$PRECISION_HOME/mibs/VMWARE-ENV-MIB.mib" ]
then
	:
else
	while true; do
		read -p "Warning: Required MIB files do not appear to be installed (VMWARE-VMINFO-MIB.mib, VMWARE-ENV-MIB.mib, VMWARE-TC-MIB.mib, VMWARE-ROOT-MIB.mib, VMWARE-ENV-MIB.mib). Do you wish to continue install anyway? ([y]es/[n]o)" CONT
		case $CONT in
			[Yy]* ) echo "Continuing with install - ensure that you obtain and install the required VMWare MIBs before activating the agent"; break;;
			[Nn]* ) echo "Cancelling install"; exit;;
			* ) echo "Please answer y or n";;
		esac
	done
fi

############################
#
# Copy files
#
#############################################################

echo "***************************************"
echo "* Installing the VMWareESXiSnmp agent *"
echo "***************************************"

docopy "VMWareESXiSnmp.stch" "$PRECISION_HOME/disco/stitchers"
docopy "VMWareESXiSnmp.pl" "$PRECISION_HOME/disco/agents/perlAgents/"
docopy "VMWareESXiSnmp.agnt" "$PRECISION_HOME/disco/agents"

############################
#
# Register agent
#
#############################################################

$NCHOME/precision/bin/ncp_agent_registrar -register VMWareESXiSnmp

############################
#
# Check to see if PostLayerProcessing stitcher is customized 
#
#############################################################

if [ -f /usr/bin/md5sum ];
then
	PLPSMD5=`/usr/bin/md5sum $PRECISION_HOME/disco/stitchers/PostLayerProcessing.stch | awk '{print $1}'`
fi
if [ "$PLPSMD5" == "$CHK" ];
then
	echo "*****************************************"
	echo "* Updating PostLayerProcessing stitcher *"
	echo "*****************************************"
	cp data/$VERDIR/PostLayerProcessing.stch $PRECISION_HOME/disco/stitchers
else
	echo "********************************************************************************"
	echo "*                                                                              *"
	echo "* NOTICE: Your PostLayerProcessing.stch is not the default provided with ITNM. *"
	echo "*                                                                              *"
	echo "* Perhaps it has been modified or customized.                                  *"
	echo "*                                                                              *"
	echo "* Please manually add call to VMWareESXiSnmp agent to the PostLayerProcessing  *"
	echo "* stitcher. See the included README for details.                               *"
	echo "*                                                                              *"
	echo "* example:                                                                     *"
	echo "* ExecuteStitcher('VMWareESXiSnmp', isRediscovery);                            *"
	echo "*                                                                              *"
	echo "********************************************************************************"
fi

echo
echo
while true; do
	read -p "Do you wish to install the VMWareESXi active object class (aoc) file? (not required but recommended) ([y]es/[n]o)" CONT
		case $CONT in
			[Yy]* ) echo "installing AOC file..."; break;;
			[Nn]* ) echo "skipping AOC file install"; exit;;
			* ) echo "Please answer y or n";;
		esac
done
docopy "VMWareESXi.aoc" "$PRECISION_HOME/aoc/"
