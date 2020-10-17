#!/bin/sh
###############################################################################################
# Description: This script will install vultr toolkit
# Author: Peter Winter
# Date: 12/01/2017
###############################################################################################
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
################################################################################################
################################################################################################

if ( [ "${1}" != "" ] )
then
    BUILDOS="${1}"
fi

if ( [ "${BUILDOS}" = "ubuntu" ] )
then
    if ( [ ! -f /usr/bin/vultr ] )
    then
        latest="`/usr/bin/curl https://github.com/JamesClonk/vultr/releases/latest | /bin/sed 's/.*tag\///g' | /bin/sed 's/\".*//g' | /bin/sed 's/v//g'`"
        /usr/bin/wget https://github.com/JamesClonk/vultr/releases/download/${latest}/vultr_linux_386.tar.gz
        /bin/tar xvfz ${HOME}/vultr_linux_386.tar.gz
        /bin/cp ${HOME}/vultr_linux_386/vultr /usr/bin
        /bin/rm -r ${HOME}/vultr_linux_386
        /bin/rm ${HOME}/vultr_linux_386.tar.gz
    fi
fi

if ( [ "${BUILDOS}" = "debian" ] )
then
    if ( [ ! -f /usr/bin/vultr ] )
    then
        latest="`/usr/bin/curl https://github.com/JamesClonk/vultr/releases/latest | /bin/sed 's/.*tag\///g' | /bin/sed 's/\".*//g' | /bin/sed 's/v//g'`"
        /usr/bin/wget https://github.com/JamesClonk/vultr/releases/download/${latest}/vultr_linux_386.tar.gz
        /bin/tar xvfz ${HOME}/vultr_linux_386.tar.gz
        /bin/cp ${HOME}/vultr_linux_386/vultr /usr/bin
        /bin/rm -r ${HOME}/vultr_linux_386
        /bin/rm ${HOME}/vultr_linux_386.tar.gz
    fi
fi
