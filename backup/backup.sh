#!/bin/bash
# Backup Tool

#Define the colors of our script
#Making it more colorful
green='\e[32m'
blue='\e[34m'
clear='\e[0m'
red='\033[0;31m'
pink='\033[1;35m'
#CRON_FILE
CRON_FILE="/var/spool/cron/root"
MYCRON="autoBackup.sh"
#Color displayers

ColorGreen(){
	echo -ne $green$1$clear
}
ColorBlue(){
	echo -ne $blue$1$clear
}

#0 Helper functions
#Log function
writeToTheLog(){
	if [ "$optionPath" = "y" ] || [ "$optionPath" = "Y" ]; then
		echo -ne "$(date +'%d/%m/%Y     %H:%M')     $1\n" >> /backups/backup.log
	else
		echo -ne "$(date +'%d/%m/%Y     %H:%M')     $1\n" >> $HOME/backups/backup.log
	fi
}

#Check requirements
checkReq(){
	a=$(which getfacl)
	if [ -z $a ]; then
		echo -ne "Need to install package acl to work properly"
		sudo apt-get install acl
		writeToTheLog "ACL installed"
	fi
}


#Ask for permissions and make backup dir
askPerm(){
  echo -e "Do you want to make the backups in /backups? (y/n)"
  read optionPath
    if [ "$optionPath" = "y" ] || [ "$optionPath" = "Y" ]
    then
    #Ask the user for root
        if [ ! "$EUID" -eq 0 ]
        then
            echo "Running the program again as root ...";
            exec sudo -- "$0" "$@";
        else
            echo "Already running as root!"
        fi

				if [ ! -d "/backups" ]
				then
					mkdir /backups
					echo "Created directory /backups"
				fi

				if [ ! -f "/backups/backup.log" ]; then
					touch /backups/backup.log
					echo -ne "DATE           TIME      INSTRUCTION\n" >> /backups/backup.log
				fi

				echo "Making the backups in /backups"

				if [ ! -d "$HOME/backups" ]
				then
					mkdir $HOME/backups
					echo "Created directory $HOME/backups\n"
				fi
				if [ ! -f "$HOME/backups/backup.log" ]; then
					touch $HOME/backups/backup.log
					echo -ne "DATE           TIME      INSTRUCTION\n" >> $HOME/backups/backup.log
				fi

    else
        echo -e "Making the backup in$blue $HOME/backups"$clear
        if [ ! -d "$HOME/backups" ]
        then
        mkdir $HOME/backups
        else
        echo -ne "Path$blue $HOME/backups$clear alredy created \n"
        fi
    fi
}

#1- Make backup
makeBackup(){
 bckdate=$(date +'%Y%m%d-%H%M')
 nameOfFile="$(basename $path)-${bckdate}"
 if [ "$optionPath" = "y" ] || [ "$optionPath" = "Y" ]
	 then
	   echo -ne "Creating backup of file $nameOfFile in directory /backups \n"
		 getfacl -pR $1 > $path/permissions_backup
		 basePath=$(echo $path | cut -d '/' -f1-3)
		 getfacl -p $basePath >> $path/permissions_backup
	   tar -cvzf $nameOfFile.tgz $1
		 mv -vb $nameOfFile.tgz /backups/$nameOfFile.tgz
		 FILESIZE=$(stat -c%s "/backups/$nameOfFile.tgz")
		 writeToTheLog "Backup of $path made in /backup/$nameOfFile.tgz of size $FILESIZE"
		 rm -f $path/permissions_backup

	else
	   echo -ne "Creating backup of file $nameOfFile in directory $HOME/backups"
	   tar -cvzf $nameOfFile.tgz $1
		 mv -vb $nameOfFile.tgz $HOME/backups/$nameOfFile.tgz
		 FILESIZE=$(stat -c%s "$HOME/backups/$nameOfFile.tgz")
		 writeToTheLog "Backup of $path made in $HOME/backups/$nameOfFile.tgz of size $FILESIZE"
	 fi
}

#1.1-Function reading the input path
readPath(){
echo -ne "
Menu 1
Path of the directory: "
read path
if [ -d "$path" ]
then
  if [ -L "$path" ]
  then
    echo $red"Error: Directory $path exists but point to $(readlink -f $path)."$clear; readPath;
  fi
else
  echo -e $red"The directory $path does not exist"$clear; readPath;
fi
}

doOne(){
	readPath
	userConfAndBack1 $path
	makeBackup $path
}

#1.2-User confirmation
userConfAndBack1(){
echo -ne "We will do a backup of the directory: $1.
Do you want to proceed(y/n)?"
read confirm1
}

#2-Programed backup
askForRoot(){
	echo -ne $pink"Root permissions are needed for this functionality"$clear
	if [ ! "$EUID" -eq 0 ]
	then
			echo "Running the program again as root ...";
			writeToTheLog "Requesting root permissions"
			exec sudo -- "$0" "$@";
			writeToTheLog "Root permissions granted"
	fi
}

#Create the programmed task in cron
createTaskinCron(){
	#Ask for the hour and minutes in bash
	echo -ne "Introduce the hour and minutes in the following format HH:MM -> "
	read MyH
	echo $MyH
	if [[ $MyH =~ ^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$ ]]
	then
		echo -ne "Absolute path of the directory: $path\n"
		echo -ne "Hour for the backup $MyH\n"
		echo -ne "Creating task autoBackup.sh at $MyH\n"
		crontab -u root -l >/tmp/crontab
		cp ./$MYCRON /backups/$MYCRON
    echo "${MyH:3:2} ${MyH:0:2} * * * /bin/bash /backups/$MYCRON $path /backups" >> /tmp/crontab
	  crontab -u root /tmp/crontab
		writeToTheLog "Created automatic backup at $MyH of directory $path"
  else
		echo -ne $red"Wrong time format. Expected format HH:MM \n"$clear
		createTaskinCron $1
	fi
}

doTwo(){
	askForRoot
	readPath
	createTaskinCron $path

}

#3 - Restore funciton
displayBack(){
	echo -ne $pink"\n*************The list of backups*************\n"$clear
	echo -ne "Backups in directory$blue /backups $clear\n"
	ls -u /backups/*.tgz | xargs -n 1 basename
	echo -ne "\nBackups in directory$blue $HOME/backups $clear\n"
	ls -u $HOME/backups/*.tgz | xargs -n 1 basename
  echo -ne "\nChoose the directory where you want to restore from:
    1) For /backups
    2) For $HOME/backups
  ->"
	read resOpt
	echo -ne "\nChoose the file to restore:"
 	read resFile
}

restoreFilesPerm(){
	if [ -f "$1/$2" ]; then
		echo -ne "\nDecompressing $1/$2\n"
		tar -xvzf $1/$2 && \
		array=($(ls -du */)) && \
		backD=$(echo ${array[0]} | cut -d '/' -f 1)
		sudo rsync -av --exclude 'permissions_backup' --progress ./$backD / && \
		sudo setfacl --restore=$(find ./$backD -name "permissions_backup") && \
		sudo rm -rf ./$backD
		writeToTheLog "Restored backup $2 of directory $1"
	else
		echo -ne $red"File $2 not found"$clear
	fi

}

doThree(){
	displayBack
	case $resOpt in
		1) restoreFilesPerm /backups $resFile;;
		2) restoreFilesPerm $HOME/backups $resFile;;
		*) echo -e $red"\n\nWrong option.\n\n"$clear;;
	esac
}


#Menu Function
menu(){
echo -ne "
ASO 2021-2022
Sergio Valle Trillo

Backup tool for directories
---------------------------

Menu
  $(ColorGreen '1)') Perform a backup
  $(ColorGreen '2)') Program a backup with cron
  $(ColorGreen '3)') Restore the content of a bakcup
  $(ColorGreen '4)') Exit
  $(ColorBlue 'Choose an option:') "
        read a
        case $a in
	        1) doOne; menu ;;
	        2) doTwo; menu ;;
	        3) doThree ; menu ;;
	        4) exit 0 ;;
		*) echo -e $red"\n\nWrong option.\n\n"$clear; menu;;
        esac
}

#Call the menu function
checkReq
askPerm
menu
