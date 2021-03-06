#!/bin/sh
####################################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script gets a list of server ip addresses based on a name/type
####################################################################################
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
#######################################################################################
#######################################################################################
#set -x

server_type="${1}"
cloudhost="${2}"

if ( [ -f ${HOME}/DROPLET ] || [ "${cloudhost}" = "digitalocean" ] )
then
    ip="`/usr/local/bin/doctl compute droplet list | /bin/grep ${server_type} | /usr/bin/awk '{print $4}'`"
    count="0"

    while ( [ "${ip}" = "" ] && [ "${count}" -lt "10" ] )
    do
        /bin/echo "${0} `/bin/date` : failed in an attempt to get server ip address, trying again ...." >> ${HOME}/logs/MonitoringLog.log
        ip="`/usr/local/bin/doctl compute droplet list | /bin/grep ${server_type} | /usr/bin/awk '{print $4}'`"
        count="`/usr/bin/expr ${count} + 1`"
        /bin/sleep 5
    done
    if ( [ "${count}" -eq "10" ] )
    then
        /bin/echo "${0} `/bin/date` : failed in an attempt to get server ip address too many times, giving up ...." >> ${HOME}/logs/MonitoringLog.log
    else
        /bin/echo "${ip}"
    fi
fi

if ( [ -f ${HOME}/EXOSCALE ] || [ "${cloudhost}" = "exoscale" ] )
then
    /usr/local/bin/cs listVirtualMachines | /usr/bin/jq '.virtualmachine[] | .nic[].ipaddress + " " + .displayname' | /bin/grep ".*${server_type}" | /bin/sed 's/"//g' | /usr/bin/awk '{print $1}'
fi

if ( [ -f ${HOME}/LINODE ] || [ "${cloudhost}" = "linode" ] )
then
   /usr/local/bin/linode-cli linodes list --text | /bin/grep ${server_type} | /bin/grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | /bin/grep "192.168"
fi

if ( [ -f ${HOME}/VULTR ] || [ "${cloudhost}" = "vultr" ] )
then
    export VULTR_API_KEY="`/bin/ls ${HOME}/.ssh/VULTRAPIKEY:* | /usr/bin/awk -F':' '{print $NF}'`"
    /bin/sleep 1
    server_type="`/bin/echo ${server_type} | /usr/bin/cut -c -25`"
    ids="`/usr/bin/vultr server list | /bin/grep ${server_type} | /usr/bin/awk '{print $1}' | /bin/sed 's/SUBID//g' | /bin/sed '/^$/d'`"
    for id in ${ids}
    do
        /bin/sleep 1
        /usr/bin/vultr server list-ipv4 ${id} | /bin/grep '^10\.' | /usr/bin/awk '{print $1}'
    done
fi

if ( [ -f ${HOME}/AWS ] || [ "${cloudhost}" = "aws" ] )
then 
    /usr/bin/aws ec2 describe-instances --filter "Name=tag:descriptiveName,Values=${server_type}*" "Name=instance-state-name,Values=running" | /usr/bin/jq '.Reservations[].Instances[].PrivateIpAddress' | /bin/sed 's/\"//g'
fi

