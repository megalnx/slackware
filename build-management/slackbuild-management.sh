#!/bin/bash
# 
# Slackbuild's management script
#
# Copyright 2014-2015 William PC, Seattle, US.
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

SBO_MANAGEMENT_VERSION=0.9

# define where to build the packages 
# local or remote
BUILD_SYSTEM=local

source ~/slackbuilds.conf

# System compilation version
SLACKWARE_LOCAL_VERSION=$(cat /etc/slackware-version)

PACKAGE=${pulseaudio:-$2}

TMP=${TMP:-~/Public/SBo-slackbuilds/$SLACKWARE_VERSION}


#red='\033[0;31m'
#NC='\033[0m' # No Color
#echo -e "${red}Hello Stackoverflow${NC}"

if [ -z "$SBo_MIRROR" ]; then
  SBo_MIRROR="rsync://slackbuilds.org/slackbuilds"
  echo "No local mirror defined mirror,
        using $SBo_MIRROR"
  sleep 2
fi

if [ ! -d $TMP ]; then
  mkdir -p $TMP; cd $TMP
else
  cd $TMP
fi

echo "###############"###############
echo "# SBo management version: $SBO_MANAGEMENT_VERSION"
echo "# Slackware version: $SLACKWARE_VERSION"
echo "# /etc/slackware-version: $SLACKWARE_LOCAL_VERSION"
echo "###############"###############

function update_slackbuilds() {
  echo "### Updating Slackbuild's source"
  if [ ! -f $TMP/SLACKBUILDS.TXT.old ];then
     zcat $TMP/SLACKBUILDS.TXT.gz > $TMP/SLACKBUILDS.TXT.old
  fi
     rsync -auv $SBo_MIRROR/$SLACKWARE_VERSION/SLACKBUILDS.TXT.gz $TMP
     zcat $TMP/SLACKBUILDS.TXT.gz > $TMP/SLACKBUILDS.TXT.new

     NEWPKGS=$(diff $TMP/SLACKBUILDS.TXT.new $TMP/SLACKBUILDS.TXT.old | grep "SLACKBUILD NAME:" | awk '{print $( ( 4 ) )}')
     echo " ${#NEWPKGS[@]} new packages:"
     echo $NEWPKGS
}

function display_packages {
	searchfor=$1
	SEARCH=$(zgrep -i "$searchfor" SLACKBUILDS.TXT.gz | sed -n -e 's/SLACKBUILD NAME: //p')

	PKG_LIST=( $SEARCH )

	if [ ${#PKG_LIST[@]} == 0 ]; then
	  echo "No packages found for: $searchfor"
	  exit 0
	else
	  echo "Packages found for $searchfor: ${#PKG_LIST[@]}"
	fi

    	npkg=0;
	while [ $npkg -lt "${#PKG_LIST[@]}" ]
	do
    	    menu_list[$npkg]=" $npkg ${PKG_LIST[$npkg]} "
	    npkg=$(( $npkg + 1 ))
	done
	tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/sb_management-tmp$$
        dialog --backtitle "Slackbuilds for $SLACKWARE_VERSION" --menu "Choose a package:" 15 45 5 ${menu_list[@]} 2> $tempfile
	PACKAGE=$(cat $tempfile)

     	get_package ${PKG_LIST[$PACKAGE]}
}

function search_package() {
    searchfor="$1"

    if [ -z "$searchfor" ]; then
      echo "None search entry asked by user"
      exit
    fi

    DESCRIPTION=$(zgrep -i "$searchfor" SLACKBUILDS.TXT.gz | sed -n -e 's/^.*DESCRIPTION: //p')
    NAME=$(zgrep -i "$searchfor" SLACKBUILDS.TXT.gz | sed -n -e 's/^.*NAME: //p')
    NAME=( $NAME )

    if [ "${#NAME[@]}" == "1" ]; then
      echo "$(tput bold) $NAME $(tput sgr0) - $DESCRIPTION"
    elif [ "${#NAME[@]}" == "0" ]; then
      echo "No packages found for: $searchfor"
    else     
      display_packages $searchfor || exit 1
    fi

}

function info_package() {
    DESCRIPTION=$(zgrep -A 10 "SLACKBUILD NAME: $PACKAGE" SLACKBUILDS.TXT.gz | grep "DESCRIPTION:" | sed -n -e 's/^.*DESCRIPTION: //p')
    DOWNLOAD=$(zgrep -A 11 "SLACKBUILD NAME: $PACKAGE" SLACKBUILDS.TXT.gz | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')

    echo "$(tput bold) Description:"
    echo "$(tput sgr0) $DESCRIPTION"

    echo "$(tput bold) Download file(s):"
    for f in $DOWNLOAD
    do
	echo "$(tput sgr0)  $f"
    done
  
    echo "$(tput bold) Additional required package(s):"
    echo "$(tput sgr0) $(check_dependence)"

    tput sgr0
}

# Check for required packages
function check_dependence() {
  REQUIRES=$(zgrep -A 10 "SLACKBUILD NAME: $PACKAGE" SLACKBUILDS.TXT.gz | grep "SLACKBUILD REQUIRES:" | sed -n -e 's/^.*REQUIRES: //p')

  # Filters
  REQUIRES=$(echo $REQUIRES | sed "s/$PACKAGE\s//g")

#remote duplicated
  REQUIRES=$(echo $REQUIRES | xargs -n1 | sort -u | xargs)
  README=$(echo $REQUIRES | sed 's/*README*//') # Remove README files 
  [ ! -z $README ]; echo "Attention for README"; sleep 1

  if [ ! "$REQUIRES" ]; then
	  echo "### No additional requires found"
  else
	  echo " *** Dependence required packages *** "
	  echo " $REQUIRES"
	  echo "--------------------------------------"
  fi
}

function get_package() {

searchfor="$1"

SEARCH=$(zgrep -x -A 12  "SLACKBUILD NAME:* $searchfor" SLACKBUILDS.TXT.gz)
SEARCH=$(echo "$SEARCH" | sed -e '/^$/,$d')

if [ ! "$SEARCH" ]; then
    echo "No packages found for: $searchfor"
    break;
else
    NAME=$(echo "$SEARCH" | sed -n -e 's/^.*NAME: //p')
    LOCATION=$(echo "$SEARCH" | sed -n -e 's/^.*LOCATION: //p')
    VERSION=$(echo "$SEARCH" | sed -n -e 's/^.*VERSION: //p')
    DESCRIPTION=$(echo "$SEARCH" | sed -n -e 's/^.*DESCRIPTION: //p')
    DOWNLOAD=$(echo "$SEARCH" | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')

    echo "Name: $NAME"
    echo "Description: $DESCRIPTION"
    echo "Location: $LOCATION"
    echo "Source downloads: $DOWNLOAD"
fi
PACKAGE=$NAME
}

function check_prepar() {
  TODOWNLOAD="$TODOWNLOAD"

  if [ ! -z "$REQUIRES" ]; then
	  for dep_pack in $REQUIRES
	  do
		LOCAL_PKG=$(find /var/log/packages/ -iname "$dep_pack-*_SBo" -printf "%f /" )
		if [ ! "$LOCAL_PKG" ]; then
		    TODOWNLOAD="$dep_pack"
		else
		    LOCAL_PKGS="$LOCAL_PKGS $LOCAL_PKG "
		fi
	  done

	  if [ "$LOCAL_PKGS" ]; then
		  echo "Local packages installed:"
		  echo "$LOCAL_PKGS"
		  unset LOCAL_PKGS
	  fi
  fi
  echo "------------------------------------------"
  sleep 6
}


function download_package() {
get_package $1
SB_SOURCE="$SBo_MIRROR/$SLACKWARE_VERSION/${LOCATION}"

if [ ! -d "$TMP/$LOCATION" ]; then mkdir -p $LOCATION; fi
cd $TMP/$LOCATION

echo "Slackbuilds mirror: $SB_SOURCE"

if [ -z "$LOCATION" ]; then
  echo "Unable to locate SlackBuild for $1"
else
  echo "### Slackbuild's source: $SB_SOURCE"
  rsync -aPSH $SB_SOURCE/ $TMP/$LOCATION
fi



if [ -z $TMP/${LOCATION}/${NAME}/README ]; then
  cat $TMP/${LOCATION}/${NAME}/README
fi

# check for source downloads
if [ -z "$DOWNLOAD" ]; then
  for f in $DOWNLOAD
  do
	echo "wget -c -p -O ~/Downloads/SBo/$(basename $f) $f"
  done
fi
cd -
}




function download_temp() {

get_package $1

######
# Download package source files
######  
DOWNLOAD=$(zgrep -i -A 11 -x  "SLACKBUILD NAME: $PACKAGE" SLACKBUILDS.TXT.gz | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')

# split 
DOWNLOAD_ARCH=( $DOWNLOAD )
echo "Source archs found: ${#DOWNLOAD_ARCH[@]}"

  if [ ${#DOWNLOAD_ARCH[@]} == "0" ]; then
    echo "No sources found for: $PACKAGE"
    exit
  elif [ ${#DOWNLOAD_ARCH[@]} == "2" ]; then

  i=0
  for f in $DOWNLOAD
  do
	menu_diag[$i]="$i $(basename ${DOWNLOAD_ARCH[$i]})"
	link[$i]="$f"
	i=$(( $i + 1 ))
  done

  # User input selection
  DOWNLOAD=$(dialog --backtitle "Slackbuilds downloader" --menu "Choose a package:" 15 55 5 ${menu_diag[*]} 2>&1 >/dev/tty)
  echo $SCREEN - ${NAME[$SCREEN]} - ${link[$DOWNLOAD]}
  else
  
  # default selection
  DOWNLOAD=$(zgrep -i -A 11 "SLACKBUILD NAME: $PACKAGE" SLACKBUILDS.TXT.gz | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')
  DOWNLOAD=( $DOWNLOAD )
echo $SCREEN - ${NAME[$SCREEN]} - $DOWNLOAD
link[$i]="$DOWNLOAD"


  fi
  
  
  SB_SOURCE="$SBo_MIRROR/$SLACKWARE_VERSION/${LOCATION[$SCREEN]}"

  for slink in $DOWNLOAD
  do
	lfile="$(basename $slink)"
        echo "wget -O ~/Downloads/SBo/$lfile"
        echo "ln -rs $HOME/Downloads/SBo/$lfile $TMP/$PACKAGE/"
  done  

}

function download_sources() {

   DOWNLOAD=$(zgrep -A 11 "SLACKBUILD NAME: $PACKAGE" SLACKBUILDS.TXT.gz | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')
   DOWNLOAD_ARCH=( $DOWNLOAD )

   MD5SUM=$(zgrep -x -A 12  "SLACKBUILD NAME: $PACKAGE" SLACKBUILDS.TXT.gz | grep "MD5SUM" | sed -n -e 's/^.*: //p')


   #TODO: check if different downloads
   CATEGORY=$(dirname $LOCATION)
   SVAS_DOWNLOAD="$HOME/Downloads/$CATEGORY"
   mkdir -p $SVAS_DOWNLOAD

   for f in $DOWNLOAD
   do
	lfile="$(basename $f)"
	wget -c -p -O $SVAS_DOWNLOAD/$lfile $f 2>&1 | tee $LOG
	ln -rs $SVAS_DOWNLOAD/$lfile \
	       $TMP/$CATEGORY/$PACKAGE/
        CHECKSUM=$(md5sum $SVAS_DOWNLOAD/"$lfile" | cut -b 1-32 )
   done
   
   echo "$CHECKSUM : $MD5SUM"
   if [ "$CHECKSUM == $MD5SUM" ]; then echo "MD5SUM: Ok"; else echo "MD5SUM: fail"; sleep 1;fi

}

function build_package() {
   if [ ! -z "$DISTCC" ]; then
     MAKEL=$(awk 'NR==1,/\<make*/' $SBTARGET | wc -l )
     sed ''$MAKEL' s/\<make *\>/pump make -j'$NUMJOBS' CC=distcc/' $SBTARGET > $SBTARGET.distcc
     SBTARGET=$SBTARGET.distcc
     chmod +x $SBTARGET
     sudo distccmon-gnome &
   fi

   # User building parameters
   if [ ! -z $TMP_DIR ]; then TMP_DIR="TMP=$TMP_DIR"; fi 
   if [ ! -z $SBo_OUTPUT ]; then SBo_OUTPUT="OUTPUT=$SBo_OUTPUT/$CATEGORY"; fi
   ADDON="$ADDON"   # for custom package parameters


   CUSTOM="$TMP_DIR $SBo_OUTPUT $ADDON"

   if [ ! -z $ADDON ]; then 
      echo "Addons";
       sudo -u root $ADDON $CUSTOM ./$SBTARGET || exit
   else 
      echo "No addons !";
      sudo -u root $CUSTOM ./$SBTARGET || exit
   fi 
}

function pack_package() {

  if [ -z "$1" ];then
	echo "unknown package"
	exit 1
  fi

  PACKAGE=$1
  
  search_package $PACKAGE
  download_package $PACKAGE
  check_dependence
  check_prepar
  download_sources

  if [ "$TODOWNLOAD" ]; then
    echo "Do you wish to download the following slackbuilds:"
    echo " $TODOWNLOAD "
    read -p "Please confirm. (y/n):" yn
    while true; do
      case $yn in
        [Yy]* ) ;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
      esac
      
      read -p "Prepear dependence required packages ? (y/n): " yn
      case $yn in
        [Yy]* ) $0 download "$TODOWNLOAD"; pack_package $TODOWNLOAD;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
      esac 
    done
  fi

  # Download source files
   LOG=$TMP/$PACKAGE.log

   cd $TMP/$CATEGORY/${NAME[$NAME]}/
   SBTARGET=$PACKAGE.SlackBuild
   sudo chmod 754 $SBTARGET
   echo "sudo -u root ./$SBTARGET"
  
   build_package 

   sleep 1
   cd -
   #dialog --title "Example Dialog message box" --msgbox "\n Installation Completed on host7" 6 50 


   if [ ! -z $SBo_OUTPUT ]; then
     SBo_OUTPUT=$(echo "$SBo_OUTPUT" | awk -F"=" '{print $2}')
     OUT_PACKAGE=$(ls $SBo_OUTPUT/$PACKAGE-$VERSION-*.t?z)
   else
     OUT_PACKAGE=$(ls /tmp/$PACKAGE-$VERSION-*.t?z)
   fi


   sudo chown $(whoami) $OUT_PACKAGE
   echo "Building options:" > $OUT_PACKAGE.txt
   echo "$ADDON" >> $OUT_PACKAGE.txt


   if [ ! -z $SBo_OUTPUT ]; then
     cd $SBo_OUTPUT	   
     md5sum --tag $PACKAGE-$VERSION-*.t?z > $OUT_PACKAGE.md5
   else
     cd /tmp
     md5sum --tag $PACKAGE-$VERSION-*.t?z > $OUT_PACKAGE.md5
   fi

   read -p "Do you want to install: $PACKAGE ? (y/n): " yn
   while true; do
     case $yn in
        [Yy] )
	   install_slackbuilds $PACKAGE $OUT_PACKAGE;
	   break;
	;;
        [Nn] )
	   break;
	;;
        * ) 
	   echo "Please answer y or n.";
	   break
	;;
     esac
   done

}

function install_slackbuilds() {
#        sb_out=$(ls /tmp/$1-*SBo.t?z)
	LOCAL_PACKAGES=$(find /var/log/packages/ -iname "$1-*") 

	if [ ! -z "$LOCAL_PACKAGES" ]; then
	   echo "Slackware package already found"
           read -p "Do you want to upgrade ? (y/n): " yn
	   case $yn in
	      [Yy]* )
	    	   sudo -u root /sbin/upgradepkg $2
		;;
	      [Nn]* ) 
		  exit 0
		;;
	      * ) echo "Nothing to do."; exit 0;;
	   esac
	else
	    sudo -u root /sbin/installpkg $INSTOPTS $2
	fi
}

if [ $# -lt 1 ]; then
   echo "Usage: $(basename $0) search|indo|download|pack|install packagename"
   echo "  search - search for package"
   echo "  download - slackbuilds"
   echo "  pack - download and build the SlackBuilds"
   echo "  info - shows the SlackBuilds info"
   echo " * update - updates local SlackBuilds index"
   exit
fi

if [ ! -f SLACKBUILDS.TXT.gz ]; then  
    read -p "File not found, do you wish download it now ? (y/n):" yn
    case $yn in
        [Yy]* ) update_slackbuilds;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
fi

case $1 in
    search)
      search_package $2
    ;;
    download-sources)
      args=("$@")
      c=1
      while [ "$c" -lt "$#" ]; do        
	download_sources "${args[$c]}"
         (( c++ ))
      done
    ;; 
    download)
      args=("$@")
      c=1
      while [ "$c" -lt "$#" ]; do        
	#download_package "${args[$c]}"
        download_temp "${args[$c]}"
         (( c++ ))
      done
    ;;
    pack)
      args=("$@")
      c=1
      while [ "$c" -lt "$#" ]; do        
        pack_package "${args[$c]}"
        (( c++ ))
      done
    ;;
    install)
      install_slackbuilds $2
      exit
    ;;    
    info)
      info_package $2 
      exit
    ;;
    update)
      update_slackbuilds
      exit
    ;;
    *)
      echo "Unkwon option: $1"
      echo "Try $0: search|download|pack|info|update"
      echo "Sorry, no help for now"
      exit
    ;;
esac
#reset color mode


##
# Active mode
##
#cd ~/Downloads
#wget $DOWNLOAD || echo "Failed to download source files" | exit
#ln -rs $PACKAGE* $TMP/$PACKAGE
#chmod +x $TMP/$PACKAGE.SlackBuild


