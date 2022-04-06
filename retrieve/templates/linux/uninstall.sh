#!/bin/sh
#======================================================================================================================
# vim: softtabstop=4 shiftwidth=4 expandtab fenc=utf-8 spell spelllang=en cc=120
#======================================================================================================================
#
#          FILE: rport-client-uninstaller.sh
#
#   DESCRIPTION: Rport removal for various systems/distributions
#
#          BUGS: https://github.com/cloudradar-monitoring/rport/issues
#
#     COPYRIGHT: (c) 2021 by the CloudRadar Team,
#
#       LICENSE: MIT
#  ORGANIZATION: cloudradar GmbH, Potsdam, Germany (cloudradar.io)
#       CREATED: 30/09/2021
#======================================================================================================================

echo " Uninstall the RPort client"

# INCLUDE functions.sh

uninstall
echo " [ FINISH  ] RPort client removed."
echo ""
echo "#"
echo "# If you dislike RPort, please share your feedback on "
echo "# https://github.com/cloudradar-monitoring/rport/discussions/categories/general "
echo "# "