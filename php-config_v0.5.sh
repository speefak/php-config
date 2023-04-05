#!/bin/bash
# name          : ap-config
# desciption    : apache PHP configure script
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 0.5
# notice 	: 
# infosource	: 
#		  
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 RequiredPackets="bash sed awk"

 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)
 Version=$(cat $ScriptFile | grep -m 1 "# version" | awk -F ": " '{print $2}' )

 PHP_BackupDir="$HOME/PHP_bck_$(date +%F-%H%M%S)"
 PHP_Repository="deb https://packages.sury.org/php/ $(lsb_release -sc) main"

 ApacheModsAvailable=$(ls /etc/apache2/mods-available/ | sed 's/.conf//;s/.load//' | uniq)
 ApacheModsActive=$(ls /etc/apache2/mods-enabled/ | sed 's/.conf//;s/.load//' | uniq)

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
		ShowApacheModules;-sam
		ShowPHPConfiguration;-spc
		ChangePHPVersion;-cpv
		ShowInstalledPHPVersion;-sip
		ShowAvailablePHPVersion;-sap
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
	printf " -h			  => help dialog \n"
	printf " -m			  => monochrome output \n"
	printf " -si			  => show script information \n"
	printf " -cfrp			  => check for required packets \n"
	printf " \n"
	printf " -b			  => backup configs (PHP,apache) \n"
	printf " -ipr			  => install and activate PHP repository \n"
	printf " -sap			  => show available php versions \n"
	printf " -sip			  => show installed php versions \n"
	printf " -sam (a|e|d) => show apache modules (Available|Enabled|Disabled) \n"
	printf " -cpv			  => change PHP version \n"
	printf " -spc			  => show PHP configuration \n"
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
backup_configs () {

	mkdir $PHP_BackupDir
	sudo cp -r /etc/php* $PHP_BackupDir
	dpkg -l | grep ^ii | grep php | awk -F " " '{print $2}' >  $PHP_BackupDir/PHP_packages_installed.lst

	echo -en "\n\n  available mods:\n\n$ApacheModsAvailable\n"		>  $PHP_BackupDir/apache_modules
	echo -en "\n\n  active mods:\n\n$ApacheModsActive\n"			>> $PHP_BackupDir/apache_modules

#	error log output => obsolet
#	sudo apt list --installed | grep php- | cut -d "/" -f1 > $PHP_BackupDir/PHP_packages_installed.lst
#	sudo apachectl -M > $PHP_BackupDir/apache_modules
}

#------------------------------------------------------------------------------------------------------------
install_php_repo () {

	sudo wget https://packages.sury.org/php/apt.gpg -O /etc/apt/trusted.gpg.d/php-sury.gpg
	echo "$PHP_Repository" | sudo tee /etc/apt/sources.list.d/php-sury.list
	sudo apt update
}
#------------------------------------------------------------------------------------------------------------
show_available_PHP_Versions ()  {
#TODO
	printf "\n"
	apt-cache search php | grep -w "^php[[:digit:]].[[:digit:]] " | cut -d "-" -f1  | sed 's/php/  php /' | sort
	printf "\n"
}
#------------------------------------------------------------------------------------------------------------
show_installed_PHP_Versions () {
#TODO
	printf "\n"
	dpkg -l | grep ^ii  | awk -F " " '{print $2}' | grep -w "^php[[:digit:]].[[:digit:]]$" | sed 's/php/  php /' | sort
	printf "\n"
}
#------------------------------------------------------------------------------------------------------------
show_apache_modules () {

	ApacheModListParsed=$(for i in $ApacheModsAvailable ; do 
				if [[ -n $(grep -w $i <<< "$ApacheModsActive" ) ]]; then
					printf "$LGreen   active:  $i $Reset\n"
				else
					printf "$LRed inactive:  $i $Reset\n"
				fi
	
			      done)

	ApacheModListFiltered=$(
				if   [[ $ShowApacheModules == "-sam a" ]]; then
					echo "$ApacheModListParsed"
				elif [[ $ShowApacheModules == "-sam e" ]]; then
					echo "$ApacheModListParsed" | grep -w "active:"
				elif [[ $ShowApacheModules == "-sam d" ]]; then
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
show_php_version () {

	PHPVersionCLI=$(php -v | head -n1 | awk '{printf $2}')
	PHPVersionCGI=$(php-cgi -v | head -n1 | awk '{printf $2}')
	PHPVersionFPM=$(systemctl --type=service | grep php | sed 's/.service.*$//;s/ //g' | tr "\n" " ")
	PHPVersionApache=$(ls /etc/apache2/mods-enabled/php*.conf | tr "/" "\n" | grep "^php" | sed 's/.conf//;s/php//')

	printf " PHP version CLI:	$PHPVersionCLI\n"
	printf " PHP version CGI:	$PHPVersionCGI\n"
	printf " PHP version FPM:	$PHPVersionFPM\n"
	printf " PHP version Apache:	$PHPVersionApache\n"
}
#------------------------------------------------------------------------------------------------------------
change_php_version () {

	AvailablePHPVersions=$(apt-cache search php | grep -w "^php[[:digit:]].[[:digit:]] " | cut -d "-" -f1)

	# create menu
	MenuList=$(echo "$(show_php_version && echo -en " all\n cancel" )" | nl )
 	MenuListCount=$(grep -c . <<<$MenuList)

	# php service selection
	printf "$MenuList\n\n"
	read -e -p " select PHP service: "	-i "$MenuListCount" 		PHPSelection
#	printf "\n"

	# get selected string
	SelectedPHPService=$(echo "$MenuList" | sed 's/^[[:space:]]*//' | grep "^$PHPSelection" | sed 's/[[:digit:]]*[[:space:]]*//')

	# check input selection
	if   [[ -z $SelectedPHPService ]]; then
		change_php_version
	elif [[ $SelectedPHPService == cancel ]]; then
		printf " exit ... \n"
		exit 0
	fi

	# process input selection
	if   [[ -n $( grep -w "CLI:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for CLI service ... $Reset\n"

	elif [[ -n $( grep -w "CGI:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for apache service ... $Reset\n"

	elif [[ -n $( grep -w "FPM:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for apache service ... $Reset\n"

	elif [[ -n $( grep -w "Apache:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for apache service ... $Reset\n"

	elif [[ -n $( grep -w "all" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for all services ... $Reset\n"

	else
		usage "PHP selection error"
	fi



#TODO

#	# select option ever uses columns - disable colums for selection needed
#	SAVEIFS=$IFS
#	IFS=$(echo -en "\n\b")
#	PS3="select php modul number: "
#	select brand in $(show_php_version | sed 's/^ //' ) all cancel ; do		
#		if [[ -n $brand ]]; then
#			break
#		fi
#	done
#	IFS=$SAVEIFS
#
#	echo "You have chosen $brand"


exit
# unmask systemctl service files and start service
if [[ -n $(service php8.2-fpm start 2>&1 | grep masked) ]]; then
	printf " unmasking php8.2-fpm: "
	sudo systemctl unmask  php8.2-fpm
	sudo service php8.2-fpm start 
fi


}
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

	# check for required packages
	if [[ -n $CheckForRequiredPackages ]]; then check_for_required_packages; fi

#------------------------------------------------------------------------------------------------------------

	# backup php and apache configs before applying changes
	if [[ -n $BackupConfigs$ChangePHPVersion ]]; then
		printf "$LYellow backup configs ( PHP / apache ) ... $Reset \n"
		backup_configs
	fi

#------------------------------------------------------------------------------------------------------------

	# install and activate php repository
	if [[ -n $InstallPHPRepo ]]; then
		printf "$LYellow activating php repo: ($PHP_Repository) ... $Reset\n"
		install_php_repo
	fi

#------------------------------------------------------------------------------------------------------------

	# show apache modules
	if [[ -n $ShowApacheModules ]]; then
		printf "$LYellow apache module list: $Reset\n\n"
		show_apache_modules
	fi

#------------------------------------------------------------------------------------------------------------

	# show php configuration
	if [[ -n $ShowPHPConfiguration ]]; then
		printf "$LYellow current PHP configuration: $Reset\n"
		show_php_version
	fi

#------------------------------------------------------------------------------------------------------------
# TODO available version mit installed version abgleichen und mit einer option ausgeben 
	# show available php versions
	if [[ -n $ShowAvailablePHPVersion ]]; then
		printf "$LYellow available php versions: $Reset\n"
		show_available_PHP_Versions
	fi

#------------------------------------------------------------------------------------------------------------
# TODO available version mit installed version abgleichen und mit einer option ausgeben 
	# show installed php versions
	if [[ -n $ShowInstalledPHPVersion ]]; then
		printf "$LYellow installed php versions: $Reset\n"
		show_installed_PHP_Versions
	fi

#------------------------------------------------------------------------------------------------------------

	# change php version
	if [[ -n $ChangePHPVersion ]]; then
		printf "$LYellow change php service version ... $Reset\n\n"
		change_php_version
	fi

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################



