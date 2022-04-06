set -e
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  prepare
#   DESCRIPTION:  Create a temporary folder and prepare the system to execute the installation
#----------------------------------------------------------------------------------------------------------------------
prepare() {
  test -e "${TMP_FOLDER}" && rm -rf "${TMP_FOLDER}"
  mkdir "${TMP_FOLDER}"
  cd "${TMP_FOLDER}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  cleanup
#   DESCRIPTION:  Remove the temporary folder and cleanup any leftovers after script has ended
#----------------------------------------------------------------------------------------------------------------------
clean_up() {
  cd /tmp
  rm -rf "${TMP_FOLDER}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  test_connection
#   DESCRIPTION:  Check if the RPort server is reachable or abort.
#----------------------------------------------------------------------------------------------------------------------
test_connection() {
  CONN_TEST=$(curl -vIs -m5 "${CONNECT_URL}" 2>&1)
  if echo "${CONN_TEST}"|grep -q "Connected to";then
    confirm "${CONNECT_URL} is reachable. All good."
  else
    echo "$CONN_TEST"
    echo ""
    echo "Testing the connection to the RPort server on ${CONNECT_URL} failed."
    echo "* Check your internet connection and firewall rules."
    echo "* Check if a transparent HTTP proxy is sniffing and blocking connections."
    echo "* Check if a virus scanner is inspecting HTTP connections."
    abort "FATAL: No connection to the RPort server."
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  download_and_extract
#   DESCRIPTION:  Download the package from Github and unpack to the temp folder
#                 https://downloads.rport.io/ acts a redirector service
#                 returning the real download URL of GitHub in a more handy fashion
#----------------------------------------------------------------------------------------------------------------------
download_and_extract() {
  cd "${TMP_FOLDER}"
  # Download the tar.gz package
  if is_available curl; then
    curl -LSs "https://downloads.rport.io/rport/${RELEASE}/latest.php?arch=Linux_${ARCH}" -o rport.tar.gz
  elif is_available wget; then
    wget -q "https://downloads.rport.io/rport/${RELEASE}/latest.php?arch=Linux_${ARCH}" -O rport.tar.gz
  else
    abort "No download tool found. Install curl or wget."
  fi
  # Unpack
  tar xzf rport.tar.gz
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_bin
#   DESCRIPTION:  Install a binary located in the temp folder to /usr/local/bin
#    PARAMETERS:  binary name relative to the temp folder
#----------------------------------------------------------------------------------------------------------------------
install_bin() {
  EXEC_BIN=/usr/local/bin/${1}
  if [ -e "$EXEC_BIN" ]; then
    if [ "$FORCE" -eq 0 ]; then
      abort "${EXEC_BIN} already exists. Use -f to overwrite."
    fi
  fi
  mv "${TMP_FOLDER}/${1}" "${EXEC_BIN}"
  confirm "${1} installed to ${EXEC_BIN}"
  TARGET_VERSION=$(${EXEC_BIN} --version |awk '{print $2}')
  confirm "RPort $TARGET_VERSION installed to $EXEC_BIN"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_config
#   DESCRIPTION:  Install an example config located in the temp folder to /etc/rport
#    PARAMETERS:  config name relative to the temp folder without suffix .example.conf
#----------------------------------------------------------------------------------------------------------------------
install_config() {
  test -e "$CONF_DIR" || mkdir "$CONF_DIR"
  CONFIG_FILE=${CONF_DIR}/${1}.conf
  if [ -e "${CONFIG_FILE}" ]; then
    mv "${CONFIG_FILE}" "${CONFIG_FILE}".bak
    confirm "Old config has been backed up to ${CONFIG_FILE}.bak"
  fi
  mv "${TMP_FOLDER}/rport.example.conf" "${CONFIG_FILE}"
  confirm "${CONFIG_FILE} created."
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_user
#   DESCRIPTION:  Create a system user "rport"
#----------------------------------------------------------------------------------------------------------------------
create_user() {
  confirm "RPort will run as user ${USER}"
  if id "${USER}" >/dev/null 2>&1; then
    confirm "User ${USER} already exist."
  else
    if is_available useradd; then
      useradd -r -d /var/lib/rport -m -s /bin/false -U -c "System user for rport client" $USER
    elif is_available adduser; then
      addgroup rport
      adduser -h /var/lib/rport -s /bin/false -G rport -S -D $USER
    else
      abort "No command found to add a user"
    fi
  fi
  test -e "$LOG_DIR" || mkdir -p "$LOG_DIR"
  test -e /var/lib/rport/scripts || mkdir -p /var/lib/rport/scripts
  chown "${USER}":root "$LOG_DIR"
  chown "${USER}":root /var/lib/rport/scripts
  chmod 0700 /var/lib/rport/scripts
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_systemd_service
#   DESCRIPTION:  Install a systemd service file
#----------------------------------------------------------------------------------------------------------------------
create_systemd_service() {
  echo "Installing systemd service for rport"
  test -e /etc/systemd/system/rport.service && rm -f /etc/systemd/system/rport.service
  /usr/local/bin/rport --service install --service-user "${USER}" --config /etc/rport/rport.conf
  if is_available systemctl; then
    systemctl daemon-reload
    systemctl start rport
    systemctl enable rport
  elif is_available service; then
    service rport start
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_openrc_service
#   DESCRIPTION:  Install a oprnrc service file
#----------------------------------------------------------------------------------------------------------------------
create_openrc_service() {
  echo "Installing openrc service for rport"
  cat << EOF >/etc/init.d/rport
#!/sbin/openrc-run
command="/usr/local/bin/rport"
command_args="-c /etc/rport/rport.conf"
command_user="${USER}"
command_background=true
pidfile=/var/run/rport.pid
EOF
  chmod 0755 /etc/init.d/rport
  rc-service rport start
  rc-update add rport default
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  prepare_server_cofnig
#   DESCRIPTION:  Make changes to the example config to give the user a better starting point
#----------------------------------------------------------------------------------------------------------------------
prepare_config() {
  echo "Preparing $CONFIG_FILE"
  sed -i "s|#*server = .*|server = \"${CONNECT_URL}\"|g" "$CONFIG_FILE"
  sed -i "s/#*auth = .*/auth = \"${CLIENT_ID}:${PASSWORD}\"/g" "$CONFIG_FILE"
  sed -i "s/#*fingerprint = .*/fingerprint = \"${FINGERPRINT}\"/g" "$CONFIG_FILE"
  sed -i "s/#*log_file = .*C.*Program Files.*/""/g" "$CONFIG_FILE"
  sed -i "s/#*log_file = /log_file = /g" "$CONFIG_FILE"
  sed -i "s|#updates_interval = '4h'|updates_interval = '4h'|g" "$CONFIG_FILE"
  if [ "$ENABLE_COMMANDS" -eq 1 ]; then
    sed -i "s/#allow = .*/allow = ['.*']/g" "$CONFIG_FILE"
    sed -i "s/#deny = .*/deny = []/g" "$CONFIG_FILE"
    sed -i '/^\[remote-scripts\]/a \ \ enabled = true' "$CONFIG_FILE"
    sed -i "s|# script_dir = '/var/lib/rport/scripts'|script_dir = '/var/lib/rport/scripts'|g" "$CONFIG_FILE"
  fi

  # Set the hostname.
  if grep -Eq "^use_hostname = true" "$CONFIG_FILE";then
    # For versions >= 0.5.9
    # Just insert an example.
    sed -i "s/#name = .*/#name = \"$(get_hostname)\"/g" "$CONFIG_FILE"
  else
    # Older versions
    # Insert a hardcoded name
    sed -i "s/#*name = .*/name = \"$(get_hostname)\"/g" "$CONFIG_FILE"
  fi

  # Set the machine_id
  if grep -Eq "^use_system_id = true" "$CONFIG_FILE" && [ -e /etc/machine-id ];then
    # Versions >= 0.5.9 read it dynamically
    echo "Using /etc/machine-id as rport client id"
  else
    # Older versions need a hard coded id
    sed -i "s/^use_hostname = true/use_hostname = false/g" "$CONFIG_FILE"
    sed -i "s/#id = .*/id = \"$(machine_id)\"/g" "$CONFIG_FILE"
  fi

  if get_geodata; then
    sed -i "s/#tags = .*/tags = ['$COUNTRY','$CITY']/g" "$CONFIG_FILE"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  get_hostname
#   DESCRIPTION:  Try to get the hostname from various sources
#----------------------------------------------------------------------------------------------------------------------
get_hostname() {
  hostname -f 2>/dev/null && return 0
  hostname 2>/dev/null && return 0
  cat /etc/hostname 2>/dev/null && return 0
  LANG=en hostnamectl | grep hostname | grep -v 'n/a' |cut -d':' -f2 | tr -d ' '
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  machine_id
#   DESCRIPTION:  Try to get a unique machine id form different locations.
#                 Generate one based on the hostname as a fallback.
#----------------------------------------------------------------------------------------------------------------------
machine_id() {
  if [ -e /etc/machine-id ]; then
    cat /etc/machine-id
    return 0
  fi

  if [ -e /var/lib/dbus/machine-id ]; then
    cat /var/lib/dbus/machine-id
    return 0
  fi

  alt_machine_id
}

alt_machine_id() {
  ip a | grep ether | md5sum | awk '{print $1}'
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_client
#   DESCRIPTION:  Execute all needed steps to install the rport client
#----------------------------------------------------------------------------------------------------------------------
install_client() {
  echo "Installing rport client"
  print_distro
  if runs_with_selinux && [ "$SELINUX_FORCE" -ne 1 ];then
    echo ""
    echo "Your system has SELinux enabled. This installer will not create the needed policies."
    echo "Rport will not connect with out the right policies."
    echo "Read more https://kb.rport.io/digging-deeper/advanced-client-management/run-with-selinux"
    echo "Excute '$0 ${RAW_ARGS} -l' to skip this warning and install anyways. You must create the polcies later."
    exit 1
  fi
  test_connection
  download_and_extract
  install_bin rport
  install_config rport
  prepare_config
  enable_lan_monitoring
  detect_interpreters
  create_user
  if is_available openrc; then
    create_openrc_service
  else
    create_systemd_service
  fi
  create_sudoers_updates
  [ "$ENABLE_SUDO" -eq 1 ] && create_sudoers_all
  [ "$INSTALL_TACO" -eq 1 ] && install_tacoscript
  verify_and_terminate
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  verify_and_terminate
#   DESCRIPTION:  Verify the installation has succeeded
#----------------------------------------------------------------------------------------------------------------------
verify_and_terminate() {
  sleep 1
  if pgrep rport >/dev/null 2>&1; then
    if check_log; then
      finish
      return 0
    elif [ $? -eq 1 ] && [ "$USE_ALTERNATIVE_MACHINEID" -ne 1 ]; then
      USE_ALTERNATIVE_MACHINEID=1
      use_alternative_machineid
      verify_and_terminate
      return 0
    fi
  fi
  fail
}

use_alternative_machineid() {
  # If the /etc/machine-id is already used, use an alternative unique id
  systemctl stop rport
  rm -f "$LOG_FILE"
  echo "Creating a unique id based on the mac addresses of the network cards."
  sed -i "s/^id = .*/id = \"$(alt_machine_id)\"/g" "$CONFIG_FILE"
  systemctl start rport
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  get_geodata
#   DESCRIPTION:  Retrieve the Country and the city of the currently used public IP address
#----------------------------------------------------------------------------------------------------------------------
get_geodata() {
  GEODATA=""
  GEOSERVICE_URL="http://ip-api.com/line/?fields=status,country,city"
  if is_available curl; then
    GEODATA=$(curl -m2 -Ss "${GEOSERVICE_URL}" 2>/dev/null)
  else
    GEODATA=$(wget --timeout=2 -O - -q "${GEOSERVICE_URL}" 2>/dev/null)
  fi
  if echo "$GEODATA" | grep -q "^success"; then
    CITY="$(echo "$GEODATA" | head -n3 | tail -n1)"
    COUNTRY="$(echo "$GEODATA" | head -n2 | tail -n1)"
    GEODATA="1"
    return 0
  else
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  check_log
#   DESCRIPTION:  Check the log file for proper operation or common errors
#----------------------------------------------------------------------------------------------------------------------
check_log() {
  if [ -e "$LOG_FILE" ];then
    true
  else
    echo 2>&1 "[!] Logfile $LOG_FILE does not exist."
    echo 2>&1 "[!] RPOrt very likely failed to start."
    return 4
  fi
  if grep -q "client id .* is already in use" "$LOG_FILE"; then
    echo ""
    echo 2>&1 "[!] Configuration error: client id is already in use."
    echo 2>&1 "[!] Likely you have systems with an duplicated machine-id in your network."
    echo ""
    return 1
  elif grep -q "Connection error: websocket: bad handshake" "$LOG_FILE"; then
    echo ""
    echo 2>&1 "[!] Connection error: websocket: bad handshake"
    echo "Check if transparent proxies are interfering outgoing http connections."
    return 2
  elif tac "$LOG_FILE" | grep error; then
    return 3
  fi

  return 0
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  help
#   DESCRIPTION:  print a help message and exit
#----------------------------------------------------------------------------------------------------------------------
help() {
  cat <<EOF
Usage $0 [OPTION(s)]

Options:
-h  Print this help message.
-f  Force  overwriting existing files and configurations.
-t  Use the latest unstable version (DANGEROUS!).
-u  Uninstall the rport client and all configurations and logs.
-x  Enable unrestricted command execution in rport.conf.
-s  Create sudo rules to grant full root access to the rport user.
-a  Use a different user account than 'rport'. Will be created if not present.
-i  Install Tacoscript along with the RPort client.
-l  Install with SELinux enabled.
EOF
  exit 0
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  finish
#   DESCRIPTION:  print some information
#----------------------------------------------------------------------------------------------------------------------
finish() {
  echo "
#
#  Installation of rport finished.
#
#  This client is now connected to $SERVER
#
#  Look at $CONFIG_FILE and explore all options.
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
  echo "
#
# -------------!!   ERROR  !!-------------
#
# Installation of rport finished with errors.
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

#----------------------------------------------------------------------------------------------------------------------
#                                               END OF FUNCTION DECLARATION
#----------------------------------------------------------------------------------------------------------------------

#
# Check for prerequisites
#
check_prerequisites

MANDATORY="SERVER FINGERPRINT CLIENT_ID PASSWORD"
for VAR in $MANDATORY; do
  if eval "[ -z $${VAR} ]"; then
    abort "Variable \$${VAR} not set."
  fi
done

#
# Read the command line options and map to a function call
#
RAW_ARGS=$*
ACTION=install_client
ENABLE_COMMANDS=0
ENABLE_SUDO=0
RELEASE=stable
INSTALL_TACO=0
SELINUX_FORCE=0
while getopts 'hvfcsuxstila:' opt; do
  case "${opt}" in

  h) help ; exit 0 ;;
  f) FORCE=1 ;;
  v)
    echo "$0 -- Version $VERSION"
    exit 0
    ;;
  c) ACTION=install_client ;;
  u) ACTION=uninstall ;;
  x) ENABLE_COMMANDS=1 ;;
  s) ENABLE_SUDO=1 ;;
  t) RELEASE=unstable ;;
  i) INSTALL_TACO=1;;
  l) SELINUX_FORCE=1;;
  # Execute a single function. For dev and debug only  #
  a) USER=${OPTARG} ;;

  \?)
    echo "Option does not exist."
    exit 1
    ;;
  esac # --- end of case ---
done
shift $((OPTIND - 1))
prepare  # Prepare the system
$ACTION  # Execute the function according to the users decision
clean_up # Clean up the system
