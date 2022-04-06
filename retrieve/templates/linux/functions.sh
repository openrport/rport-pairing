set -e
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_available
#   DESCRIPTION:  Check if a command is available on the system.
#    PARAMETERS:  command name
#       RETURNS:  0 if available, 1 otherwise
#----------------------------------------------------------------------------------------------------------------------
is_available() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  uninstall
#   DESCRIPTION:  Uninstall everything and remove the user
#----------------------------------------------------------------------------------------------------------------------
uninstall() {
  if pgrep rportd >/dev/null; then
    echo 1>&2 "You are running the rportd server on this machine. Uninstall manually."
    exit 0
  fi
  systemctl stop rport >/dev/null 2>&1 || true
  rc-service rport stop >/dev/null 2>&1 || true
  pkill -9 rport >/dev/null 2>&1 || true
  rport --service uninstall >/dev/null 2>&1 || true
  FILES="/usr/local/bin/rport
    /usr/local/bin/rport
    /etc/systemd/system/rport.service
    /etc/sudoers.d/rport-update-status
    /etc/sudoers.d/rport-all-cmd
    /usr/local/bin/tacoscript
    /etc/init.d/rport
    /var/run/rport.pid
    /etc/runlevels/default/rport"
  for FILE in $FILES; do
    if [ -e "$FILE" ]; then
      rm -f "$FILE" && echo " [ DELETED ] File $FILE"
    fi
  done
  if id rport >/dev/null 2>&1; then
    if is_available deluser; then
      deluser --remove-home rport >/dev/null 2>&1 ||true
      deluser --only-if-empty --group rport >/dev/null 2>&1 ||true
    elif is_available userdel; then
      userdel -r -f rport >/dev/null 2>&1
    fi
    if is_available groupdel; then
      groupdel -f rport >/dev/null 2>&1 ||true
    fi
    echo " [ DELETED ] User rport"
  fi
  FOLDERS="/etc/rport
    /var/log/rport
    /var/lib/rport"
  for FOLDER in $FOLDERS; do
    if [ -e "$FOLDER" ]; then
      rm -rf "$FOLDER" && echo " [ DELETED ] Folder $FOLDER"
    fi
  done
  echo "RPort client successfully uninstalled."
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  print_distro
#   DESCRIPTION:  print name of the distro
#----------------------------------------------------------------------------------------------------------------------
print_distro() {
  if [ -e /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    echo "Detected Linux Distribution: ${PRETTY_NAME}"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_sudoers_all
#   DESCRIPTION:  create a sudoers file to grant full sudo right to the rport user
#----------------------------------------------------------------------------------------------------------------------
create_sudoers_all() {
  SUDOERS_FILE=/etc/sudoers.d/rport-all-cmd
  if [ -e "$SUDOERS_FILE" ]; then
    echo "You already have a $SUDOERS_FILE. Not changing."
    return 1
  fi

  if is_available sudo; then
    echo "#
# This file has been auto-generated during the installation of the rport client.
# Change to your needs or delete.
#
${USER} ALL=(ALL) NOPASSWD:ALL
" >$SUDOERS_FILE
    echo "A $SUDOERS_FILE has been created. Please review and change to your needs."
  else
    echo "You don't have sudo installed. No sudo rules created. RPort will not be able to get elevated right."
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_sudoers_updates
#   DESCRIPTION:  create a sudoers file to allow rport supervise the update status
#----------------------------------------------------------------------------------------------------------------------
create_sudoers_updates() {
  SUDOERS_FILE=/etc/sudoers.d/rport-update-status
  if [ -e "$SUDOERS_FILE" ]; then
    echo "You already have a $SUDOERS_FILE. Not changing."
    return 0
  fi

  if is_available sudo; then
    echo '#
# This file has been auto-generated during the installation of the rport client.
# Change to your needs.
#' >$SUDOERS_FILE
    if is_available apt-get; then
      echo "${USER} ALL=NOPASSWD: SETENV: /usr/bin/apt-get update -o Debug\:\:NoLocking=true" >>$SUDOERS_FILE
    fi
    #if is_available yum;then
    #  echo 'rport ALL=NOPASSWD: SETENV: /usr/bin/yum *'>>$SUDOERS_FILE
    #fi
    #if is_available dnf;then
    #  echo 'rport ALL=NOPASSWD: SETENV: /usr/bin/dnf *'>>$SUDOERS_FILE
    #fi
    if is_available zypper; then
      echo "${USER} ALL=NOPASSWD: SETENV: /usr/bin/zypper refresh *" >>$SUDOERS_FILE
    fi
    #if is_available apk;then
    #  echo 'rport ALL=NOPASSWD: SETENV: /sbin/apk *'>>$SUDOERS_FILE
    #fi
    echo "A $SUDOERS_FILE has been created. Please review and change to your needs."
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  abort
#   DESCRIPTION:  Exit the script with an error message.
#----------------------------------------------------------------------------------------------------------------------
abort() {
  echo >&2 "$1 Exit!"
  clean_up
  exit 1
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  confirm
#   DESCRIPTION:  Print a success message.
#----------------------------------------------------------------------------------------------------------------------
confirm() {
  echo "Success: $1"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_prerequisites
#   DESCRIPTION:  Check if prerequisites are fulfilled.
#----------------------------------------------------------------------------------------------------------------------

check_prerequisites() {
  if [ "$(id -u)" -ne 0 ]; then
    abort "Execute as root or use sudo."
  fi

  if command -v sed >/dev/null 2>&1; then
    true
  else
    abort "sed command missing. Make sure sed is in your path."
  fi

  if command -v tar >/dev/null 2>&1; then
    true
  else
    abort "tar command missing. Make sure tar is in your path."
  fi
}

is_terminal() {
  if echo "$TERM"|grep -q "^xterm";then
    return 0
  else
    echo 1>&2 "You are not on a terminal. Please use command line switches to avoid interactive questions."
    return 1
  fi
}

update_tacoscript() {
  TACO_VERSION=$(/usr/local/bin/tacoscript --version|grep -o "Version:.*"|awk '{print $2}')
  cd /tmp
  test -e tacoscript.tar.gz&&rm -f tacoscript.tar.gz
  curl -LSso tacoscript.tar.gz "https://download.rport.io/tacoscript/${RELEASE}/?arch=Linux_${ARCH}&gt=$TACO_VERSION"
  if tar xzf tacoscript.tar.gz 2>/dev/null; then
    echo ""
    echo "Updating Tacoscript from ${TACO_VERSION} to latest ${RELEASE} $(./tacoscript --version|grep -o "Version:.*")"
    mv -f /tmp/tacoscript /usr/local/bin/tacoscript
  else
    echo "Nothing to do. Tacoscript is on the latest version ${TACO_VERSION}."
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_tacoscript
#   DESCRIPTION:  install Tacoscript on Linux
#----------------------------------------------------------------------------------------------------------------------
install_tacoscript() {
  if [ -e /usr/local/bin/tacoscript ]; then
    echo "Tacoscript already installed. Checking for updates ..."
    update_tacoscript
    return 0
  fi
  cd /tmp
  test -e tacoscript.tar.gz&&rm -f tacoscript.tar.gz
  curl -LJs "https://download.rport.io/tacoscript/${RELEASE}/?arch=Linux_${ARCH}" -o tacoscript.tar.gz
  tar xvzf tacoscript.tar.gz -C /usr/local/bin/ tacoscript
  rm -f tacoscript.tar.gz
  echo "Tacoscript installed $(/usr/local/bin/tacoscript --version)"
}

version_to_int() {
  echo "$1" | \
  awk -v 'maxsections=3' -F'.' 'NF < maxsections {printf("%s",$0);for(i=NF;i<maxsections;i++)printf("%s",".0");printf("\n")} NF >= maxsections {print}' | \
  awk -v 'maxdigits=3' -F'.' '{print $1*10^(maxdigits*2)+$2*10^(maxdigits)+$3}'
}

runs_with_selinux() {
  if command -v getenforce >/dev/null 2>&1 && getenforce|grep -q Enforcing;then
    return 0
  else
    return 1
  fi
}

enable_lan_monitoring() {
  if [ "$(version_to_int "$TARGET_VERSION")" -lt 5008 ];then
      # Version does not handle network interfaces yet.
      return 0
  fi
  if grep "^\s*net_[wl]" "$CONFIG_FILE";then
    # Network interfaces already configured
    return 0
  fi
  echo "Enabling Network monitoring"
  for IFACE in /sys/class/net/*;do
    IFACE=$(basename "${IFACE}")
    [ "$IFACE" = 'lo' ] && continue
    if ip addr show "$IFACE"|grep -E -q "inet (10|192\.168|172\.16)\.";then
      # Private IP
      NET_LAN="$IFACE"
    else
      # Public IP
      NET_WAN="$IFACE"
    fi
  done
  if [ -n "$NET_LAN" ]; then
    sed -i "/^\[monitoring\]/a \ \ net_lan = ['${NET_LAN}' , '1000' ]" "$CONFIG_FILE"
  fi
  if [ -n "$NET_WAN" ];then
    sed -i "/^\[monitoring\]/a \ \ net_wan = ['${NET_WAN}' , '1000' ]" "$CONFIG_FILE"
  fi
}

detect_interpreters() {
  if [ "$(version_to_int "$TARGET_VERSION")" -lt 5008 ];then
    # Version does not handle interpreters yet.
    return 0
  fi
  if grep -q "\[interpreter\-aliases\]" "$CONFIG_FILE"; then
    # Config already updated
    true
  else
    echo "Updating config with new interpreter-aliases ..."
    echo '[interpreter-aliases]' >>"$CONFIG_FILE"
  fi
  SEARCH="bash zsh ksh csh python3 python2 perl pwsh fish"
  for ITEM in $SEARCH;do
    FOUND=$(command -v "$ITEM" 2>/dev/null||true)
    if [ -z "$FOUND" ];then
      continue
    fi
    echo "Interpreter '$ITEM' found in '$FOUND'"
    if grep -q "$ITEM.*$FOUND" "$CONFIG_FILE";then
      echo "Interpreter '$ITEM = $FOUND' already registered."
      continue
    fi
    # Append the found interpreter to the config
    sed -i "/^\[interpreter-aliases\]/a \ \ $ITEM = \"$FOUND\"" "${CONFIG_FILE}"
  done
}