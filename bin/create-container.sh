
CTNAME=slackit-123
MIRROR=${MIRROR:-"ftp://ftp.slackware.com/pub"}
IPV4=${IPV4:-'10.0.0.1'}

DIALOG=dialog

$DIALOG --title "SLACKIT-LXC install" --infobox "This setup help you to setup a Slackware container" 16 45

tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/lxc-slackit-tmp$$
trap "rm -f $tempfile" 0 1 2 5 15


$DIALOG --max-input 32 --title "SLACKIT-LXC install" --inputbox "Container name:" 16 45 "slackit-123" 2> $tempfile
CTNAME=`cat $tempfile`



$DIALOG --title "SLACKIT-LXC install" --inputbox "Slackware mirror:\nhttp://www.slackware.com/pub/\nftp://ftp.slackware.com/pub/" 16 45 "$MIRROR" 2> $tempfile
MIRROR=$(cat $tempfile)

$DIALOG --backtitle "LXC Slackware" --radiolist "Choose a machine architecture:" 20 45 5 \
		arm - off \
		i486 x86 on \
		x86_64 x86_64 off  2> $tempfile
MARCH=$(cat $tempfile)

$DIALOG --backtitle "LXC Slackware" --radiolist "Choose a version:" 20 45 5 \
		13.37 - off \
		14.0 - off \
		14.1 -  off \
		14.2 - on \
		current - off  2> $tempfile
RELEASE=$(cat $tempfile)

macaddress=$(date|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
cat <<EOF > /tmp/lxc-slackit-additional.conf
# Additional container configuration: 
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = virbr0
lxc.network.hwaddr = $macaddress
lxc.network.ipv4 = $IPV4
lxc.mount.entry = /mnt/tmp  mnt/tmp  bind   0  0
EOF

$DIALOG --title "SLACKIT-LXC install" --editbox  /tmp/lxc-slackit-additional.conf 20 50  2> $tempfile
ADDCONF=$(cat $tempfile)

echo $CTNAME - $MARCH - $RELEASE :  $MIRROR 

$DIALOG --title "SLACKIT-LXC install" --msgbox "\nName: $CTNAME \nSlackware version: $RELEASE - ($MARCH) \n\nMirror source: $MIRROR\n\n$ADDCONF\n" 25 100

MIRROR=$MIRROR arch=$MARCH release=$RELEASE lxc-create -n $CTNAME -t slackware -f /tmp/lxc-slackit-additional.conf 1>& lxc-slackit-install.log & sleep 1
$DIALOG   --scrollbar --title "SLACKIT-LXC install" --tailbox "lxc-slackit-install.log" 40 160 && sleep 0.5

echo "$ADDCONF" >> /var/lib/lxc/$CTNAME/config

$DIALOG --title "SLACKIT-LXC install" --yesno " Do you want to start the container ? " 8 50 

retval=$?

case $retval in
	1) echo "If you wish to start your container, use the following command: lxc-start -n $CTNAME ";;
	0) echo "Starting $CTNAME..."; lxc-start -n $CTNAME ;;
esac

