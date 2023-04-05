#!/bin/bash
# name          : ap-config
# desciption    : apache PHP configure script
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 0.1
# notice 	: 
# infosource	: https://speefak.spdns.de/oss_lifestyle/lvm-installation-auf-luks-basis-und-manueller-partitionierung 
#		  https://askubuntu.com/questions/453969/how-can-i-order-gnome3-shell-extensions-at-the-top
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 RequiredPackets="bash sed awk"

 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)
 Version=$(cat $ScriptFile | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')

 PHP_BackupDir="$HOME/PHP_bck_$(date +%F-%H%M%S)"
 PHP_Repository="deb https://packages.sury.org/php/ $(lsb_release -sc) main"

#------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	OptionVarList="

		HelpDialog;-h
		Monochrome;-m
		ScriptInformation;-si
		CheckForRequiredPackages;-cfrp

		BackupConfigs;-b
		InstallPHPRepo;-ipr
		ShowApacheModules;-sa
		ChangePHPVersion;-cpv
	"
	# set entered vars from optionvarlist
	OptionAllocator=" "										# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for InputOption in $(echo " $@" | sed -e 's/-[a-z]/\n\0/g' ) ; do  				# | sed 's/ -/\n-/g'
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
			if [[ -n $(echo " $InputOption" | grep -w " $VarValue" 2>/dev/null) ]]; then 
				InputOption=$(sed 's/[ 0]*$//'<<< $InputOption)
				eval $(echo "$VarName"='$InputOption')					# if [[ -n Option1 ]]; then echo "Option1 set";fi
				#eval $(echo "$VarName"="true")
			elif [[ $(echo $InputOption | cut -d "$OptionAllocator" -f1) == "$VarValue" ]]; then
				eval $(echo "$VarName"='$(echo $InputOption | cut -d "$OptionAllocator" -f 2-10)')
			fi
		done
	done
	IFS=$SAVEIFS

#------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
load_color_codes () {
	# parse required colours for echo/printf usage: printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'

	BG='\033[47m'
	FG='\033[0;30m'

	# parse required colours for sed usage: sed 's/status=sent/'${Green}'status=sent'${Reset}'/g' |\
	if [[ $1 == sed ]]; then
		for ColorCode in $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='"); do
			eval $(sed 's|\\|\\\\|g' <<< $ColorCode)						# sed parser '\033[1;31m' => '\\033[1;31m'
		done
	fi
}
#------------------------------------------------------------------------------------------------------------
usage() {
	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n"
	printf " -h		=> help dialog \n"
	printf " -m		=> monochrome output \n"
	printf " -si		=> show script information \n"
	printf " -cfrp		=> check for required packets \n"
	printf " \n"
	printf " -b		=> backup configs (PHP,apache) \n"
	printf " -ipr		=> install and activate PHP repository \n"
	printf " -sa (a|e|d)	=> show apache modules (Available|Enabled|Disabled) \n"
	printf " -cpv		=> change PHP version \n"
	printf  "\n${LRed} $1 ${Reset}\n"
	printf "\n"
	exit
}
#------------------------------------------------------------------------------------------------------------
script_information () {
	printf "\n"
	printf " Scriptname: $ScriptName\n"
	printf " Version:    $Version \n"
	printf " Scriptfile: $ScriptFile\n"
	printf " Filesize:   $(ls -lh $0 | cut -d " " -f5)\n"
	printf "\n"
	exit 0
}
#------------------------------------------------------------------------------------------------------------
check_for_required_packages () {

	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
   		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: \e[0;31m $MissingPackets\e[0m\n"$(tput sgr0)
		read -e -p "install required packets ? (Y/N) "		 	-i "Y" 		InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf  "programm error: $LRed missing packets : $MissingPackets $Reset\n\n"$(tput sgr0)
			exit 1
		fi

	else
		printf "$LGreen all required packets detected$Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------
Countdown_request () {

	RequestCountdown=10
	CountdownRequestMessage="proceed ?"
	tput civis 
	for i in $(seq 1 $RequestCountdown) ;do
		read -t1 -n1 -s -p "$CountdownRequestMessage (y/n) " Request
		request () {
			if   [[ "$Request" == "[yY]" ]]; then
				DeleteUserConfigs=true
				break	
			elif [[ "$Request" == "[nN]" ]]; then
				DeleteUserConfigs=false
				break
			elif   [[ -n "$Request" ]] ;then 
				request	
			fi
			DeleteUserConfigs=true
			printf '%2s\r' $(echo $(($RequestCountdown-$i)))
		}
		request
	done
	printf '%50s\r'
	tput cnorm
}
#------------------------------------------------------------------------------------------------------------
countdown_default () {
	tput civis 
	CountdownTimer=20
	CountdownMessage="Kill and restart in: (press any key to abort) "
	for i in $(seq 1 $CountdownTimer) ;do
		read -t1 -n1 -s -p "$CountdownMessage" Request1 
			if   [[ -n "$Request1" ]] ;then
				printf "\nContinue running instance.\n"
				printf "Exit ...\n"
				tput cnorm
				exit 						
			fi
			printf '%2s\r' $(echo $(($CountdownTimer-$i)))
	done
	printf '%50s\r'
	tput cnorm 
}
#------------------------------------------------------------------------------------------------------------
backup_configs () {

	mkdir $PHP_BackupDir
	sudo cp -r /etc/php* $PHP_BackupDir
	sudo apt list --installed | grep php- | cut -d "/" -f1 > $PHP_BackupDir/PHP_packages_installed.lst
	sudo apachectl -M > $PHP_BackupDir/apache_modules
}

#------------------------------------------------------------------------------------------------------------
install_php_repo () {

	sudo wget https://packages.sury.org/php/apt.gpg -O /etc/apt/trusted.gpg.d/php-sury.gpg
	echo "$PHP_Repository" | sudo tee /etc/apt/sources.list.d/php-sury.list
	sudo apt update
}
#------------------------------------------------------------------------------------------------------------
show_apache_modules () {

	ApacheModsAvailable=$(ls /etc/apache2/mods-available/ | sed 's/.conf//;s/.load//' | uniq)
	ApacheModsActive=$(ls /etc/apache2/mods-enabled/ | sed 's/.conf//;s/.load//' | uniq)

	ApacheModListParsed=$(for i in $ApacheModsAvailable ; do 
				if [[ -n $(grep -w $i <<< "$ApacheModsActive" ) ]]; then
					printf "$LGreen   active:  $i $Reset\n"
				else
					printf "$LRed inactive:  $i $Reset\n"
				fi
	
			      done)


	ApacheModListFiltered=$(
				if   [[ $ShowApacheModules == "-sa a" ]]; then
					echo "$ApacheModListParsed"
				elif [[ $ShowApacheModules == "-sa e" ]]; then
					echo "$ApacheModListParsed" | grep -w "active:"
				elif [[ $ShowApacheModules == "-sa d" ]]; then
					echo "$ApacheModListParsed" | grep -w "inactive:"
				else 
					usage "invalid input: $ShowApacheModules"		
				fi
				)

	if [[ -n $Monochrome ]]; then
		printf "$ApacheModListFiltered" | sed 's/^/ /'
	else
		printf "$ApacheModListFiltered" | sed 's/ .*active://'
	fi

	printf "\n\n"
}
#------------------------------------------------------------------------------------------------------------
change_php_version () {

echo

}
#------------------------------------------------------------------------------------------------------------






#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	# check for cronjob execution and cronjob options
	CronExecution=
	if [ -z $(grep "/" <<< "$(tty)") ]; then
		CronExecution=true
		Monochrome=true
	fi

#------------------------------------------------------------------------------------------------------------

	# check for monochrome output
	Reset='\033[0m'
	if [[ -z $Monochrome ]]; then
		load_color_codes
	fi

#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ -n $HelpDialog ]] || [[ -z $1 ]]; then usage "help dialog" ; fi

#------------------------------------------------------------------------------------------------------------

	# check for script information
	if [[ -n $ScriptInformation ]]; then script_information ; fi

#------------------------------------------------------------------------------------------------------------

#	# check for root permission
#	if [ "$(whoami)" = "root" ]; then echo "";else printf "$LRed Are You Root ?\n";exit 1;fi

#------------------------------------------------------------------------------------------------------------

	# check for required package
	if [[ -n $CheckForRequiredPackages ]]; then check_for_required_packages; fi

#------------------------------------------------------------------------------------------------------------

	# backup php and apache configs before applying changes
	if [[ -n $BackupConfigs$ChangePHPVersion ]]; then
		printf "$LYellow backup configs ( PHP / apache ) ... $Reset"
		backup_configs
	fi

#------------------------------------------------------------------------------------------------------------

	# install and activate php repository
	if [[ -n $InstallPHPRepo ]]; then
		printf "$LYellow activating php repo: ($PHP_Repository) ...$Reset\n"
		install_php_repo
	fi

#------------------------------------------------------------------------------------------------------------

	# show apache module list
	if [[ -n $ShowApacheModules ]]; then
		printf "\n$LYellow apache module list: $Reset\n\n"
		show_apache_modules
	fi

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################



root@D11-Webserver:/var/www/html> for i in $(ls /etc/apache2/mods-available/ | sed 's/.conf//;s/.load//' | uniq) ; do echo $i ; done

