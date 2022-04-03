#
# Dynamically inserted variables
#
FINGERPRINT="{{ .Fingerprint}}"
CONNECT_URL="{{ .ConnectUrl}}"
CLIENT_ID="{{ .ClientId}}"
PASSWORD="{{ .Password}}"

#
# Global Variables
#
ARCH=$(uname -m | sed s/"armv\(6\|7\)l"/'armv\1'/ | sed s/aarch64/arm64/)
TMP_FOLDER=/tmp/rport-install
CONF_DIR=/etc/rport
LOG_DIR=/var/log/rport
FORCE=1
USE_ALTERNATIVE_MACHINEID=0
LOG_FILE=${LOG_DIR}/rport.log
CONFIG_FILE=${CONF_DIR}/rport.conf
USER=rport