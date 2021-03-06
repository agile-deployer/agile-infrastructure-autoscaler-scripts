#!/bin/sh
#####################################################################################################################################
#Description: This script monitors for new SSL certificates which are generated on the webservers when needed. This will be the
#case if an old certificate has expired and a new one has been issued. We keep a copy of the certificate on the autoscaler so
#that when new webservers are built as part of an autoscaling event, they are passed a valid certificate.
#Date: 10-11-2016
#Author: Peter Winter
########################################################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################################################
#######################################################################################################
#set -x

SERVER_USER_PASSWORD="`/bin/ls ${HOME}/.ssh/SERVERUSERPASSWORD:* | /usr/bin/awk -F':' '{print $NF}'`"
WEBSITE_URL="`/bin/ls ${HOME}/.ssh/WEBSITEURL:* | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "`/usr/bin/diff ${HOME}/config/ssl/fullchain.pem ${HOME}/.ssh/fullchain.pem`" != "" ] ||
    [ "`/usr/bin/diff ${HOME}/config/ssl/privkey.pem ${HOME}/.ssh/privkey.pem`" != "" ] ||
[ "`/usr/bin/diff ${HOME}/config/ssl/${WEBSITE_URL}.json ${HOME}/.ssh/${WEBSITE_URL}.json`" != "" ] )
then
    /bin/mv ${HOME}/.ssh/privkey.pem ${HOME}/.ssh/privkey.pem.previous.`/bin/date | /bin/sed 's/ //g'`
    /bin/mv ${HOME}/.ssh/fullchain.pem ${HOME}/.ssh/fullchain.pem.previous.`/bin/date | /bin/sed 's/ //g'`
    /bin/mv ${HOME}/.ssh/${WEBSITE_URL}.json ${HOME}/.ssh/${WEBSITE_URL}.json.previous.`/bin/date | /bin/sed 's/ //g'`

    /bin/cp ${HOME}/config/ssl/privkey.pem ${HOME}/.ssh/privkey.pem
    /bin/cp ${HOME}/config/ssl/fullchain.pem ${HOME}/.ssh/fullchain.pem
    /bin/cp ${HOME}/config/ssl/${WEBSITE_URL}.json ${HOME}/.ssh/${WEBSITE_URL}.json

    /bin/chmod 400 ${HOME}/.ssh/privkey.pem
    /bin/chmod 400 ${HOME}/.ssh/fullchain.pem
    /bin/chmod 400 ${HOME}/.ssh/${WEBSITE_URL}.json
fi

