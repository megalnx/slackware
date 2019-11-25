SERVERS=${SERVERS:-"slackit-130 slackit64-130 slackit-131 slackit64-131 slackit-1337 slackit64-1337 slackit-140 slackit64-140 slackit-141 slackit64-141 slackit-142 slackit64-142"}
LXCDIR=/var/lib/lxc/slackit

function build_pkg() {
     mcmd=$1

     package=$(echo "$@" | sed 's/'$mcmd'//g' | xargs -n1 | xargs)

     echo "Package(s): $package"
     REMOTE_USER=root BUILD_SERVER="$server" sh remote-build-pkg.sh pack "$package" auto;
}

function slack_upd() {
  if [ $# -lt 1 ]; then
    echo -e "\n $1 requires an argument 'update|install...\n"
    exit 0
  else
    ssh "$server" 'bash -l' slackpkg $2 $3
  fi
}

function lxchellow() {
    ssh "$server" 'cat /etc/slackware-version; uname -m'

}



function lxc_power() {
case $1 in
  start) echo "Starting $server..."; sleep 1
         lxc-$1 -P $LXCDIR -n $2 -d ; sleep 1 ;;
  stop) echo "Stopping $server...";  lxc-$1 -P $LXCDIR -n $2 ;;
  *) echo "Unknown container state: $1 lxc-power start|stop";;
esac

}

function rssh() {
  echo "User command: $@"
  echo "Building machines: $SERVERS"

  for server in $SERVERS
  do
    lxc_power start $server ; sleep 1
    lxc-wait -P $LXCDIR -n $server --state=RUNNING ; sleep 5
    $1 $@ | tee /var/log/lxc/$server/lxc-$server\-$1.log


    lxc_power stop $server ; sleep 1
  done
}

if [ $# -lt 1 ]; then
  echo "options: pack or slackpkg "PKGNAME""; 
  exit
fi

case $1 in
  pack) rssh build_pkg $2 ;;
  slackpkg) rssh slack_upd $2 $3 $4;;
  check) rssh lxchellow ;;
  *) echo "options: pack "PKGNAME"" or slackpkg "arguments";;
esac
