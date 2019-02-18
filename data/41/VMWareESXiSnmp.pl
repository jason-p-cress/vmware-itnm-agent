#------------------------------------------------------------------
#
# This is a perl discovery agent that discovers the connectivity
# between a VMWare ESXi host system and the guests that are
# running on it.  
#
# Note that SNMP access must be configured on the ESXi server for
# this agent to work.
#
# v1 release 8/29/14
# Jason Cress - IBM SWG
#
# Special thanks to Jim Kovach at Allstate for providing assistance
# in building this agent.
#
# This agent employs the CiscoSwitchInPerl agent as a template for
# its structure.
#
#------------------------------------------------------------------
use strict;
use warnings;
use Data::Dumper;


use RIV;
use RIV::Param;
use RIV::Record;
use RIV::Agent;
use Socket;

# standard out is buffered. Waits until full before flushing to screen
# this forces it to print it straight out rather than waiting
# makes the debug MUCH easier to read.
$| =1 ;

my $agent;
my $agentName = "VMWareESXiSnmp";

#---------------------------------------------------------------------
#Initiation
#
# we create a new agent with a name 
#
#---------------------------------------------------------------------
sub Init{
    my $param=new RIV::Param();
    $agent=new RIV::Agent($param, $agentName);
}

#---------------------------------------------------------------------
# ProcessPhase
#
# Do any phase dependent processing. 
#
#---------------------------------------------------------------------
sub ProcessPhase($){
	my $phaseNumber = shift;

	if($RIV::DebugLevel >= 1)
	{
		print "Phase number is $phaseNumber\n";
	}
}

#---------------------------------------------------------------------
# ProcessPhase1
#
# Do processing of the NE necessary during phase 1
#
#---------------------------------------------------------------------
sub ProcessPhase1($){
	my $TestNE = shift;
	if($RIV::DebugLevel >= 1)
	{
		print "Processing Phase 1\n";
		print Dumper($TestNE);
	}


	if($RIV::DebugLevel >= 1)
	{
		print "Entity now .\n";
		print Dumper($TestNE);
	}

	$agent->SendNEToNextPhase($TestNE);
}


#---------------------------------------------------------------------
# ProcessPhase2
#
# Do processing of the NE necessary during phase 2
#
#---------------------------------------------------------------------
sub ProcessPhase2($){
	my $TestNE = shift;
	if($RIV::DebugLevel >= 1)
	{
		print "Processing Phase 2\n";
		print Dumper($TestNE);
	}

	$agent->SendNEToNextPhase($TestNE);
}

#---------------------------------------------------------------------
# ProcessPhase3
#
# Do processing of the NE necessary during phase 3
#
#---------------------------------------------------------------------
sub ProcessPhase3($){
	my $TestNE = shift;
	if($RIV::DebugLevel >= 1)
	{
		print "Processing Phase 3\n";
		print Dumper($TestNE);
	}

   my $refLphysAddress=$agent->SnmpGetNext($TestNE,'ifPhysAddress');
   my $refLifDescr=$agent->SnmpGetNext($TestNE,'ifDescr');
   my $refLipIfIndex=$agent->SnmpGetNext($TestNE,'ipAdEntIfIndex');
   my $refLnetMask=$agent->SnmpGetNext($TestNE,'ipAdEntNetMask');
   my $vmguests=$agent->SnmpGetNext($TestNE,'vmwVmDisplayName');
   my $vmmacs=$agent->SnmpGetNext($TestNE,'vmwVmMAC');

   print "Guests: $vmguests";
   print "MACs: $vmmacs";

# Get information for the interfaces on this ESXi server. Configured vSwitches are
# enumerated in the MIB-II interface table

       for (my $j=0;$j<=$#$refLphysAddress;$j++)
        {
                my $ifIndex = $refLphysAddress->[$j]->{ASN1};
                my $physAddress = $refLphysAddress->[$j]->{VALUE};
                my %localNbr;
                $localNbr{m_IfIndex} = $ifIndex;
                print "========== $ifIndex\n";
                $localNbr{m_LocalNbrPhysAddr} = $physAddress;
                my $ifDescr = GetValueForKey($refLifDescr, $ifIndex);
                $localNbr{m_IfDescr} = $ifDescr;
                $TestNE->AddLocalNeighbour(\%localNbr);
        }

# Cycle through the guests that are running on this machine, get the VM index and name

  for (my $j=0;$j<=$#$vmguests;$j++)
  {
        #print "VMGUEST INFORMATION DOWNLOADED:\n";
        #print $j, "\n";

        print "=== found vm machine with name $vmguests->[$j]->{VALUE}\n";
        #$vmguests->[$j]->{ASN1} =~ /^[0-9]+\.([0-9]+)/;
        my $vmindex = $vmguests->[$j]->{ASN1};;
        my $vmname = $vmguests->[$j]->{VALUE};

        my $MACAddr = GetValueForKey($vmmacs, $vmindex);

        print "VMName is: $vmname\nVMIndex is: $vmindex\nMAC Address is: $MACAddr";

  }

# Cycle through the list of guest network interface mac addresses,
# Resolve IP addresses for the guest physical addresses

  for (my $j=0;$j<=$#$vmmacs;$j++)
  {
                my $remoteMac = $vmmacs->[$j]->{VALUE};;

                # Attempt to retrieve the remote neighbour ip
                print "==== ATTEMPTING TO RETREIVE ARP ENTRY FOR MAC $remoteMac\n";
                my $remoteIp=$agent->GetIpArp($remoteMac);
                print "==== REMOTE IP: $remoteIp\n";

                my %remoteNbr;
                $remoteNbr{m_RemoteNbrPhysAddr} = $remoteMac;
                if($remoteIp)
                {
                        $remoteNbr{m_RemoteNbrIpAddr} = $remoteIp;

                        # NOTE: We tie it explicitely to the 2nd ifIndex. This isn't entirely accurate, but VMWare's SNMP implementation doesn't tie the host MAC address to a specific ifIndex, unfortunately
                        my $ifIndex = 2; 

                        AttachLocalNbrByIfIndex($TestNE, \%remoteNbr, $ifIndex);
			print "===== Added remote connection for remote neigbor:\n";
			print Dumper(\%remoteNbr);
                }

   }

	delete $TestNE->{'__NcpDiscoAgentNePhase__'};
    $TestNE->{'m_LastRecord'}=1;
    $TestNE->{'m_UpdAgent'}=$agentName;

	print "Sending record to disco: \n";
		print Dumper($TestNE);
	$agent->SendNEToDisco($TestNE,0);
}

#---------------------------------------------------------------------
#
# Returns a value corresponding to the key from an array of varOps
#
#---------------------------------------------------------------------
sub GetValueForKey
{
  my ($refArray,$key) = @_;

  for (my $jj=0; $jj<=$#$refArray; $jj++)
  {
    if ($refArray->[$jj]->{ASN1} eq $key)
    {
       return $refArray->[$jj]->{VALUE};
    }
  }
  return;
}
#---------------------------------------------------------------------
#
# Returns ASN1 corresponding to the value from an array of varOps
#
#---------------------------------------------------------------------
sub GetKeyForValue
{
  my ($refArray,$value) = @_;

  for (my $jj=0; $jj<=$#$refArray; $jj++)
  {
    if ($refArray->[$jj]->{VALUE} eq $value)
    {
       return $refArray->[$jj]->{ASN1};
    }
  }
  return;
}

#---------------------------------------------------------------------
#
# Find the appropriate local neighbour to connect the remote neighbour to
#
#---------------------------------------------------------------------
sub AttachLocalNbrByIfIndex ($)
{
	my ($TestNE, $refR, $ifIndex) = @_;

	my $foundIt = 0;
	if( ($ifIndex) && ($TestNE) && ($refR) )
	{
		my @localN = $TestNE->GetLocalNeighbours();
		foreach my $lnbr (@localN)
		{
			# Look for the local neighbour that has the same ifIndex as earlier
			if ( ($lnbr->{m_IfIndex}) && ($lnbr->{m_IfIndex} eq $ifIndex) )	
			{
				if($RIV::DebugLevel >= 1)
				{
					print " Matched ifIndex $lnbr->{m_IfIndex} to $ifIndex \n";
					print "Adding to device $TestNE->{m_Name}\n";
					print "via local neighbour \n";
					print Dumper($lnbr);
					print " connection to remote record\n";
					print Dumper($refR);
				}
				$TestNE->AddRemoteNeighbour($lnbr, $refR);
				$foundIt = 1;
			}
		}
	}

	if($foundIt == 0)
	{
		if(!$ifIndex)
		{
			$ifIndex = "NULL";
		}
		print "Failed to find interface with ifIndex $ifIndex for device $TestNE->{m_Name}\n";
		print " to add remote record\n";
		print Dumper($refR);
	}
}

#---------------------------------------------------------------------
#
# Add a variable to a local neighbour record 
#
#---------------------------------------------------------------------
sub AddFieldToLocalNeighbour($)
{
	my ($TestNE, $ifIndex, $fieldName, $fieldValue) = @_;

	my $foundIt = 0;
	if( ($ifIndex) && ($TestNE) )
	{
		my @localN = $TestNE->GetLocalNeighbours();
		foreach my $lnbr (@localN)
		{
			# Look for the local neighbour that has the same ifIndex as earlier
			if ( ($lnbr->{m_IfIndex}) && ($lnbr->{m_IfIndex} eq $ifIndex) )	
			{
				if($RIV::DebugLevel >= 1)
				{
					print " Matched ifIndex $lnbr->{m_IfIndex} to $ifIndex \n";
					print "Adding to device $TestNE->{m_Name} ";
					print "via ifIndex $ifIndex field $fieldName value $fieldValue \n";
				}
				$lnbr->{$fieldName} = $fieldValue;
				$foundIt = 1;
			}
		}
	}

	if($foundIt == 0)
	{
		if(!$ifIndex)
		{
			$ifIndex = "NULL";
		}
		print "Failed to find interface with ifIndex $ifIndex for device\n";
		print " $TestNE->{m_Name} to add field $fieldName with value $fieldValue.\n";
	}
}

#---------------------------------------------------------------------
#
# Get a variable of a local neighbour record 
#
#---------------------------------------------------------------------
sub GetFieldOfLocalNeighbour($)
{
	my ($TestNE, $ifIndex, $fieldName) = @_;
	my $fieldValue;

	my $foundIt = 0;
	if( ($ifIndex) && ($TestNE) )
	{
		my @localN = $TestNE->GetLocalNeighbours();
		foreach my $lnbr (@localN)
		{
			# Look for the local neighbour that has the same ifIndex as earlier
			if ( ($lnbr->{m_IfIndex}) && ($lnbr->{m_IfIndex} eq $ifIndex) )	
			{
				$fieldValue = $lnbr->{$fieldName};
			}
		}
	}
	
	return $fieldValue;
}

sub ConvertASN1ToMac($)
{
	my $asn1String = shift; 

	my $macStr = "";

	my @numbers = split /\./, $asn1String;
	my $num = 0;
	my $first = 0;
	foreach $num (@numbers)
	{ 
		my $hexVal = sprintf "%02X",  $num;
		if($first == 0)
		{
			$macStr = "$hexVal";
			$first = 1;
		}
		else
		{
			$macStr = "$macStr:$hexVal";
		}
	}

	if($RIV::DebugLevel >= 1)
	{
		print "Converted $asn1String to $macStr.\n";
	}

	return $macStr;
}

#------------------------------------------------------------------
# create a new agent object
#------------------------------------------------------------------
if($RIV::DebugLevel >= 1)
{
	print "Creating a new agent\n";
}
Init();

#-----------------------------------------------------------------
#
# We are now ready to receive records from the Disco
#
#-----------------------------------------------------------------
print "Entering infinite loop wait for devices for Disco\n";

INFINITE: while (1)
{
	my ($tag,$data)=RIV::GetInput(-1);
	# all network devices are tagged with the tag NE
	if ($tag ne 'NE')
	{
		print "Data is not a Network entity Ignoring it!\n";
		next INFINITE;
	}

	my $TestNE=new RIV::Record($data);

    if ($TestNE->{m_TerminateAgent})
    {
        print "Exit Main Loop\n";
        exit(0);
    }

	$TestNE->{m_LastRecord}=1;
	$TestNE->{m_UpdAgent}=$agentName;

	# Is the record a phase tag. If it is then process it differently
	if($TestNE->{m_NewPhase})
	{
		ProcessPhase($TestNE->{m_NewPhase});
		next INFINITE;
	}
	else
	{
		# Retrieve the phase
		my $phase = $TestNE->{__NcpDiscoAgentNePhase__};
		if($phase == 1)
		{
			ProcessPhase1($TestNE);
		}
		elsif($phase == 2)
		{
			ProcessPhase2($TestNE);
		}
		elsif($phase == 3)
		{
			ProcessPhase3($TestNE);
		}
		else
		{
			# do nothing;
			print "Unexpected phase, doing nothing\n";
		}
	}
} # the main loop ends

