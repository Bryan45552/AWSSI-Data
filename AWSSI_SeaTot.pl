#!/bin/env perl

#Accumulated Winter Season Severity Index (AWSSI) 
#End of Season Total Values
#More info on AWSSI at mrcc.isws.illinois.edu/research/awssi/indexAwssi.jsp
#
# ARGUMENTS
# 
# 0: Station ID (Co-op, GHCN, ect.)
# 1: Start Year
# 2: End Year
#
# Example:
#
# perl AWSSI_SeaTot.pl 474546 1951 2017
#
# Output: All End of Season AWSSI Values 

use JSON;
use Date::Calc qw (Delta_Days);

#Define the start and end date for the ACIS call

# ACIS set up and call for SINGLE Station

$sid=$ARGV[0];
$syear=$ARGV[1];
$eyear=$ARGV[2];

#Set up start and end of Snow Year for the call

$sdate="$syear-07-01";
$edate="$eyear-06-30";


$outfile="$sid-AWSSI.csv";

open(OUT, ">$outfile") or die "Can't open";


$params = 'params={"sid":"'.$sid.'","sdate":"'.$sdate.'","edate":"'.$edate.'","elems":[{"name":"maxt","interval":"dly","duration":"dly"},{"name":"mint","interval":"dly","duration":"dly"},{"name":"snow","interval":"dly","duration":"dly"},{"name":"snwd","interval":"dly","duration":"dly"}]}';

#Makes the actual call

$json = `curl --data '$params' http://data.rcc-acis.org/StnData`;

#Decodes the JSON output from the call

$data = decode_json($json);

$meta = $$data{"meta"}; #Points to ALLLLL The metadata!

$name = $$meta{"name"}; #Points to the name of the station in the metadata

$lat= $$meta{"ll"}[1]; #Points to the part of the lat-lon array in the metadata that corrisponds to latitude

$lon= $$meta{"ll"}[0]; #Points to the part of the lat-lon array in the metadata that corrisponds to longitude

#Output File Header

print OUT "AWSSI End of Season Totals for\n$name\nLat $lat Lon $lon\n\n";
print OUT "Season End Year,AWSSI,TempAWSSI,SnowAWSSI,Season Start,Season End,Season Length,MmaxT,MminT,Msnow,MsnowD\n";

#Initialization for the while loop

$date=$$data{"data"}[0][0];
$i=0;
$startday=0;
$Mmaxt=0;$Mmint=0;$Msnow=0;$Msnwd=0;
$maxAWSSI=0;$minAWSSI=20000;$maxSnowAWSSI=0;$minSnowAWSSI=20000;$maxTempAWSSI=0;$minTempAWSSI=20000;
$maxSeaLen=0;$minSeaLen=367;

while($date ne "")
{
	#load in data 
	$maxt=$$data{"data"}[$i][1];
	$mint=$$data{"data"}[$i][2];
	$snow=$$data{"data"}[$i][3];
	$snwd=$$data{"data"}[$i][4];
	#load in date
	$year=substr($date,0,4);
	$month=substr($date,5,2);
	$day=substr($date,8,2);
	#Test if season has begun
	if(($maxt <=32 and $maxt ne "M") || ($snow >=0.1 and $snow ne "M") || $month==12){$seaStart=1;$startday++;}
	#If it has, mark the date for the output
	if($startday==1){$SeaStartDate=$date;}
	#And begin counting seasonal totals
	if($seaStart==1)
	{
		#Calculate the AWSSI values & track missing data
		($Amaxt,$Amint,$Asnow,$Asnwd,$AWSSI)=awssiCalc($maxt,$mint,$snow,$snwd);
                $Mmaxt=missing($maxt,$Mmaxt);
                $Mmint=missing($mint,$Mmint);
                $Msnow=missing($snow,$Msnow);
                $Msnwd=missing($snwd,$Msnwd);
		#Sum daily values with season total for temp, snow and total
		$tAWSSI=$tAWSSI+$Amaxt+$Amint;
		$sAWSSI=$sAWSSI+$Asnow+$Asnwd;
		$seaAWSSI=$seaAWSSI+$AWSSI;
		#Test for end of AWSSI season
		($PostSeaAWSSI,$SeaEndDate,$PostMmax,$PostMmin,$PostMsnow,$PostMsnwd)=seasonEnd($maxt,$mint,$snow,$snwd,$date,$Amint,$PostMmax,$PostMmin,$PostMsnow,$PostMsnwd);

	}
	#End of Snow Year Tests & Summaries
	if($month==6 && $day==30)
	{
		$seaAWSSI=$seaAWSSI-$PostSeaAWSSI; #Subtract min temp values that should not be accrued
		$tAWSSI=$tAWSSI-$PostSeaAWSSI; #As well in the tAWSSI values. Snow AWSSI never >0 after season end

                @sSt = (substr($SeaStartDate,0,4),substr($SeaStartDate,5,2),substr($SeaStartDate,8,2));
                @sEn = (substr($SeaEndDate,0,4),substr($SeaEndDate,5,2),substr($SeaEndDate,8,2));
		$seaLen = Delta_Days(@sSt,@sEn)-1;

                if($seaAWSSI <= 0){$seaAWSSI="M";$tAWSSI="M";$sAWSSI="M";$SeaStartDate="M";$SeaEndDate="M";$seaLen="M"}

                if($maxAWSSI <= $seaAWSSI){$maxAWSSI=$seaAWSSI;$maxAyr=$year;}
                if($minAWSSI >= $seaAWSSI and $seaAWSSI ne "M"){$minAWSSI=$seaAWSSI;$minAyr=$year;}
                if($maxTempAWSSI <= $tAWSSI){$maxTempAWSSI=$tAWSSI;$maxATyr=$year;}
                if($minTempAWSSI >= $tAWSSI and $tAWSSI ne "M"){$minTempAWSSI=$tAWSSI;$minATyr=$year;}
                if($maxSnowAWSSI <= $sAWSSI){$maxSnowAWSSI=$sAWSSI;$maxASyr=$year;}
                if($minSnowAWSSI >= $sAWSSI and $sAWSSI ne "M"){$minSnowAWSSI=$sAWSSI;$minASyr=$year;}

                if($maxSeaLen <= $seaLen){$maxSeaLen=$seaLen;$maxSeayr=$year;}
                if($minSeaLen >= $seaLen and $seaLen ne "M"){$minSeaLen=$seaLen;$minSeayr=$year;}

		$Mmaxt=$Mmaxt-$PostMmax;$Mmint=$Mmint-$PostMmin;$Msnow=$Msnow-$PostMsnow;$Msnwd=$Msnwd-$PostMsnwd;

		print OUT "$year,$seaAWSSI,$tAWSSI,$sAWSSI,$SeaStartDate,$SeaEndDate,$seaLen,$Mmaxt,$Mmint,$Msnow,$Msnwd\n";
		$seaAWSSI=0;$tAWSSI=0;$sAWSSI=0;
		$Mmaxt=0;$Mmint=0;$Msnow=0;$Msnwd=0;
		$PostSeaAWSSI=0;$startday=0;$seaStart=0;
	}
	
	


	$i++;
	$date=$$data{"data"}[$i][0];
}

#Summary Values 
print OUT "\nSummary\n\n";
print OUT "Max AWSSI,Year,Min AWSSI,Year,Max T AWSSI,Year,Min T AWSSI,Year,Max S AWSSI,Year,Min S AWSSI,Year,Longest Winter,Year,Shortest Winter,Year\n";
print OUT "$maxAWSSI,$maxAyr,$minAWSSI,$minAyr,$maxTempAWSSI,$maxATyr,$minTempAWSSI,$minATyr,$maxSnowAWSSI,$maxASyr,$minSnowAWSSI,$minASyr,$maxSeaLen,$maxSeayr,$minSeaLen,$minSeayr";

close(OUT);

##SUBROUTINES##

#Calculates the full AWSSI value for a day
#Calls the maxT, minT, snow and snwD value functions
#to determine each variable's contribution
sub awssiCalc
{

($maxIn,$minIn,$snowIn,$snwdIn)=@_;

$maxOUT=maxCalc($maxIn);
$minOUT=minCalc($minIn);
$snowOUT=snowCalc($snowIn);
$snwdOUT=snwdCalc($snwdIn);

$daytot=$maxOUT+$minOUT+$snowOUT+$snwdOUT;

return ($maxOUT,$minOUT,$snowOUT,$snwdOUT,$daytot);

}
#Calculates the AWSSI value for max temp
sub maxCalc
{
$valMx=$_[0];

if($valMx > 32){$Amx=0;}
elsif($valMx <= 32 && $valMx >= 25){$Amx=1;}
elsif($valMx <=24 && $valMx >=20){$Amx=2;}
elsif($valMx <=19 && $valMx >=15){$Amx=3;}
elsif($valMx <=14 && $valMx >=10){$Amx=4;}
elsif($valMx <=9 && $valMx >=5){$Amx=5;}
elsif($valMx <=4 && $valMx >=0){$Amx=6;}
elsif($valMx <=-1 && $valMx >=-5){$Amx=7;}
elsif($valMx <=-6 && $valMx >=-10){$Amx=8;}
elsif($valMx <=-11 && $valMx >=-15){$Amx=9;}
elsif($valMx <=-16 && $valMx >=-20){$Amx=10;}
elsif($valMx <-20){$Amx=15;}
if($valMx eq "M"){$Amx="M";}

return $Amx;

}
#Calculates the AWSSI value for min temp
sub minCalc
{

$valMn=$_[0];

if($valMn > 32){$Amn=0;}
elsif($valMn <= 32 && $valMn >= 25){$Amn=1;}
elsif($valMn <= 24 && $valMn >= 20){$Amn=2;}
elsif($valMn <= 19 && $valMn >= 15){$Amn=3;}
elsif($valMn <= 14 && $valMn >= 10){$Amn=4;}
elsif($valMn <= 9 && $valMn >= 5){$Amn=5;}
elsif($valMn <= 4 && $valMn >= 0){$Amn=6;}
elsif($valMn <= -1 && $valMn >= -5){$Amn=7;}
elsif($valMn <= -6 && $valMn >= -10){$Amn=8;}
elsif($valMn <= -11 && $valMn >= -15){$Amn=9;}
elsif($valMn <= -16 && $valMn >= -20){$Amn=10;}
elsif($valMn <= -21 && $valMn >= -25){$Amn=11;}
elsif($valMn <= -26 && $valMn >= -35){$Amn=15;}
elsif($valMn < -35){$Amn=20;}
if($valMn eq "M"){$Amn="M";}

return $Amn;
}
#Calculates the AWSSI value for snowfall
sub snowCalc
{
$valSn=$_[0];

if($valSn==0){$Asn=0;}
elsif($valSn >= 0.1 && $valSn <=0.9){$Asn=1;}
elsif($valSn >= 1.0 && $valSn <=1.9){$Asn=2;}
elsif($valSn >= 2.0 && $valSn <=2.9){$Asn=3;}
elsif($valSn >= 3.0 && $valSn <=3.9){$Asn=4;}
elsif($valSn >= 4.0 && $valSn <=4.9){$Asn=6;}
elsif($valSn >= 5.0 && $valSn <=5.9){$Asn=7;}
elsif($valSn >= 6.0 && $valSn <=6.9){$Asn=9;}
elsif($valSn >= 7.0 && $valSn <=7.9){$Asn=10;}
elsif($valSn >= 8.0 && $valSn <=8.9){$Asn=12;}
elsif($valSn >= 9.0 && $valSn <=9.9){$Asn=13;}
elsif($valSn >= 10.0 && $valSn <=10.9){$Asn=14;}
elsif($valSn >= 12.0 && $valSn <=12.9){$Asn=18;}
elsif($valSn >= 15.0 && $valSn <=17.9){$Asn=22;}
elsif($valSn >= 18.0 && $valSn <=23.9){$Asn=26;}
elsif($valSn >= 24.0 && $valSn <=29.9){$Asn=36;}
elsif($valSn >= 30.0){$Asn=45;}
if($valSn eq "M"){$Asn="M";}

return $Asn;

}
#Calculates the AWSSI value for snow depth
sub snwdCalc
{
$valSd=$_[0];

if($valSd==0){$Asd=0;}
elsif($valSd==1){$Asd=1;}
elsif($valSd==2){$Asd=2;}
elsif($valSd==3){$Asd=3;}
elsif($valSd >= 4 && $valSd <= 5){$Asd=4;}
elsif($valSd >= 6 && $valSd <= 8){$Asd=5;}
elsif($valSd >= 9 && $valSd <= 11){$Asd=6;}
elsif($valSd >= 12 && $valSd <= 14){$Asd=7;}
elsif($valSd >= 15 && $valSd <= 17){$Asd=8;}
elsif($valSd >= 18 && $valSd <= 23){$Asd=9;}
elsif($valSd >= 24 && $valSd <= 35){$Asd=10;}
elsif($valSd >= 36){$Asd=15;}
if($valSd eq "M"){$Asd="M";}

return $Asd;

}

#Tracks the season end date and possible post-season 
#ASWSSI values that need to be subtracted
sub seasonEnd
{

($endMaxt,$endMint,$endSnow,$endSnwd,$endDate,$exAMint,$Mismax,$Mismin,$Misnow,$Misnwd)=@_;

$testMo=substr($endDate,5,2);

	if((($endMaxt > 32 && ($endSnow==0 or $endSnow eq "T") && ($endSnwd==0 or $endSnwd eq "T")) or $endMaxt eq "M" or $endSnow eq "M" or $endSnwd eq "M") && ($testMo == 3 || $testMo == 4 || $testMo == 5 || $testMo == 6))
	{
		$EOSnoCnt=$EOSnoCnt+$exAMint;
                $Mismax=missing($maxt,$Mismax);
                $Mismin=missing($mint,$Mismin);
                $Misnow=missing($snow,$Misnow);
                $Misnwd=missing($snwd,$Misnwd);
	}
	else 
	{
		$EOSnoCnt=0;
		$Mismax=0;$Mismin=0;$Misnow=0;$Misnwd=0;
		$seaEndDate=$endDate;
	}

	return ($EOSnoCnt,$seaEndDate,$Mismax,$Mismin,$Misnow,$Misnwd);

}

#Tests for missing data
#Tracks the number of missing days
sub missing
{

$value=$_[0];
$missingtot=$_[1];

if($value eq "M") {$missingtot++;}

return $missingtot;

}
