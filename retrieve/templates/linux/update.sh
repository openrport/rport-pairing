set -e
CURRENT_VERSION=$(/usr/local/bin/rport --version | awk '{print $2}')
download_package() {
  if [ "$VERSION" != "undef" ]; then
    RELEASE=custom
    URL="https://github.com/cloudradar-monitoring/rport/releases/download/${VERSION}/rport_${VERSION}_Linux_${ARCH}.tar.gz"
    if curl -fI "$URL" >/dev/null 2>&1; then
      true
    else
      echo 1>&2 "Version $VERSION does not exist on $URL"
      exit 1
    fi
  else
    URL="https://download.rport.io/rport/${RELEASE}/?arch=Linux_${ARCH}&gt=${CURRENT_VERSION}"
  fi
  curl -Ls "${URL}" -o rport.tar.gz
}

restart_rport() {
  # The restart of RPort must be detached from this process in case the update is triggered remotely using rport.
  # The rport client would kill the script otherwise here.
  if [ -e /etc/init.d/rport ];then
    RESTART_CMD='/etc/init.d/rport restart'
  else
    RESTART_CMD='systemctl restart rport'
  fi
  if command -v at >/dev/null 2>&1; then
    echo "$RESTART_CMD" | at now +1 minute
    echo "Restart of rport scheduled via atd."
  else
    nohup sh -c "sleep 10;$RESTART_CMD" >/dev/null 2>&1 &
    echo "Restart of rport scheduled via nohup+sleep."
  fi
}
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  update
#   DESCRIPTION:  update to the latest version or exit if not update available
#----------------------------------------------------------------------------------------------------------------------
update() {
  check_prerequisites
  cd /tmp
  download_package
  test -e rport && rm -f rport
  if tar xzf rport.tar.gz rport 2>/dev/null; then
    TARGET_VERSION=$(./rport --version | awk '{print $2}')
    echo "Updating from ${CURRENT_VERSION} to latest ${RELEASE} $(./rport --version)"
    check_scripts
    check_sudo
    create_sudoers_updates
    detect_interpreters
    enable_monitoring
    enable_lan_monitoring
    mv -f /tmp/rport /usr/local/bin/rport
    restart_rport
  else
    echo "Nothing to do. RPort is on the latest version ${CURRENT_VERSION}."
    [ "$ENABLE_TACOSCRIPT" -eq 1 ] && install_tacoscript
    exit 0
  fi
  rm -f rport.tar.gz
  [ "$ENABLE_TACOSCRIPT" -eq 1 ] && install_tacoscript
  if pidof rport >/dev/null; then
    finish
  else
    fail
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  ask_yes_no
#   DESCRIPTION:  Ask a question and wait for a confirmation
#    PARAMETERS:  Question to be asked
#----------------------------------------------------------------------------------------------------------------------
ask_yes_no() {
  if [ -z "$1" ]; then
    printf "Do you want to proceed?"
  else
    printf "%s" "$1"
  fi
  echo " (y/n)"
  while read -r INPUT; do
    if echo "$INPUT" | grep -q "^[Yy]"; then
      return 0
    elif echo "$INPUT" | grep -q "^[Nn]"; then
      return 1
    fi
    echo "Type (y/n) or abort with Ctrl-C"
  done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  insert_scripts
#   DESCRIPTION:  Insert the missing remote scripts block
#----------------------------------------------------------------------------------------------------------------------
insert_scripts() {
  echo "[remote-scripts]
  enabled = ${ENABLE_SCRIPTS}
" >>"$CONFIG_FILE"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_scripts
#   DESCRIPTION:  check if scripts can be activated
#----------------------------------------------------------------------------------------------------------------------
check_scripts() {
  if grep -q remote-scripts "$CONFIG_FILE"; then
    return 0
  fi
  if [ "$ENABLE_SCRIPTS" = 'true' ]; then
    insert_scripts
    return 0
  fi
  if is_terminal; then
    true
  else
    echo 1>&2 "Please use the switches -x/-d to enable or disable script execution."
    help
    exit 1
  fi
  if ask_yes_no "Do you want to activate script execution?"; then
    ENABLE_SCRIPTS=true
    insert_scripts
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_sudo
#   DESCRIPTION:  check if user wants to enable sudo
#----------------------------------------------------------------------------------------------------------------------
check_sudo() {
  if [ -e /etc/sudoers.d/rport-all-cmd ]; then
    return 0
  fi
  if [ "$ENABLE_SUDO" -eq 1 ]; then
    create_sudoers_all
    return 0
  fi
  if is_terminal; then
    true
  else
    echo 1>&2 "Please use the switches -s/-n to enable or disable sudo rights."
    help
    exit 1
  fi
  if ask_yes_no "Do you want to activate sudo rights for RPort remote script execution?"; then
    create_sudoers_all
  fi
}

clean_up() {
  true
}

enable_monitoring() {
  if [ "$(version_to_int "$TARGET_VERSION")" -lt 5000 ];then
        # Version does not handle monitoring yet.
        return 0
  fi
  if grep -q "\[monitoring\]" "$CONFIG_FILE";then
    echo "Monitoring already enabled."
    return 0
  fi
  cat <<EOF >>"$CONFIG_FILE"
[monitoring]
  ## The rport client can collect and report performance data of the operating system.
  ## https://oss.rport.io/docs/no17-monitoring.html
  ## Monitoring is enabled by default
  enabled = true
  ## How often (seconds) monitoring data should be collected.
  ## A value below 60 seconds will be overwritten by the hard-coded default of 60 seconds.
  # interval = 60
  ## RPort monitors the fill level of almost all volumes or mount points.
  ## Change the below defaults to include or exclude volumes or mount points from the monitoring.
  #fs_type_include = ['ext3','ext4','xfs','jfs','ntfs','btrfs','hfs','apfs','exfat','smbfs','nfs']
  ## List of excluded mount points or device letters
  #fs_path_exclude = []
  ## Example:
  # fs_path_exclude = ['/mnt/*','h:']
  ## Having fs_path_exclude_recurse = false the specified path
  ## must match a mountpoint or it will be ignored
  ## Having fs_path_exclude_recurse = true the specified path
  ## can be any folder and all mountpoints underneath will be excluded
  #fs_path_exclude_recurse = false
  ## To avoid monitoring of so-called mount binds,
  ## mount points are identified by the path and device name.
  ## Mountpoints pointing to the same device are ignored.
  ## What appears first in /proc/self/mountinfo is considered as the original.
  ## Applies only to Linux
  #fs_identify_mountpoints_by_device = true
  ## RPort monitors all running processes
  ## Process monitoring is enabled by default
  pm_enabled = true
  ## Monitor kernel tasks identified by process group 0
  #pm_enable_kerneltask_monitoring = true
  ## The process list is sorted by PID descending. Only the top N processes are monitored.
  #pm_max_number_monitored_processes = 500
  ## Monitor the bandwidth usage of the following maximum two network cards:
  ## 'net_lan' and 'net_wan'.
  ## You must specify the device name and the maximum speed in Megabits.
  ## On Windows use 'Get-Netadapter' to discover adapter names.
  ## Examples:
  ## net_lan = [ 'eth0' , 1000 ]
  ## net_wan = ['Ethernet0', 1000]
  #net_lan = ['', 1000]
  #net_wan = ['', 1000]
EOF
echo "Monitoring enabled."
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  finish
#   DESCRIPTION:  print some information
#----------------------------------------------------------------------------------------------------------------------
finish() {
  echo "
#
#  Update of RPort finished.
#
#  Logs are written to /var/log/rport/rport.log.
#
#  READ THE DOCS ON https://kb.rport.io/
#
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#  Give us a star on https://github.com/cloudradar-monitoring/rport
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#

Thanks for using
  _____  _____           _
 |  __ \|  __ \         | |
 | |__) | |__) |__  _ __| |_
 |  _  /|  ___/ _ \| '__| __|
 | | \ \| |  | (_) | |  | |_
 |_|  \_\_|   \___/|_|   \__|
"
}

fail() {
  systemctl --no-pager status rport
  echo "
#
# -------------!!   ERROR  !!-------------
#
# Update of RPort finished with errors.
#

Try the following to investigate:
1) systemctl rport status

2) tail /var/log/rport/rport.log

3) Ask for help on https://kb.rport.io/need-help/request-support
"
  if runs_with_selinux; then
    echo "
4) Check your SELinux settings and create a policy for rport."
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  help
#   DESCRIPTION:  print a help message and exit
#----------------------------------------------------------------------------------------------------------------------
help() {
  cat <<EOF
Usage $0 [OPTION(s)]

Update the current version of RPort to the latest version.

Options:
-h  print this help message
-v [version] update to the specified version.
-c  update the rport client, default action
-t  use the latest unstable version (DANGEROUS!)
-u  uninstall the rport client and all configurations and logs
-x  enable script execution in rport.conf
-d  disable script execution in rport.conf
-s  create sudo rules to grant full root access to the rport user
-m  do not install or update tacoscript
EOF
  exit 0
}

#
# Read the command line options and map to a function call
#
ACTION=update
ENABLE_TACOSCRIPT=1
ENABLE_SUDO=2
RELEASE=stable
ENABLE_SCRIPTS=undef
VERSION=undef
while getopts "hcuxdsmtv:" opt; do
  case "${opt}" in

  h) ACTION=help ;;
  v) VERSION=${OPTARG} ;;
  c) ACTION=update ;;
  u) ACTION=uninstall ;;
  x) ENABLE_SCRIPTS=true ;;
  d) ENABLE_SCRIPTS=false ;;
  s) ENABLE_SUDO=1 ;;
  t) RELEASE=unstable ;;
  m) ENABLE_TACOSCRIPT=0;;

  \?)
    echo "Option does not exist."
    exit 1
    ;;
  esac # --- end of case ---
done
shift $((OPTIND - 1))
$ACTION # Execute the function according to the users decision
