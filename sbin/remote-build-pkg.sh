
#lxc-ls --fancy -n $BUILD_SERVER

ssh $REMOTE_USER@$BUILD_SERVER 'rm /var/lock/slackpkg.*'
ssh $REMOTE_USER@$BUILD_SERVER 'yes n | slackpkg update'
ssh $REMOTE_USER@$BUILD_SERVER 'slackpkg upgrade-all'
ssh $REMOTE_USER@$BUILD_SERVER 'bash -l -s' -- < /usr/local/sbin/slackbuild-management.sh update
ssh $REMOTE_USER@$BUILD_SERVER 'bash -l -s' -- < /usr/local/sbin/slackbuild-management.sh $1 "$2" auto
ssh $REMOTE_USER@$BUILD_SERVER 'slackpkg clean-system'
