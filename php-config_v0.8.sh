#!/bin/bash
# name          : ap-config
# desciption    : apache PHP configure script
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 0.8
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
		ShowPHPVersions;-spv
		ShowPHPConfiguration;-spc
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

	# sed parser '\033[1;31m' => '\\033[1;31m'
	if [[ $1 == sed ]]; then
		eval $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='" | sed 's|\\|\\\\|g')
	fi

	# unset color codes
	if [[ $1 == "-u" ]]; then
		eval $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='" | sed 's/=.*/=/')
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
	printf " -sa  (e|d)   	=> show apache modules (Enabled|Disabled) \n"
	printf " -spv (i|n)   	=> show PHP versions (Installed|Not installed) \n"
	printf " -spc		=> show PHP configuration \n"
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
			apt update
			apt install -y $MissingPackets
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
	cp -r /etc/php* $PHP_BackupDir
	dpkg -l | grep ^ii | grep php | awk -F " " '{print $2}' >  $PHP_BackupDir/PHP_packages_installed.lst

	echo -en "\n\n  available mods:\n\n$ApacheModsAvailable\n"		>  $PHP_BackupDir/apache_modules
	echo -en "\n\n  active mods:\n\n$ApacheModsActive\n"			>> $PHP_BackupDir/apache_modules
}

#------------------------------------------------------------------------------------------------------------
install_php_repo () {

	wget https://packages.sury.org/php/apt.gpg -O /etc/apt/trusted.gpg.d/php-sury.gpg
	echo "$PHP_Repository" | tee /etc/apt/sources.list.d/php-sury.list
	apt update
}
#------------------------------------------------------------------------------------------------------------
show_php_version_instaled () {

	PHPVersionsAvailable=$(apt-cache search php | grep -w "^php[[:digit:]].[[:digit:]] " | cut -d "-" -f1  | sed 's/php//' | sort)
	PHPVersionsInstalled=$(dpkg -l | grep ^ii  | awk -F " " '{print $2}' | grep -w "^php[[:digit:]].[[:digit:]]$" | sed 's/php//' | sort)

	PHPVersionsListParsed=$(for i in $PHPVersionsAvailable ; do 
				if [[ -n $(grep -w $i <<< "$PHPVersionsInstalled" ) ]]; then
					printf "$LGreen     installed:  $i $Reset\n"
				else
					printf "$LRed not installed:  $i $Reset\n"
				fi
	
			      done )

	PHPVersionsListFiltered=$(
				if   [[ $1 == "-spv" ]]; then
					echo "$PHPVersionsListParsed"
				elif [[ $1 == "-spv i" ]]; then
					echo "$PHPVersionsListParsed" | grep -v "not installed"
				elif [[ $1 == "-spv n" ]]; then
					echo "$PHPVersionsListParsed" | grep -w "not installed"
				else 
					usage "invalid input: $ShowPHPVersions"		
				fi
				)

	if [[ -n $Monochrome ]]; then
		printf "$PHPVersionsListFiltered" | sed 's/^/ /'
	else
		printf "$PHPVersionsListFiltered" | sed 's/ .*installed://'
	fi

	printf "\n\n"
}
#------------------------------------------------------------------------------------------------------------
show_apache_modules () {

	ApacheModsAvailable=$(ls /etc/apache2/mods-available/ 2> /dev/null | sed 's/.conf//;s/.load//' | uniq)
	ApacheModsActive=$(ls /etc/apache2/mods-enabled/ 2> /dev/null | sed 's/.conf//;s/.load//' | uniq)

	ApacheModListParsed=$(for i in $ApacheModsAvailable ; do 
				if [[ -n $(grep -w $i <<< "$ApacheModsActive" ) ]]; then
					printf "$LGreen   active:  $i $Reset\n"
				else
					printf "$LRed inactive:  $i $Reset\n"
				fi
	
			      done)

	ApacheModListFiltered=$(
				if   [[ $1 == "-sa" ]]; then
					echo "$ApacheModListParsed"
				elif [[ $1 == "-sa e" ]]; then
					echo "$ApacheModListParsed" | grep -w "active:"
				elif [[ $1 == "-sa d" ]]; then
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
show_php_version_active () {

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

	# create menu
	MenuList=$(echo "$(show_php_version_active && echo -en " all\n cancel" )" | nl )
 	MenuListCount=$(($(grep -c . <<<$MenuList)-1))

	# select php service
	printf "$MenuList\n\n"
	read -e -p " select PHP service: "	-i "$MenuListCount" 		PHPSelection

	# get selected string
	SelectedPHPService=$(echo "$MenuList" | sed 's/^[[:space:]]*//' | grep "^$PHPSelection" | sed 's/[[:digit:]]*[[:space:]]*//')

	# check input selection
	if   [[ -z $SelectedPHPService ]]; then
		change_php_version
	elif [[ $SelectedPHPService == cancel ]]; then
		printf " exit ... \n"
		exit 0
	fi

	# select PHP version
	PHPVersionSelector

	# get active versions
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for i in $(show_php_version_active 2>/dev/null | sed 's/ &//') ; do
		eval $(echo $i | awk -F " " '{print $3,$4}' | sed 's/: /=/' | cut -d "." -f1-2)
	done
	IFS=$SAVEIFS
	printf "\n\n"

	# process input selection
	if   [[ -n $( grep -w "CLI:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for CLI service to ($CLI > $SelectedPHPVersion) ... $Reset\n"
		WritePHPConfigCLI

	elif [[ -n $( grep -w "CGI:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for CGI service ( $CGI > $SelectedPHPVersion) ... $Reset\n"
		WritePHPConfigCGI

	elif [[ -n $( grep -w "FPM:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for FPM service ($FPM > $SelectedPHPVersion) ... $Reset\n"
		WritePHPConfigFPM

	elif [[ -n $( grep -w "Apache:" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for apache service ($Apache > $SelectedPHPVersion) ... $Reset\n"
		WritePHPConfigApache

	elif [[ -n $( grep -w "all" <<< $SelectedPHPService) ]]; then
		printf "$LYellow change PHP version for all services ( X.X > $SelectedPHPVersion) ... $Reset\n"
		WritePHPConfigCLI
		WritePHPConfigCGI
		WritePHPConfigFPM
		WritePHPConfigApache
	else
		usage "PHP selection error"
	fi

	printf "\n"
	show_php_version_active
}
#------------------------------------------------------------------------------------------------------------
PHPVersionSelector () {

	# create menu
	Monochrome=true 
	load_color_codes -u
	MenuList=$(echo -en "$(show_php_version_instaled "-spv i" | sed 's/^.*:  //')" "\ncancel" | nl)
 	MenuListCount=$(grep -c . <<<$MenuList)
	Monochrome= 
	load_color_codes

	# php service selection
	printf "$MenuList\n\n"
	read -e -p " select PHP version: "	-i "$MenuListCount" 		PHPVersionSelection

	# get selected string
	SelectedPHPVersion=$(echo "$MenuList" | sed 's/^[[:space:]]*//' | grep "^$PHPVersionSelection" | sed 's/[[:digit:]].[[:space:]]*//')

	# check input selection
	if   [[ -z $SelectedPHPVersion ]]; then
		PHPVersionSelector
	elif [[ $SelectedPHPVersion == cancel ]]; then
		printf " exit ... \n"
		exit 0
	fi
}
#------------------------------------------------------------------------------------------------------------
WritePHPConfigCLI () {
	update-alternatives --set php /usr/bin/php$SelectedPHPVersion 
	update-alternatives --set phar /usr/bin/php$SelectedPHPVersion 
	update-alternatives --set phar.phar /usr/bin/phar.phar$SelectedPHPVersion 
}
#------------------------------------------------------------------------------------------------------------
WritePHPConfigCGI () {	# TODO ERROR
	update-alternatives --set php /usr/bin/php-cgi$SelectedPHPVersion 
}
#------------------------------------------------------------------------------------------------------------
WritePHPConfigFPM () {
echo #TODO
}

#------------------------------------------------------------------------------------------------------------	
WritePHPConfigApache () {	

	# enable PHP version for apache webserver | disable other versions to avoid conflics
	Monochrome= 
	load_color_codes -u
	PHPVersionApacheAvailable=$(show_apache_modules "-sa" | grep " php[[:digit:]].[[:digit:]] " | tr -d "\n" | sed 's/  / /g')
	PHPVersionApacheEnabled=$(show_apache_modules "-sa e" | grep " php[[:digit:]].[[:digit:]] " | tr -d "\n" | sed 's/  / /g')

	load_color_codes
	printf "$LYellow enable apache module: php$SelectedPHPVersion $Reset \n"
	load_color_codes -u
	a2dismod $PHPVersionApacheEnabled &> /dev/null
	a2enmod php$SelectedPHPVersion &> /dev/null

	load_color_codes
	printf "$LYellow restart apache webserver $Reset \n"
	systemctl restart apache2

	printf "$LYellow enabled php version for apache: $Reset"
	show_apache_modules "-sa e" | grep " php[[:digit:]].[[:digit:]] " 
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

	# check for root permission
	if [ "$(whoami)" = "root" ]; then echo "";else printf "$LRed Are You Root ?\n";exit 1;fi

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
		printf "$LYellow apache module list: $Reset\n"
		show_apache_modules "$ShowApacheModules"
	fi

#------------------------------------------------------------------------------------------------------------

	# show installed php versions
	if [[ -n $ShowPHPVersions ]]; then
		printf "$LYellow php versions: $Reset\n"
		show_php_version_instaled "$ShowPHPVersions"
	fi

#------------------------------------------------------------------------------------------------------------

	# show actual php configuration
	if [[ -n $ShowPHPConfiguration ]]; then
		printf "$LYellow current PHP configuration: $Reset\n"
		show_php_version_active
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

#TODO mask unused fpm services
#TODO change php-cgi version from terminal update-alternatives does not work

## unmask systemctl service files and start service
#if [[ -n $(service php8.2-fpm start 2>&1 | grep masked) ]]; then
#	printf " unmasking php8.2-fpm: "
#	systemctl unmask  php8.2-fpm
#	service php8.2-fpm start 
#fi
