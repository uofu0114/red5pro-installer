#!/bin/bash
## --


alias cls='printf "\033c"'

OS_UBUNTU="Ubuntu"
OS_CENTOS="CentOs"
DEFAULT_RPRO_PATH=/usr/local/red5pro
SERVICE_LOCATION=/etc/init.d
SERVICE_NAME=red5pro 
SERVICE_INSTALLER=/usr/sbin/update-rc.d
MIN_JAVA_VERSION="1.8"
IS_64_BIT=0
OS_NAME=
OS_VERSION=
MODE=0




######################################################################################

############################ MISC ----- METHODS ######################################




pause()
{

	printf "\n"
	read -r -p 'Press any [ Enter ] key to continue...' key

	echo $MODE

	if [ "$MODE" -eq  1 ]; then
 	show_advance_menu
	else
 	show_simple_menu
	fi
}




pause_license()
{

	printf "\n"
	read -r -p 'Press any [ Enter ] key to continue...' key

	show_licence_menu
}



empty_pause()
{
	printf "\n"
	read -r -p 'Press any [ Enter ] key to continue...' key
}




######################################################################################

############################ MISC TOOL INSTALLS ######################################



check_java()
{
	java_check_success=0
	has_min_java_version=0

	for JAVA in "${JAVA_HOME}/bin/java" "${JAVA_HOME}/Home/bin/java" "/usr/bin/java" "/usr/local/bin/java"
		do
			if [ -x "$JAVA" ]
			then
			break
		fi
	done


	if [ ! -x "$JAVA" ]; then
	  	echo "Unable to locate Java. If you think you do have java installed, please set JAVA_HOME environment variable to point to your JDK / JRE."
	else
		JAVA_VER=$(java -version 2>&1 | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')

		JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')

		echo "Current java version is $JAVA_VERSION"
		JAVA_VERSION_MAJOR=`echo "${JAVA_VERSION:0:3}"`

		if (( $(echo "$JAVA_VERSION_MAJOR < $MIN_JAVA_VERSION" |bc -l) )); then
			has_min_java_version=0			
			echo "You need to install a newer java version of java!"			
		else
			has_min_java_version=1
			echo "Minimum java version is already installed!"
		fi
	fi

}



check_unzip()
{
	unzip_check_success=0

	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' unzip|grep "install ok installed")

	if [ -z "$PKG_OK" ]; then
	unzip_check_success=0
	echo "Unzip utility not found."
	else
	unzip_check_success=1
	echo "Unzip utility was found"		
	fi
}



install_java()
{
	java_install_success=0

	echo "Installing JRE 8 for Ubuntu";
		
	add-apt-repository ppa:webupd8team/java
	apt-get update

	apt-get install oracle-java8-installer

	check_java

	has_min_java_version=1

	if [ $has_min_java_version -eq 1 ]; then
		default_jre="$(which java)";
		echo "JRE   successfully installed at $default_jre"
		java_install_success=1
	else
		echo "Could not install required version of java"
	fi
		
}



install_unzip()
{
	apt-get update
	apt-get install unzip

	install_unzip="$(which unzip)";
	echo "Unzip installed at $install_unzip"
}





add_update_java()
{
	install_java
}





######################################################################################

############################ RED5PRO OPERATIONS ######################################




download_latest()
{
	clear

	latest_rpro_download_success=0
	rpro_zip=

	echo "Downloading latest Red5pro from red5pro.com"
	
	# create tmp directory
	dir=`sudo mktemp -d` && cd $dir

	cd $dir

	# echo $dir
	rpro_form_valid=1
	echo "Please enter your red5pro.com login details"
	
	echo "Enter Email : "
	read rpro_email

	echo "Enter Password : "
	# read rpro_passcode
	read -s rpro_passcode

	# simple validate email
	if echo "${rpro_email}" | grep '^[a-zA-Z0-9]*@[a-zA-Z0-9]*\.[a-zA-Z0-9]*$' >/dev/null; then
	    	# NO OP
		echo "Email string ok!"		
	else
		rpro_form_valid=0
		echo "Invalid email string!"		
	fi
	
	# simple validate password
	if [ ! -z "$rpro_passcode" -a "$rpro_passcode" != " " ]; then
		echo "Password string ok!"		
	else
		rpro_form_valid=0
		echo "Invalid password string!"
	fi


	# if all params are valid
	if [ "$rpro_form_valid" -eq "1" ]; then
		# POST to site
		wget --server-response --save-cookies cookies.txt --keep-session-cookies --post-data="email=$rpro_email&password=$rpro_passcode" "https://account.red5pro.com/login" 2>$dir/wsession.txt
		wget_status=$(< $dir/wsession.txt)

		# Check http code
		wget_status_ok=0
		if [[ $wget_status == *"HTTP/1.1 200"* ]] 
		then
			wget_status_ok=1
		fi
		
		# if 200 then proceed
		if [ "$wget_status_ok" -eq "1" ]; then

			wget --load-cookies cookies.txt --content-disposition -p  https://account.red5pro.com/download/red5
			search_dir="$dir/account.red5pro.com/download"
			for file in $search_dir/*.zip
			do
				rpro_zip="${file%%.zip}"
				latest_rpro_download_success=1
				rpro_zip="${rpro_zip}.zip"
				break	
			done
		else
			echo "Failed to authenticate with website!"
		fi
		
	else
		echo "Invalid HTTP request parameters"
	fi
}






auto_install_rpro()
{
	# Install prerequisites
	prerequisites

	# Checking java
	echo "Checking java requirements"
	sleep 2
	check_java

	
	if [ "$has_min_java_version" -eq 0 ]; then
		echo "Installing latest java runtime environment..."
		sleep 2

		install_java
	fi 


	# Download red5 zip from red5pro.com
	echo "Preparing to install Red5Pro from Red5pro.com"
	sleep 2
	download_latest

	if [ "$latest_rpro_download_success" -eq 0 ]; then
		echo "Failed to download latest Red5pro distribution from Red5pro.com. Please contact support!"
		pause
	fi


	if [ -z "$rpro_zip" ]; then
		echo "Downloaded file could not be found or is invalid. Exiting now!"
		pause
	fi


	# Installing red5 from zip downloaded  from red5pro.com

	echo "Installing Red5Pro"
	sleep 2
	install_rpro_zip $rpro_zip

	if [ "$red5_zip_install_success" -eq 0 ]; then
		echo "Failed to install Red5pro distribution. Something went wrong!! Try again or contact support!"
		pause
	fi
	
}





register_rpro_as_service()
{
	check_current_rpro 1

	if [ "$rpro_exists" -eq 1 ]; then


		if [ -f "$SERVICE_LOCATION/$SERVICE_NAME" ]; then
		echo "Service already exists. Do you wish to re-install ?" 
		read -r -p "Are you sure? [y/N] " response

		case $response in
		[yY][eE][sS]|[yY]) 
		register_rpro_service
		;;
		*)
		echo "Install cancelled"
		;;
		esac

		else
		register_rpro_service
		fi
	fi

	pause
}



unregister_rpro_as_service()
{
	check_current_rpro 0

	if [ "$rpro_exists" -eq 1 ]; then

		if [ ! -f "$SERVICE_LOCATION/$SERVICE_NAME" ]; then
			echo "Service does not exists. Nothing to remove" 
		else
			unregister_rpro_service
		fi

	fi

	pause
}





install_rpro_zip()
{
	red5_zip_install_success=0

			
	clear
	echo "Installing red5pro from zip"

	if [ $# -eq 0 ]; then
		echo "Enter the full path to Red5pro zip"
		read rpro_zip_path
	else 
		rpro_zip_path=$1
	fi
	

	if [ ! -f "$rpro_zip_path" ]; then
		echo "Invalid archive file path $rpro_zip_path"
		pause;
	fi


	filename=$(basename "$rpro_zip_path")
	extension="${filename##*.}"
	filename="${filename%.*}"


	case "$extension" in 
	zip|tar|gz*) 
	    # All ok
	    ;;	
	*)
	    echo "Invalid archive type $extension"
	    pause
	    ;;
	esac
	


	echo "Attempting to install red5pro from zip"
	dir=`mktemp -d` && cd $dir
	unzip_dest="$dir/$filename"


	check_current_rpro 1
	
	if [ "$rpro_exists" -eq 1 ]; then
	
		echo "Seems like an existing Red5pro installation was found. If you continue this will be replaced"
		sleep 1
		echo "Warning! All file(s) and folder(s) at $DEFAULT_RPRO_PATH will be removed permanently"
		read -r -p "Are you sure? [y/N] " response

		case $response in
		[yY][eE][sS]|[yY]) 
		# remove rpro service
		unregister_rpro_service
		# check remove folder
		rm -rf $DEFAULT_RPRO_PATH
		;;
		*)
		echo "Uninstall cancelled"
		pause
		;;
		esac
	fi


		
	echo "Unpacking archive to install location -------"
	
	if ! unzip $rpro_zip_path -d $unzip_dest; then
		echo "Failed to extract zip. Possible invalid archive"
		pause;
	fi


	if [ ! -d "$unzip_dest" ]; then
		echo "Could not create output directory."
		pause;
	fi


	# Move to actual install location 
	rpro_loc=$DEFAULT_RPRO_PATH
	mv -v $unzip_dest/* $rpro_loc

	# DEFAULT_RPRO_PATH=/usr/local/red5pro

	echo "Setting permissions -----------"
	sleep 1

	chmod 755 $rpro_loc
	
	chmod +x $rpro_loc/red5.sh

	chmod +x $rpro_loc/red5-shutdown.sh


	# set path
	echo "Setting RED5_HOME"
	sleep 1
	export RED5_HOME=$rpro
 

	# clear tmp directories - IMPORTANT
	echo "cleaning up ----"
	sleep 1

	rm -rf $dir
	rm -rf $unzip_dest

	sleep 1	

	if [ ! -d "$rpro_loc" ]; then
		echo "Could not install Red5pro at $rpro_loc"
	else
		echo "All done! ----"
		echo "Red5pro installed at  $rpro_loc"
		red5_zip_install_success=1
	fi


	# Installing red5 service
	echo "For Red5pro to autostart with operating system, it needs to be registered as a service"
	read -r -p "Do you want to register Red5pro service now? [y/N] " response

	case $response in
	[yY][eE][sS]|[yY]) 
		
		echo "Registering Red5pro as a service"
		sleep 2
		register_rpro_service
		
		if [ "$rpro_service_install_success" -eq 0 ]; then
		echo "Failed to register Red5pro service. Something went wrong!! Try again or contact support!"
		pause
		fi
	;;
	*)
	;;
	esac

	
	# All Done
	echo "Red5pro service is now installed on your system. You can start / stop it with from the menu".
	pause;
	

}





register_rpro_service()
{

	rpro_service_install_success=0

	echo "Preparing to install service..."
	sleep 2


#######################################################

service_script="#!/bin/sh
### BEGIN INIT INFO
# chkconfig: 2345 85 85
# description: Red5 Pro streaming server
# Provides:          Red5 Pro
# Required-Start:    \$local_fs \$network
# Required-Stop:     \$local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Red5Pro
# processname: red5
### END INIT INFO

PROG=red5
RED5_HOME=/usr/local/red5pro 
DAEMON=\$RED5_HOME/\$PROG.sh
PIDFILE=/var/run/\$PROG.pid

start() {
  echo \"Starting Red5pro..\"
  # check to see if the server is already running
  if netstat -an | grep ':5080' > /dev/null 2>&1 ; then
    echo \"Red5 is already started...\"
    while netstat -an | grep ':5080' > /dev/null 2>&1 ; do
      # wait 5 seconds and test again
      sleep 5
    done
  fi
  cd \${RED5_HOME} && ./red5.sh > /dev/null 2>&1 &
}

stop() {
  cd \${RED5_HOME} && ./red5-shutdown.sh > /dev/null 2>&1 &
  echo \"Shutting down Red5pro... It may take upto 30 seconds for shutdown to complete...\"
}


case \"\$1\" in
  start)
    start
    exit 1
  ;;
  stop)
    stop
    exit 1
  ;;
  restart)
    stop
    start
    exit 1
  ;;
  **)
    echo \"Usage: \$0 {start|stop|restart}\" 1>&2
    exit 1
  ;;

esac"

#######################################################

	echo "Writing service script"
	sleep 1

	touch $SERVICE_LOCATION/$SERVICE_NAME

	# write script to file
	echo "$service_script" > /etc/init.d/red5pro

	# make service file executable
	chmod +x $SERVICE_LOCATION/$SERVICE_NAME


	echo "Registering service \"$SERVICE_NAME\""
	sleep 1

	$SERVICE_INSTALLER $SERVICE_NAME -f defaults

	echo "Enabling service \"$SERVICE_NAME\""
	sleep 1

	$SERVICE_INSTALLER $SERVICE_NAME enable


	echo "Red5Pro service installed successfully!"
	rpro_service_install_success=1
}





unregister_rpro_service()
{
	rpro_service_remove_success=0
	
	prog="red5"

	echo "Preparing to remove service..."
	sleep 2


	if [ -f "$SERVICE_LOCATION/$SERVICE_NAME" ];	then
	

		# 1. Terminate service if running

		# 2. check PID file and check pid
		

		echo "Disabling service \"$SERVICE_NAME\""
		sleep 1

		update-rc.d $SERVICE_NAME disable

		echo "Removing service \"$SERVICE_NAME\""
		sleep 1

		update-rc.d $SERVICE_NAME remove

		rm $SERVICE_LOCATION/$SERVICE_NAME

		echo "Service removed successfully"
		rpro_service_remove_success=0
	
	else
		echo "Red5pro service was not found"
	fi
}






start_red5pro_service()
{

	if [ ! -f "$SERVICE_LOCATION/$SERVICE_NAME" ];	then
		echo "It seems Red5Pro service was not installed. Please register Red5pro service from the menu for best results."
		echo " Attempting to start using \"red5.sh\""
		exec $DEFAULT_RPRO_PATH/red5.sh &
	else
		echo "Red5Pro service was found at $SERVICE_LOCATION/$SERVICE_NAME"
		echo " Attempting to start service"
		"$SERVICE_LOCATION/$SERVICE_NAME" start /dev/null 2>&1 &
	fi

	pause
}




# needs repair

stop_red5pro_service()
{
	$proc="red5"

	if [ ! -f "$SERVICE_LOCATION/$SERVICE_NAME" ];	then
		echo "It seems Red5Pro service was not installed. Please register Red5pro service from the menu for best results."
		echo " Attempting to start using \"red5-shutdown.sh\""

		exec $DEFAULT_RPRO_PATH/red5-shutdown.sh /dev/null 2>&1 &
	else
		echo "Red5Pro service was found at $SERVICE_LOCATION/$SERVICE_NAME."
		echo " Attempting to stop service"

		"$SERVICE_LOCATION/$SERVICE_NAME" stop /dev/null 2>&1 &
	fi

	if [ $# -eq 0 ]
	  then
	    pause
	fi
}




is_red5_running()
{	
	pid_info=`pgrep -f red5`
	echo $pid_info
}





remove_rpro_installation()
{
	echo "Looking for Red5Pro at default location..."
	sleep 2

	if [ ! -d $DEFAULT_RPRO_PATH ]; then
  		echo "No Red5pro installation found at default location : $DEFAULT_RPRO_PATH"
	else
		red5pro_ini="$DEFAULT_RPRO_PATH/conf/red5.ini" 

		if [ ! -f $red5pro_ini ]; then
		echo "There were files found at default location : $DEFAULT_RPRO_PATH, but the installation might be broken !. I could not locate version information"
		else
		echo "Red5pro installation found at default location : $DEFAULT_RPRO_PATH"
		echo "Warning! All file(s) and folder(s) at $DEFAULT_RPRO_PATH will be removed permanently"
		read -r -p "Are you sure? [y/N] " response

		case $response in
		[yY][eE][sS]|[yY]) 
		# remove rpro service
		unregister_rpro_service
		# check remove folder
		rm -rf $DEFAULT_RPRO_PATH
		unset RED5_HOME
		if [ ! -d "$DEFAULT_RPRO_PATH" ]; then
			echo "Red5 installation was removed"
		fi
		;;
		*)
		echo "Uninstall cancelled"
		;;
		esac
		fi
	fi


	if [ $# -eq 0 ]; then
		pause		
	fi

	
}





check_current_rpro()
{
	rpro_exists=0
	echo "Looking for Red5Pro at default location..."
	sleep 2

	if [ ! -d $DEFAULT_RPRO_PATH ]; then
  		echo "No Red5pro installation found at default location : $DEFAULT_RPRO_PATH"
	else
		red5pro_ini="$DEFAULT_RPRO_PATH/conf/red5.ini" 

		if [ ! -f $red5pro_ini ]; then
		echo "There were files found at default location : $DEFAULT_RPRO_PATH, but the installation might be broken !. I could not locate version information"
		rpro_exists=1
		else
		rpro_exists=1
		echo "Red5pro installation found at default location : $DEFAULT_RPRO_PATH"

		pattern='server.version*'
		replace=""
		while IFS= read line
		do
			case "$line" in
			$pattern) echo "Red5pro build info :" $line | sed -e "s/server.version=/${replace}/g";;
			*) continue ;;
			esac
		
		done <"$red5pro_ini"

		fi
	fi

	if [ $# -eq 0 ]; then
		pause		
	fi
}



######################################################################################

####################### RED5PRO UPGRADE OPERATION MENU ###############################

## PRIVATE ###
backup_rpro()
{
	rpro_backup_success=0
	USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
	RPRO_BACKUP_HOME="$USER_HOME/red5pro_backups"
echo $RPRO_BACKUP_HOME

	if [ ! -d "$RPRO_BACKUP_HOME" ]; then
	  mkdir -p $RPRO_BACKUP_HOME
	fi

	
	if [ -d "$RPRO_BACKUP_HOME" ]; then
	  
		echo "Starting backup procedure..."
		sleep 2

		# echo "Stopping Red5pro if it was running..."
		stop_red5pro_service 1
		sleep 10

		echo "Backing up... "
		sleep 5

		# Create backup folder
		t_now=`date +%Y-%m-%d-%H-%M-%S`
		RPRO_BACKUP_FOLDER="$RPRO_BACKUP_HOME/$t_now"

		# Copy all files to backup folder
		cp -R $DEFAULT_RPRO_PATH $RPRO_BACKUP_FOLDER
		sleep 2

		# Show notice to user that back up was saved
		if [ -d "$RPRO_BACKUP_FOLDER" ]; then
			if [ ! -f $red5pro_ini ]; then
				echo "Your active red5pro installation was backed up successfully to $RPRO_BACKUP_FOLDER"
				echo "After upgrade completes, you can any restore necessary file(s) manually from there"
				empty_pause
			else
				echo "Something went wrong!! Perhaps files were not copied properly"
			fi
		else
			echo "WARNING! Could not create backup destination directory"
		fi


		rpro_backup_success=1

		echo "Backup completed!"
		empty_pause

	else
		echo "Failed to create backup directory. Backup will be skipped..."

	fi

	
}





upgrade()
{
	upgrade_rpro_success=0

	# Determine upgrade type
	upgrade_from_zip=0

	if [ $# -eq 1 ]; then
		upgrade_from_zip=1
	else
		upgrade_from_zip=0		
	fi


	# Start process
	echo "Initializing upgrade process..."
	sleep 2

	check_current_rpro 1

	if [ "$rpro_exists" -eq "1" ]; then
		echo "It is recommended that you make a backup of your old server files. "
		read -r -p "Do you wish to create a backup now? [y/N] " response

		case $response in
		[yY][eE][sS]|[yY]) 
		
		# backup red5pro
		backup_rpro

		if [ $rpro_backup_success -eq 1 ]; then
			echo "Preparing to install red5pro"
			# proceed to install new red5pro 
			if [ $upgrade_from_zip -eq 1 ]; then
			install_rpro_zip
			else
			auto_install_rpro
			fi
		else
			echo "Failed to create a backup of your existing red5pro installation"
			upgrade_clean $upgrade_from_zip
			# check install state here
			pause
		fi
		;;
		*)
		echo "Upgrade cancelled"
		;;
		esac
	else
		upgrade_clean $upgrade_from_zip
		# check install state here
	fi

	pause

}





## PRIVATE ###
upgrade_clean()
{
	# Determine upgrade type
	upgrade_from_zip=0

	if [ $# -eq 1 ]; then
		upgrade_from_zip=1
	else
		upgrade_from_zip=0		
	fi

	read -r -p "Do you wish to proceed with a clean installation? [y/N] " response

	case $response in
	[yY][eE][sS]|[yY]) 
	if [ $upgrade_from_zip -eq 1 ]; then
	install_rpro_zip
	else
	auto_install_rpro
	fi
	;;
	*)
	echo "Upgrade cancelled"
	;;
	esac
}



######################################################################################

############################ LICENSE OPERATIONS ######################################




check_license()
{
	if [ $1 -eq 1]; then
		echo "Enter the full path to Red5pro installation"
		read rpro_path
	else
		rpro_path=$DEFAULT_RPRO_PATH
	fi



	lic_file=$rpro_path/LICENSE.KEY

	if [ ! -f $lic_file ]; then
  		echo "No license file found!. Please install a license."
	else
		value=`cat $lic_file`
		echo "Current license : $value"
	fi
	
	pause_license;	
}




set_update_license()
{

	if [ $1 -eq 1 ]; then
		echo "Enter the full path to Red5pro installation"
		read rpro_path
	else
		rpro_path=$DEFAULT_RPRO_PATH
	fi
	

	lic_file=$rpro_path/LICENSE.KEY
	lic_new=1

	if [ ! -f $lic_file ]; then
  		echo "Installing license code : Please enter new license code and press [ Enter ]."
		if [ ! -f "$lic_file" ] ; then
         		# if not create the file
         		touch "$lic_file"
	     	fi
	else
		lic_new=0
		cat $lic_file | while read line
		do
		echo "a line: $line"
		done
		echo "Updating license : Please enter new license code and press [ Enter ]."
	fi

	read license_code

	license_code=$(echo $license_code | tr '[a-z]' '[A-Z]')
	printf $license_code > $lic_file;

	if [ $lic_new -eq 1 ]; then
	echo "license installed"
	else
	echo "License updated"
	fi
	
	pause_license;	
}






######################################################################################

############################ LICENSE MENU ############################################




show_licence_menu()
{
	licence_menu
	license_menu_read_options
}



licence_menu()
{
	printf "\033c"

	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"	
	echo " ----------- MANAGE LICENSE ------------- "
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "1. ADD / UPDATE LICENSE"
	echo "2. VIEW LICENSE"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "3. BACK TO MAIN MENU"
	echo "			  "   
}





license_menu_read_options(){
	local choice
	read -p "Enter choice [ 1 - 3] " choice
	case $choice in
		1) set_update_license 0 ;;
		2) check_license 0 ;;
		3) 
		if [ $MODE -eq  1]; then 
		show_advance_menu 
		else 
		show_simple_menu 
		fi 
		;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}




######################################################################################

############################ ADVANCE OPERATION MENU ################################



show_advance_menu()
{
	advance_menu
	advance_menu_read_options
}


advance_menu()
{

	printf "\033c"

	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "-------------- ADVANCE MODE --------------"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "1. WHICH JAVA AM I USING ?"
	echo "2. ADD / UPDATE JAVA"
	echo "3. INSTALL RED5PRO SERVICE"
	echo "4. UNINSTALL RED5PRO SERVICE"
	echo "5. UPGRADE RED5PRO FROM ZIP"
	echo "6. UPGRADE RED5PRO FROM LATEST"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "7. BACK TO MODE SELECTION"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "0. Exit"
	echo "                             "

}





advance_menu_read_options(){
	local choice
	read -p "Enter choice [ 1 - 7 | 0 to exit]] " choice
	case $choice in
		1) check_java 1 ;;
		2) add_update_java ;;
		3) register_rpro_as_service ;;
		4) unregister_rpro_as_service ;;
		5) upgrade 1 ;;
		6) upgrade ;;
		7) main ;;
		0) exit 0;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}







######################################################################################

############################ SIMPLE OPERATION MENU ################################





show_simple_menu()
{
	simple_menu
	simple_menu_read_options
}





simple_menu()
{

	printf "\033c"

	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"	
	echo " RED5PRO SUPER UTILS - BASIC MODE         "
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "1. CHECK EXISTING RED5PRO INSTALLATION"
	echo "2. INSTALL LATEST RED5PRO"
	echo "3. INSTALL RED5PRO FROM ZIP"
	echo "4. REMOVE RED5PRO INSTALLATION"
	echo "5. ADD / UPDATE RED5PRO LICENSE"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "------ RED5PRO SERVICE OPTIONS -----------"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "6. --- START RED5PRO"
	echo "7. --- STOP RED5PRO"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "8. BACK TO MODE SELECTION"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "0. Exit"
	echo "                             "

}








simple_menu_read_options(){
	local choice
	read -p "Enter choice [ 1 - 8 | 0 to exit] " choice
	case $choice in
		1) check_current_rpro ;;
		2) auto_install_rpro ;;
		3) install_rpro_zip ;;
		4) remove_rpro_installation ;;
		5) show_licence_menu ;;
		6) start_red5pro_service ;;
		7) stop_red5pro_service ;;
		8) main ;;
		0) exit 0;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}






######################################################################################

################################ INIT FUNCTIONS ######################################



detect_system()
{
	
	ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

	if [ -f /etc/lsb-release ]; then
	    . /etc/lsb-release
	    OS_NAME=$DISTRIB_ID
	    OS_VERSION=$DISTRIB_RELEASE
	elif [ -f /etc/debian_version ]; then
	    OS_NAME=Debian  # XXX or Ubuntu??
	    OS_VERSION=$(cat /etc/debian_version)
	elif [ -f /etc/redhat-release ]; then
	    # TODO add code for Red Hat and CentOS here
	    OS_VERSION=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
	    OS_NAME=$(rpm -q --qf "%{RELEASE}" $(rpm -q --whatprovides redhat-release))
	else
	    OS_NAME=$(uname -s)
	    OS_VERSION=$(uname -r)
	fi

	case $(uname -m) in
	x86_64)
	    ARCH=x64  # or AMD64 or Intel64 or whatever
	    IS_64_BIT=1
	    os_bits="64 Bit"
	    ;;
	i*86)
	    ARCH=x86  # or IA32 or Intel32 or whatever
	    IS_64_BIT=0
	    os_bits="32 Bit"
	    ;;
	*)
	    # leave ARCH as-is
	    ;;
	esac

	echo -e "* Linux Distribution: \e[36m$OS_NAME\e[m"
	echo -e "* Version: \e[36m$OS_VERSION\e[m"
	echo -e "* Kernel: \e[36m$os_bits\e[m"

}



simple_usage_mode()
{

	MODE=0

	simple_menu
	simple_menu_read_options
}




advance_usage_mode()
{
	MODE=1
	
	advance_menu
	advance_menu_read_options
}



welcome_menu()
{

	printf "\033c"


	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"	
	echo " RED5PRO UTILITIES - W E L C O M E   M E N U"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	detect_system

	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	echo "                             "
	echo "1. BASIC MODE (Recommended)"
	echo "                             "
	echo "2. ADVANCE MODE"
	echo "                             "
	echo "0. Exit"
	echo "                             "
}




read_welcome_menu_options()
{
	local choice
	read -p "Enter choice [ 1 - 2 | 0 to exit] " choice
	case $choice in
		1) simple_usage_mode ;;
		2) advance_usage_mode ;;
		0) exit 0;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}



main()
{
	welcome_menu
	read_welcome_menu_options
}



prerequisites()
{
	# Checking unzip
	echo "Checking for unzip"
	sleep 2
	
	check_unzip


	if [ "$unzip_check_success" -eq 0 ]; then
		echo "Installing unzip..."
		sleep 2

		install_unzip
	fi 
}




# Start application
main
