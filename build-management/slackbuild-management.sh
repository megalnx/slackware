#!/bin/bash
# 
# Slackbuild's management script
#
# Copyright 2014-2019 William PC, Seattle, US.
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

SVAS_DOWNLOAD="$HOME/Downloads/slackbuilds"
TMP=${TMP:-~/Public/SBo-slackbuilds/$SLACKWARE_VERSION}
WGETOPTS="--no-check-certificate"
INSTOPTS="--terse"

[ $(which sudo) ] || exit

case "$ARCH" in
   i?86)
     ARCH=x86; SLACKNAME="" 
     ;;
   x86_64) ARCH=x86_64; SLACKNAME="64" 
     ;;
    *) echo "Unkown arch";exit;;
esac    

if [ -z "$SBo_MIRROR" ]; then
  SBo_MIRROR="rsync://slackbuilds.org/slackbuilds"
  echo "No local mirror defined mirror,
        using $SBo_MIRROR"; sleep 0.5
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

if [ "Slackware $SLACKWARE_VERSION" != "$SLACKWARE_LOCAL_VERSION" ]; then
  red='\033[0;31m'
  NC='\033[0m' # No Color
  echo -e "${red}  # # ATTENTION # # ${NC}"
  echo " Slackware release version differs"
  echo "Slackware $SLACKWARE_VERSION != $SLACKWARE_LOCAL_VERSION"
  sleep 3
fi

function update_slackbuilds() {
  echo "### Updating Slackbuild's source"

  if [ ! -f $TMP/SLACKBUILDS.TXT.old ] && [ -f $TMP/SLACKBUILDS.TXT.gz ]; then
     zcat $TMP/SLACKBUILDS.TXT.gz > $TMP/SLACKBUILDS.TXT.old
  fi
     rsync -auv $SBo_MIRROR/$SLACKWARE_VERSION/SLACKBUILDS.TXT.gz $TMP
     zcat $TMP/SLACKBUILDS.TXT.gz > $TMP/SLACKBUILDS.TXT.new

  if [ -f $TMP/SLACKBUILDS.TXT.new ] && [ -f $TMP/SLACKBUILDS.TXT.old ]; then 
     NEWPKGS=$(diff $TMP/SLACKBUILDS.TXT.new $TMP/SLACKBUILDS.TXT.old | grep "SLACKBUILD NAME:" | awk '{print $( ( 4 ) )}')
     echo " ${#NEWPKGS[@]} new packages:"
     echo $NEWPKGS
  fi
}

function display_packages {
	searchfor=$1
	SEARCH=$(zgrep -i "$searchfor" $TMP/SLACKBUILDS.TXT.gz | sed -n -e 's/SLACKBUILD NAME: //p')

	PKG_LIST=( $SEARCH )

	if [ ${#PKG_LIST[@]} == 0 ]; then
	  echo "No packages found for: $searchfor"
	  return 1
	else
	  echo "Packages found for $searchfor: ${#PKG_LIST[@]}"; sleep 1
	fi

    	npkg=0;
	while [ $npkg -lt "${#PKG_LIST[@]}" ]
	do
    	    menu_list[$npkg]=" $npkg ${PKG_LIST[$npkg]} "
	    npkg=$(( $npkg + 1 ))
	done
	tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/sb_management-tmp$$
        dialog --backtitle "Slackbuilds for $SLACKWARE_VERSION" --menu "Choose a package:" 15 45 5 ${menu_list[@]} 2> $tempfile

	if test $? -eq 0
	then 
	   PACKAGE=$(cat $tempfile)
#	   get_package ${PKG_LIST[$PACKAGE]}
	   info_package ${PKG_LIST[$PACKAGE]}

	fi
}

function search_package() {
    searchfor="$1"

    if [ -z "$searchfor" ]; then
      echo "None search entry asked by user"
      exit
    fi

    NAME=$(zgrep -i "$searchfor" $TMP/SLACKBUILDS.TXT.gz | sed -n -e 's/^.*NAME: //p')
    NAME=( $NAME )

    if [ "${#NAME[@]}" == "1" ]; then
      DESCRIPTION=$(zgrep -i "$searchfor" $TMP/SLACKBUILDS.TXT.gz | sed -n -e 's/^.*DESCRIPTION: //p')
      echo "$(tput bold) $NAME $(tput sgr0) - $DESCRIPTION"
    elif [ "${#NAME[@]}" == "0" ]; then
      echo "No packages found for: $searchfor"
    else     
      display_packages $searchfor || exit 1
    fi

}

function info_package() {
    PACKAGE=$1
    for pkg in $PACKAGE; do
      get_package $pkg
    done
    echo "------------------------------------------"
    echo "Name: $NAME"
    echo "Description: $DESCRIPTION"
    echo "Location: $LOCATION"
      if [ ! -z "$DESCRIPTION" ]; then
        echo "Source file(s):"
        for f in $DOWNLOAD; do
          echo "$(tput sgr0) $f"
        done
        PACKAGE=$NAME
        check_dependence
        echo "--------------------------------------"
        tput sgr0
      fi

}

# Check for required packages
function check_dependence() {
  REQUIRES=$(zgrep -A 10 -x "SLACKBUILD NAME: $PACKAGE" $TMP/SLACKBUILDS.TXT.gz | grep "SLACKBUILD REQUIRES:" | sed -n -e 's/^.*REQUIRES: //p')

  # Filters
  REQUIRES=$(echo $REQUIRES | sed "s/$PACKAGE\s//g")

  #remove duplicated
  REQUIRES=$(echo $REQUIRES | xargs -n1 | sort -u | xargs)

  REQUIRES=$(echo "$REQUIRES" | sed 's/[%]README[%]//')

  if [ "$REQUIRES" ]; then
    echo "--------------------------------------"
    echo "$(tput bold)*** Dependence required packages *** "
    echo "$(tput sgr0) $REQUIRES"
    echo "--------------------------------------"
  fi
}

function get_package() {
  searchfor="$1"

  SEARCH=$(zgrep -x -A 12  "SLACKBUILD NAME:* $searchfor" $TMP/SLACKBUILDS.TXT.gz)
  SEARCH=$(echo "$SEARCH" | sed -e '/^$/,$d')

  if [ ! "$SEARCH" ]; then
    echo "No packages found for: $searchfor"
    echo "try slackbuild-management.sh search $searchfor"
    return 1
  else
    NAME=$(echo "$SEARCH" | sed -n -e 's/^.*NAME: //p')
    LOCATION=$(echo "$SEARCH" | sed -n -e 's/^.*LOCATION: //p')
    VERSION=$(echo "$SEARCH" | sed -n -e 's/^.*VERSION: //p')
    DESCRIPTION=$(echo "$SEARCH" | sed -n -e 's/^.*DESCRIPTION: //p')
    DOWNLOAD=$(echo "$SEARCH" | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')
    return 0
  fi
}

function check_prepar() {
  if [ ! -z "$REQUIRES" ]; then
    for dep_pack in $REQUIRES; do
	INSTALLED_PKG=$(find /var/log/packages/ -iname "$dep_pack-[0-9]*" -printf "%f /" )
	if [ ! "$INSTALLED_PKG" ]; then
	    TODOWNLOAD+="$dep_pack "
	else
	    INSTALLED_PKGS+="$INSTALLED_PKG "
	fi
    done

    if [ ! -z "$INSTALLED_PKGS" ]; then
      echo "Local packages installed:"
      echo "$INSTALLED_PKGS"
      unset INSTALLED_PKGS
      echo "------------------------------------------"
    fi
  fi


  if [ "$TODOWNLOAD" ]; then
    for pkg_name in $TODOWNLOAD; do
      if [ ! -z "$SBo_OUTPUT" ]; then
        LOCAL_PACKAGE=$(find $SBo_OUTPUT/$ARCH/$SLACKWARE_VERSION -maxdepth 2  -iname $pkg_name-[0-9]*.t?z)
      else
        LOCAL_PACKAGE=$(find /tmp -maxdepth 1 -iname $PACKAGE-[0-9]*.t?z)
      fi

      if [ ! -z "$LOCAL_PACKAGE" ]; then
        echo "Slackware package already found: $LOCAL_PACKAGE"
        echo "Do you want to install it"
        while true; do	      
        read -p "Please answer ? (y/n): " yn
          case $yn in
            [Yy]* )  install_slackbuilds $PACKAGE $LOCAL_PACKAGE
		     TODOWNLOAD=$(echo $TODONWLOAD | tr -d "$pkg_name")		     
  		     break;;
            [Nn]* )  break;;
            * ) echo "Please answer yes or no."; sleep 1;;
          esac
        done
      fi
     done
   fi


  if [ "$TODOWNLOAD" ]; then
    echo "Do you wish to prepar the following slackbuilds:"
    echo $TODOWNLOAD

    while true; do
      read -p "Prepear dependence required packages ? (y/n): " yn
      case $yn in
        [Yy]* )  #echo yes | 
		sh $0 pack $TODOWNLOAD;
		 #pack_package $TODOWNLOAD; 
		 break;;
        [Nn]* )  break;;
        * ) echo " Please answer yes or no."; sleep 1;;
      esac
    done
 fi


}


function download_slackbuild() {
  get_package $1 || break

  SB_SOURCE="$SBo_MIRROR/$SLACKWARE_VERSION/${LOCATION}"
  if [ ! -d "$TMP/$LOCATION" ]; then mkdir -p $LOCATION; fi

  echo "### Slackbuild's source: $SB_SOURCE"
  rsync -aPSH $SB_SOURCE/ $TMP/$LOCATION

  if [ -f $TMP/${LOCATION}/${NAME}/README ]; then
    cat $TMP/${LOCATION}/${NAME}/README
    sleep 3
  fi
}


function download_temp() {

get_package $1

######
# Download package source files
######  
DOWNLOAD=$(zgrep -i -A 11 -x  "SLACKBUILD NAME: $PACKAGE" $TMP/SLACKBUILDS.TXT.gz | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')

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
  DOWNLOAD=$(zgrep -i -A 11 "SLACKBUILD NAME: $PACKAGE" $TMP/SLACKBUILDS.TXT.gz | grep "DOWNLOAD" | sed -n -e 's/^.*: //p')
  DOWNLOAD=( $DOWNLOAD )
   echo $SCREEN - ${NAME[$SCREEN]} - $DOWNLOAD
   link[$i]="$DOWNLOAD"

  fi
  
  SB_SOURCE="$SBo_MIRROR/$SLACKWARE_VERSION/${LOCATION[$SCREEN]}"

}

function download_sources() {
   get_package $PACKAGE || break
   
   MD5SUM=$(zgrep -x -A 12 -x "SLACKBUILD NAME: $PACKAGE" $TMP/SLACKBUILDS.TXT.gz | grep "MD5SUM" | sed -n -e 's/^.*: //p')

   #TODO: check if different downloads
   CATEGORY=$(dirname $LOCATION)
   mkdir -p "$SVAS_DOWNLOAD/$CATEGORY"

   for f in $DOWNLOAD
   do
     lfile="$(basename $f)"
     LOG=$SVAS_DOWNLOAD/../wget-$lfile.log
     wget $WGETOPTS -c -p -O $SVAS_DOWNLOAD/$CATEGORY/$lfile $f 2>&1 | tee $LOG
#     [ -s "$SVAS_DOWNLOAD/$CATEGORY/$lfile" ] || break
     rm $TMP/$CATEGORY/$PACKAGE/$lfile
     ln -f -rs $SVAS_DOWNLOAD/$CATEGORY/$lfile \
       $TMP/$CATEGORY/$PACKAGE/$lfile || ln -f -s $SVAS_DOWNLOAD/$lfile $TMP/$CATEGORY/$PACKAGE/

     CHECKSUM=$(md5sum $SVAS_DOWNLOAD/$CATEGORY/"$lfile" | cut -b 1-32 )
     echo "$CHECKSUM : $MD5SUM"
     if [ "$CHECKSUM" == "$MD5SUM" ]; then echo "MD5SUM: Ok"; else echo "MD5SUM: fail";fi
   done  
}

function build_package() {
   
  cd $TMP/$CATEGORY/${NAME[$NAME]}/

  if [ ! -z "$DISTCC" ]; then
    MAKEL=$(awk 'NR==1,/\<make*/' $SBTARGET | wc -l )
    sed ''$MAKEL' s/\<make *\>/pump make -j'$NUMJOBS' CC=distcc/' $SBTARGET > $SBTARGET.distcc
    SBTARGET=$SBTARGET.distcc
    chmod +x $SBTARGET
    sudo distccmon-gnome &
  else
    SBTARGET=$PACKAGE.SlackBuild || exit
    sudo chmod 754 $SBTARGET
  fi
 
  ADDON="$ADDON"   # for custom package parameters

  # User building parameters
  if [ ! -z $TMP_DIR ]; then TMP_DIR="TMP=$TMP_DIR"; fi 
  if [ ! -z $SBo_OUTPUT ]; then
    CUSTOM="$TMP_DIR OUTPUT=$SBo_OUTPUT/$ARCH/$SLACKWARE_VERSION/$CATEGORY $ADDON"
  else
    CUSTOM="$TMP_DIR $ADDON"
  fi

  LOG=$TMP/../$SBTARGET-$(echo $SLACKWARE_VERSION | tr -d ".").log
  if [ ! -z $ADDON ]; then 
     echo "Addons $CUSTOM";
     sudo -u root $ADDON $CUSTOM ./$SBTARGET 2>&1 | tee $LOG
  else 
     echo "No addons !";
     sudo -u root $CUSTOM ./$SBTARGET 2>&1 | tee $LOG
  fi 
}

function pack_package() {

  if [ -z "$1" ];then
    echo "Unknown package"
    exit 1
  fi

  PACKAGE=$1

  get_package $PACKAGE || break
  info_package $PACKAGE

  check_prepar
  download_slackbuild $PACKAGE || break 
  
  # Download source files
  download_sources || exit

  build_package || exit

  cd -

  if [ ! -z "$SBo_OUTPUT" ]; then
#    SBo_OUTPUT=$(echo "$SBo_OUTPUT" | awk -F"=" '{print $2}')
    OUT_PACKAGE=$(ls $SBo_OUTPUT/$ARCH/$SLACKWARE_VERSION/$CATEGORY/$PACKAGE-$VERSION-*.t?z)
    cd $SBo_OUTPUT/$ARCH/$SLACKWARE_VERSION/$CATEGORY
  else
    OUT_PACKAGE=$(ls /tmp/$PACKAGE-$VERSION-*.t?z)
    cd /tmp
  fi

  sudo chown $(whoami) $OUT_PACKAGE || exit
  echo "Building options:" > $OUT_PACKAGE.txt
  echo "$ADDON" >> $OUT_PACKAGE.txt

  md5sum --tag $PACKAGE-$VERSION-*.t?z > $OUT_PACKAGE.md5

  cd -

  while true; do
  read -p "Do you want to install: $PACKAGE ? (y/n): " yn
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
  LOCAL_PACKAGES=$(find /var/log/packages/ -iname "$1-[0-9]*")

  if [ ! -z "$LOCAL_PACKAGES" ]; then
    echo "Slackware package already installed"    
    echo "$LOCAL_PACKAGES"
    read -p "Do you want to upgrade ? (y/n): " yn
    case $yn in
      [Yy]* )
    	   sudo -u root /sbin/upgradepkg $2
	;;
      [Nn]* ) 
	  break;
	;;
      * ) echo "Nothing to do."; break;;
     esac
   else
     sudo -u root /sbin/installpkg $INSTOPTS $2
   fi
}

if [ $# -lt 1 ]; then
   echo "Usage: $(basename $0) search|info|download|download-sources|pack|install packagename"
   echo "  search - search for package"
   echo "  info - shows the SlackBuilds info"
   echo "  download - get SlackBuilds files"
   echo "  download-sources - get package source files"
   echo "  pack - download and build the SlackBuilds"
   echo "  install - install package"
   echo " * update - updates local SlackBuilds index"
   exit
fi

if [ ! -f $TMP/SLACKBUILDS.TXT.gz ]; then
  while true; do
    read -p "File not found, do you wish download it now ? (y/n): " yn
    case $yn in
      [Yy]* ) update_slackbuilds;;
      [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
  done
fi

case $1 in
    search)
      search_package $2
    ;;
    download)
      args=("$@")
      c=1
      while [ "$c" -lt "$#" ]; do        
	download_slackbuild "${args[$c]}"
         (( c++ ))
      done
    ;; 
    download-sources)
      args=("$@")
      c=1
      while [ "$c" -lt "$#" ]; do        
	PACKAGE="${args[$c]}"
	download_sources "${args[$c]}"
#        download_temp "${args[$c]}"
         (( c++ ))
      done
      exit
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
      args=("$@")
      c=1
      while [ "$c" -lt "$#" ]; do        
        info_package "${args[$c]}"
        (( c++ ))
      done
      exit
    ;;
    update)
      update_slackbuilds
      exit
    ;;
    *)
      echo "Unknown option: $1"
      echo "Try: $0 search|info|download|download-sources|pack|install|update"
      exit
    ;;
esac
