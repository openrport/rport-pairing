set -e
if which tput >/dev/null 2>&1; then
    true
else
    alias tput=true
fi

throw_fatal() {
    echo 2>&1 "[!] $1"
    echo "[=] Fatal Exit. Don't give up. Good luck with the next try."
    false
}

throw_hint() {
    echo "[>] $1"
}

throw_info() {
    echo "$(tput setab 2 2>/dev/null)$(tput setaf 7 2>/dev/null)[*]$(tput sgr 0 2>/dev/null) $1"
}

throw_warning() {
    echo "[:] $1"
}

throw_debug() {
    echo "$(tput setab 4 2>/dev/null)$(tput setaf 7 2>/dev/null)[-]$(tput sgr 0 2>/dev/null) $1"
}

wait_for_rport() {
    i=0
    while [ "$i" -lt 40 ]; do
        pidof rport >/dev/null 2>&1 && return 0
        echo "$i waiting for rport process to come up ..."
        sleep 0.2
        i=$((i + 1))
    done
    return 1
}

is_rport_subprocess() {
    if [ -n "$1" ]; then
        SEARCH_PID=$1
    else
        SEARCH_PID=$$
    fi
    PARENT_PID=$(ps -o ppid= -p "$SEARCH_PID" | tr -d ' ')
    PARENT_NAME=$(ps -p "$PARENT_PID" -o comm=)
    if [ "$PARENT_NAME" = "rport" ]; then
        return 0
    elif [ "$PARENT_PID" -eq 1 ]; then
        return 1
    fi
    is_rport_subprocess "$PARENT_PID"
}
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
  stop_rport >/dev/null 2>&1 || true
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
    /etc/runlevels/default/rport
    /etc/apt/sources.list.d/rport.list"
  for FILE in $FILES; do
    if [ -e "$FILE" ]; then
      rm -f "$FILE" && echo " [ DELETED ] File $FILE"
    fi
  done
  if id rport >/dev/null 2>&1; then
    if is_available deluser; then
      deluser --remove-home rport >/dev/null 2>&1 || true
      deluser --only-if-empty --group rport >/dev/null 2>&1 || true
    elif is_available userdel; then
      userdel -r -f rport >/dev/null 2>&1
    fi
    if is_available groupdel; then
      groupdel -f rport >/dev/null 2>&1 || true
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
  if dpkg -l 2>&1 | grep -q "rport.*Remote access"; then
      apt-get -y remove --purge rport
  fi
  echo "RPort client successfully uninstalled."
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  print_distro
#   DESCRIPTION:  print name of the distro
#----------------------------------------------------------------------------------------------------------------------
print_distro() {
  if [ -e /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release 2>/dev/null || true
    echo "Detected Linux Distribution: ${PRETTY_NAME}"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  has_sudo
#   DESCRIPTION:  Check if sudo is installed and sudo rules can be managed as separated files
#       RETURNS:  0 (success,  sudo os present), 1 (fail, sudo can't be used by rport)
#----------------------------------------------------------------------------------------------------------------------
has_sudo() {
  if ! which sudo >/dev/null 2>&1; then
    return 1
  fi
  if [ -e /etc/sudoers.d/ ]; then
    return 0
  fi
  return 1
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_sudoers_all
#   DESCRIPTION:  create a sudoers file to grant full sudo right to the rport user
#----------------------------------------------------------------------------------------------------------------------
create_sudoers_all() {
  SUDOERS_FILE=/etc/sudoers.d/rport-all-cmd
  if [ -e "$SUDOERS_FILE" ]; then
    throw_info "You already have a $SUDOERS_FILE. Not changing."
    return 1
  fi

  if has_sudo; then
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
    throw_info "You already have a $SUDOERS_FILE. Not changing."
    return 0
  fi

  if has_sudo; then
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
  if echo "$TERM" | grep -q "^xterm"; then
    return 0
  else
    echo 1>&2 "You are not on a terminal. Please use command line switches to avoid interactive questions."
    return 1
  fi
}

update_tacoscript() {
  TACO_VERSION=$(/usr/local/bin/tacoscript --version | grep -o "Version:.*" | awk '{print $2}')
  cd /tmp
  test -e tacoscript.tar.gz && rm -f tacoscript.tar.gz
  curl -LSso tacoscript.tar.gz "https://download.openrport.io/tacoscript/${RELEASE}/?arch=Linux_${ARCH}&gt=$TACO_VERSION"
  if tar xzf tacoscript.tar.gz 2>/dev/null; then
    echo ""
    throw_info "Updating Tacoscript from ${TACO_VERSION} to latest ${RELEASE} $(./tacoscript --version | grep -o "Version:.*")"
    mv -f /tmp/tacoscript /usr/local/bin/tacoscript
  else
    throw_info "Nothing to do. Tacoscript is on the latest version ${TACO_VERSION}."
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_tacoscript
#   DESCRIPTION:  install Tacoscript on Linux
#----------------------------------------------------------------------------------------------------------------------
install_tacoscript() {
  if [ -e /usr/local/bin/tacoscript ]; then
    throw_info "Tacoscript already installed. Checking for updates ..."
    update_tacoscript
    return 0
  fi
  cd /tmp
  test -e tacoscript.tar.gz && rm -f tacoscript.tar.gz
  curl -Ls "https://download.openrport.io/tacoscript/${RELEASE}/?arch=Linux_${ARCH}" -o tacoscript.tar.gz
  tar xvzf tacoscript.tar.gz -C /usr/local/bin/ tacoscript
  rm -f tacoscript.tar.gz
  echo "Tacoscript installed $(/usr/local/bin/tacoscript --version)"
}

version_to_int() {
  echo "$1" |
    awk -v 'maxsections=3' -F'.' 'NF < maxsections {printf("%s",$0);for(i=NF;i<maxsections;i++)printf("%s",".0");printf("\n")} NF >= maxsections {print}' |
    awk -v 'maxdigits=3' -F'.' '{print $1*10^(maxdigits*2)+$2*10^(maxdigits)+$3}'
}

runs_with_selinux() {
  if command -v getenforce >/dev/null 2>&1 && getenforce | grep -q Enforcing; then
    return 0
  else
    return 1
  fi
}

enable_file_reception() {
  if [ "$(version_to_int "$TARGET_VERSION")" -lt 6005 ]; then
    # Version does not handle file reception yet.
    return 0
  fi
  if [ "$ENABLE_FILEREC" -eq 0 ]; then
    echo "File reception disabled."
    FILEREC_CONF="false"
  else
    echo "File reception enabled."
    FILEREC_CONF="true"
  fi
  if grep -q '\[file-reception\]' "$CONFIG_FILE"; then
    echo "File reception already configured"
  else
    cat <<EOF >>"$CONFIG_FILE"


[file-reception]
  ## Receive files pushed by the server, enabled by default
  # enabled = true
  ## The rport client will reject writing files to any of the following folders and its subfolders.
  ## https://oss.openrport.io/docs/no18-file-reception.html
  ## Wildcards (glob) are supported.
  ## Linux defaults
  # protected = ['/bin', '/sbin', '/boot', '/usr/bin', '/usr/sbin', '/dev', '/lib*', '/run']
  ## Windows defaults
  # protected = ['C:\Windows\', 'C:\ProgramData']

EOF
  fi
  toml_set "$CONFIG_FILE" file-reception enabled $FILEREC_CONF
  # Clean up from pre-releases
  test -e /etc/sudoers.d/rport-filepush && rm -f /etc/sudoers.d/rport-filepush
  if [ "$ENABLE_FILEREC_SUDO" -eq 0 ]; then
    # File receptions sudo rules not desired, end this function here
    return 0
  fi
  # Create a sudoers file
  FILERCV_SUDO="/etc/sudoers.d/rport-filereception"
  if [ -e $FILERCV_SUDO ]; then
    echo "Sudo rule $FILERCV_SUDO already exists"
  else
    cat <<EOF >$FILERCV_SUDO
# The following rule allows the rport client to change the ownership of any file retrieved from the rport server
rport ALL=NOPASSWD: /usr/bin/chown * /var/lib/rport/filepush/*_rport_filepush

# The following rules allows the rport client to move copied files to any folder
rport ALL=NOPASSWD: /usr/bin/mv /var/lib/rport/filepush/*_rport_filepush *

EOF
  fi
}

enable_lan_monitoring() {
  if [ "$(version_to_int "$TARGET_VERSION")" -lt 5008 ]; then
    # Version does not handle network interfaces yet.
    return 0
  fi
  if grep "^\s*net_[wl]" "$CONFIG_FILE"; then
    # Network interfaces already configured
    return 0
  fi
  echo "Enabling Network monitoring"
  for IFACE in /sys/class/net/*; do
    IFACE=$(basename "${IFACE}")
    [ "$IFACE" = 'lo' ] && continue
    if ip addr show "$IFACE" | grep -E -q "inet (10|192\.168|172\.16)\."; then
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
  if [ -n "$NET_WAN" ]; then
    sed -i "/^\[monitoring\]/a \ \ net_wan = ['${NET_WAN}' , '1000' ]" "$CONFIG_FILE"
  fi
}

detect_interpreters() {
  if [ "$(version_to_int "$TARGET_VERSION")" -lt 5008 ]; then
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
  for ITEM in $SEARCH; do
    FOUND=$(command -v "$ITEM" 2>/dev/null || true)
    if [ -z "$FOUND" ]; then
      continue
    fi
    echo "Interpreter '$ITEM' found in '$FOUND'"
    if grep -q -E "^\s*$ITEM =" "$CONFIG_FILE"; then
      echo "Interpreter '$ITEM' already registered."
      continue
    fi
    # Append the found interpreter to the config
    sed -i "/^\[interpreter-aliases\]/a \ \ $ITEM = \"$FOUND\"" "${CONFIG_FILE}"
  done
}

toml_set() {
  TOML_FILE="$1"
  BLOCK="$2"
  KEY="$3"
  VALUE="$4"
  if [ -w "$TOML_FILE" ]; then
    true
  else
    echo 2>&1 "$TOML_FILE does not exist or is not writable."
    return 1
  fi
  if grep -q "\[$BLOCK\]" "$TOML_FILE"; then
    true
  else
    echo 2>&1 "$TOML_FILE has no block [$BLOCK]"
    return 1
  fi
  LINE=$(grep -n -A100 "\[$BLOCK\]" "$TOML_FILE" | grep "${KEY} = ")
  if [ -z "$LINE" ]; then
    echo 2>&1 "Key $KEY not found in block $BLOCK"
    return 1
  fi
  LINE_NO=$(echo "$LINE" | cut -d'-' -f1)
  sed -i "${LINE_NO}s/.*/  ${KEY} = ${VALUE}/" "$TOML_FILE"
}

gen_uuid() {
  if [ -e /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
    return 0
  fi
  if which uuidgen >/dev/null 2>&1; then
    uuidgen
    return 0
  fi
  if which dbus-uuidgen >/dev/null 2>&1; then
    dbus-uuidgen
    return 0
  fi
  # Use a internet-based fallback
  curl -s https://www.uuidtools.com/api/generate/v4 | tr -d '"[]'
}

get_ip_from_fqdn() {
  if which getent >/dev/null; then
    getent hosts "$1" | awk '{ print $1 }'
    return 0
  fi
  ping "$1" -c 1 -q 2>&1 | grep -Po "(\d{1,3}\.){3}\d{1,3}"
}

start_rport() {
  if is_available systemctl; then
    systemctl daemon-reload
    systemctl start rport
    systemctl enable rport
  elif [ -e /etc/init/rport.conf ]; then
    # We are on an upstart system
    start rport
  elif is_available service; then
    service rport start
  fi
  if pidof rport >/dev/null 2>&1; then
      return 0
  else
      return 1
  fi
}

stop_rport() {
  if is_available systemctl; then
    systemctl stop rport
  elif [ -e /etc/init/rport.conf ]; then
    # We are on an upstart system
    stop rport
  elif is_available service; then
    service rport stop
  fi
}

backup_config() {
    if [ -z "$CONFIG_FILE" ]; then
        throw_fatal "backup_config() \$CONFIG_FILE undefined."
    fi
    CONFIG_BACKUP="/tmp/.rport-conf.$(date +%s)"
    cp "$CONFIG_FILE" "$CONFIG_BACKUP"
    throw_debug "Configuration file copied to $CONFIG_BACKUP"
}

clean_up_legacy_installation() {
    # If this is a migration from the old none deb-based installation, clean up
    if [ -e /etc/systemd/system/rport.service ]; then
        throw_info "Removing old systemd service /etc/systemd/system/rport.service"
        rm -f /etc/systemd/system/rport.service
        systemctl daemon-reload
    fi
    if [ -e /usr/local/bin/rport ]; then
        throw_info "Removing old version /usr/local/bin/rport"
        rm -f /usr/local/bin/rport
    fi
}

install_via_deb_repo() {
    if [ -z "$RELEASE" ]; then
        throw_fatal "install_via_deb_repo() \$RELEASE undefined"
    fi
    validate_custom_user
    if [ -e /etc/apt/trusted.gpg.d/rport.gpg ] && dpkg -l | grep -q rport; then
        throw_info "System is already using the rport deb repo."
    else
        throw_info "RPort will use Debian package ..."
        # shellcheck source=/dev/null
        . /etc/os-release
        if [ -n "$UBUNTU_CODENAME" ]; then
            CODENAME=$UBUNTU_CODENAME
        else
            CODENAME=$VERSION_CODENAME
        fi
        curl -sf https://repo.openrport.io/dearmor.gpg >/etc/apt/trusted.gpg.d/openrport.gpg
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/openrport.gpg] https://repo.openrport.io/deb ${CODENAME} ${RELEASE}" >/etc/apt/sources.list.d/rport.list
    fi
    apt-get update
    if dpkg -s rport >/dev/null 2>&1 && ! [ -e /etc/rport/rport.conf ]; then
        throw_warning "Broken DEB package installation found."
        throw_debug "Will remove old package first."
        apt-get -y --purge remove rport
    fi
    DEBIAN_FRONTEND=noninteractive apt-get --yes -o Dpkg::Options::="--force-confold" install rport
    TARGET_VERSION=$(rport --version | cut -d" " -f2)
    clean_up_legacy_installation
}

install_via_rpm_repo() {
    if [ -z "$RELEASE" ]; then
        throw_fatal "install_via_rpm_repo() \$RELEASE undefined"
    fi
    validate_custom_user
    if [ -e /etc/yum.repos.d/openrport.repo ] && rpm -qa | grep -q rport; then
        throw_info "System is already using the rport yum repo."
    else
        throw_info "RPort will use RPM package ..."
        rpm --import https://repo.openrport.io/key.gpg
        cat <<EOF >/etc/yum.repos.d/rport.repo
[rport-stable]
name=RPort $RELEASE
baseurl=https://repo.openrport.io/rpm/$RELEASE/
enabled=1
gpgcheck=1
gpgkey=https://repo.openrport.io/key.gpg
EOF
    fi
    dnf -y install rport --refresh
    TARGET_VERSION=$(rport --version | cut -d" " -f2)
    clean_up_legacy_installation
}

validate_custom_user() {
    if [ "$USER" != "rport" ]; then
        throw_fatal "RPM/DEB packages cannot be used with a custom user. Try '-p'"
    fi
}

# Check if it's a supported debian system
is_debian() {
    if [ "$NO_REPO" -eq 1 ]; then
        return 1
    fi
    if which apt-get >/dev/null 2>&1 && test -e /etc/apt/sources.list.d/; then
        true
    else
        return 1
    fi
    DIST_SUPPORTED="jammy focal bionic bullseye buster bookworm"
    for DIST in $DIST_SUPPORTED; do
        if grep -qi "CODENAME.*$DIST" /etc/os-release; then
            return 0
        fi
    done
    return 1
}

is_rhel() {
    if [ "$NO_REPO" -eq 1 ]; then
        return 1
    fi
    if grep -q "VERSION=.[6-7]" /etc/os-release; then
        throw_info "RHEL/CentOS too old for RPM installation. Switching to tar.gz package."
        return 1
    fi

    if which rpm >/dev/null 2>&1 && test -e /etc/yum.repos.d; then
        return 0
    fi
    return 1
}

validate_pkg_url() {
    if echo "${PKG_URL}" | grep -q -E "https*:\/\/.*_linux_$(uname -m)\.(tar\.gz|deb|rpm)$"; then
        true
    else
        throw_fatal "Invalid PKG_URL '$PKG_URL'."
    fi
}

download_pkg_url() {
    DL_AUTH=""
    if [ -n "$RPORT_INSTALLER_DL_USERNAME" ] && [ -n "$RPORT_INSTALLER_DL_PASSWORD" ]; then
        DL_AUTH="-u ${RPORT_INSTALLER_DL_USERNAME}:${RPORT_INSTALLER_DL_PASSWORD}"
        throw_info "Download will use HTTP basic authentication"
    fi
    throw_info "Downloading from ${PKG_URL} ..."
    PKG_DOWNLOAD=$(mktemp)
    # shellcheck disable=SC2086
    curl -LSs "${PKG_URL}" ${DL_AUTH} >${PKG_DOWNLOAD}
    if [ -n "$(find "${PKG_DOWNLOAD}" -empty)" ]; then
        rm -f "${PKG_DOWNLOAD}"
        throw_fatal "Download to ${PKG_DOWNLOAD} failed"
    fi
    throw_info "Download to ${PKG_DOWNLOAD} completed"
}

install_from_deb_download() {
    validate_pkg_url
    if echo "${PKG_URL}" | grep -q "deb$"; then
        true
    else
        throw_fatal "URL not pointing to a debian package"
    fi
    download_pkg_url
    mv "${PKG_DOWNLOAD}" "${PKG_DOWNLOAD}".deb
    PKG_DOWNLOAD=${PKG_DOWNLOAD}.deb
    chmod 0644 "${PKG_DOWNLOAD}"
    throw_info "Installing debian package ${PKG_DOWNLOAD}"
    DEBIAN_FRONTEND=noninteractive apt-get --yes -o Dpkg::Options::="--force-confold" install "${PKG_DOWNLOAD}"
    rm -f "${PKG_DOWNLOAD}"
    clean_up_legacy_installation
}

install_from_rpm_download() {
    validate_pkg_url
    if echo "${PKG_URL}" | grep -q "rpm$"; then
        true
    else
        throw_fatal "URL not pointing to an rpm package"
    fi
    download_pkg_url
    throw_info "Installing rpm package"
    rpm -U "${PKG_DOWNLOAD}"
    rm -f "${PKG_DOWNLOAD}"
    clean_up_legacy_installation
}

abort_on_rport_subprocess() {
    if is_rport_subprocess; then
        throw_hint "Execute the rport update in a process decoupled from its parent, e.g."
        throw_hint '  nohup sh -c "curl -s https://pairing.openrport.io/update|sh" >/tmp/rport-update.log 2>&1 &'
        throw_fatal "You cannot update rport from an rport subprocess."
    fi
}
