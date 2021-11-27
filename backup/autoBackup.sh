#!bin/bash
bckdate=$(date +'%Y%m%d-%H%M')
name=$(basename $1)
nameOfFile="$name-${bckdate}"
echo -ne "Creating backup of file $nameOfFile in directory /backups \n"
tar -cvzf $nameOfFile.tgz $1
mv -vb $nameOfFile.tgz /backups/$nameOfFile.tgz
