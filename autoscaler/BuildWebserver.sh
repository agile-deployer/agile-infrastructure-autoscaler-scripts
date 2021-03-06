#!/bin/sh
############################################################################################
# Author: Peter Winter
# Date  : 04/07/2016
# Description : This script will build a webserver from scratch as part of an autoscaling event
# It depends on the provider scripts and will build according to the provider it is configured for
# If we are configured to use snapshots, then the build will be completed using a snapshot (which
# must exist) otherwise, we perform a vanilla build of our webserver from scratch.
# The advantage of building from snapshots is they are quicker to build which may or many not be
# an issue depending on how responsive you want your application to be
##############################################################################################
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
#############################################################################################
#############################################################################################
set -x

#If we are trying to build a webserver before the toolkit has been fully installed, we don't want to do anything, so exit
if ( [ ! -f ${HOME}/config/INSTALLEDSUCCESSFULLY ] )
then
    exit
fi

SERVER_USER="`/bin/ls ${HOME}/.ssh/SERVERUSER:* | /usr/bin/awk -F':' '{print $NF}'`"
SERVER_USER_PASSWORD="`/bin/ls ${HOME}/.ssh/SERVERUSERPASSWORD:* | /usr/bin/awk -F':' '{print $NF}'`"

DEFAULT_USER="`/bin/ls ${HOME}/.ssh/DEFAULTUSER:* | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${DEFAULT_USER}" = "root" ] )
then
    SUDO="DEBIAN_FRONTEND=noninteractive /bin/echo ${SERVER_USER_PASSWORD} | /usr/bin/sudo -S -E "
else
    SUDO="DEBIAN_FRONTEND=noninteractive /usr/bin/sudo -S -E "
fi
CUSTOM_USER_SUDO="DEBIAN_FRONTEND=noninteractive /bin/echo ${SERVER_USER_PASSWORD} | /usr/bin/sudo -S -E "
OPTIONS=" -o ConnectTimeout=10 -o ConnectionAttempts=10 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "

#The log files for the server build are written here...
LOG_FILE="webserver_out_`/bin/date | /bin/sed 's/ //g'`"
exec 1>>${HOME}/logs/${LOG_FILE}
ERR_FILE="webserver_err_`/bin/date | /bin/sed 's/ //g'`"
exec 2>>${HOME}/logs/${ERR_FILE}

#Check there is a directory for logging
if ( [ ! -d ${HOME}/logs ] )
then
    /bin/mkdir -p ${HOME}/logs
fi

DONE="0"
ip=""
TRIES=0

#Pull the configuration into memory for easy access
KEY_ID="`/bin/ls ${HOME}/.ssh/KEYID:* | /usr/bin/awk -F':' '{print $NF}'`"
BUILD_CHOICE="`/bin/ls ${HOME}/.ssh/BUILDCHOICE:* | /usr/bin/awk -F':' '{print $NF}'`"
REGION="`/bin/ls ${HOME}/.ssh/REGION:* | /usr/bin/awk -F':' '{print $NF}'`"
SIZE="`/bin/ls ${HOME}/.ssh/SIZE:* | /usr/bin/awk -F':' '{print $NF}'`"
BUILD_IDENTIFIER="`/bin/ls ${HOME}/.ssh/BUILDIDENTIFIER:* | /usr/bin/awk -F':' '{print $NF}'`"
CLOUDHOST="`/bin/ls ${HOME}/.ssh/CLOUDHOST:* | /usr/bin/awk -F':' '{print $NF}'`"
ALGORITHM="`/bin/ls ${HOME}/.ssh/ALGORITHM:* | /usr/bin/awk -F':' '{print $NF}'`"
WEBSITE_URL="`/bin/ls ${HOME}/.ssh/WEBSITEURL:* | /usr/bin/awk -F':' '{print $NF}'`"
WEBSITE_NAME="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{print $2}'`"
z="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{$1=""}1' | /bin/sed 's/^ //g' | /bin/sed 's/ /./g'`"
name="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{print $1}'`"
WEBSITE_DISPLAY_NAME="`/bin/ls ${HOME}/.ssh/WEBSITEDISPLAYNAME:* | /bin/sed 's/_/ /g' | /usr/bin/awk -F':' '{print $NF}'`"
DNS_CHOICE="`/bin/ls ${HOME}/.ssh/DNSCHOICE:* | /usr/bin/awk -F':' '{print $NF}'`"
DNS_SECURITY_KEY="`/bin/ls ${HOME}/.ssh/DNSSECURITYKEY:* | /usr/bin/awk -F':' '{print $NF}'`"
DNS_USERNAME="`/bin/ls ${HOME}/.ssh/DNSUSERNAME:* | /usr/bin/awk -F':' '{print $NF}'`"
GIT_USER="`/bin/ls ${HOME}/.ssh/GITUSER:* | /usr/bin/awk -F':' '{print $NF}'`"
GIT_EMAIL_ADDRESS="`/bin/ls ${HOME}/.ssh/GITEMAILADDRESS:* | /usr/bin/awk -F':' '{print $NF}'`"

INFRASTRUCTURE_REPOSITORY_PROVIDER="`/bin/ls ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYPROVIDER:* | /usr/bin/awk -F':' '{print $NF}'`"
INFRASTRUCTURE_REPOSITORY_USERNAME="`/bin/ls ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYUSERNAME:* | /usr/bin/awk -F':' '{print $NF}'`"
INFRASTRUCTURE_REPOSITORY_PASSWORD="`/bin/ls ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYPASSWORD:* | /usr/bin/awk -F':' '{print $NF}'`"
INFRASTRUCTURE_REPOSITORY_OWNER="`/bin/ls ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYOWNER:* | /usr/bin/awk -F':' '{print $NF}'`"
APPLICATION_REPOSITORY_PROVIDER="`/bin/ls ${HOME}/.ssh/APPLICATIONREPOSITORYPROVIDER:* | /usr/bin/awk -F':' '{print $NF}'`"
APPLICATION_REPOSITORY_OWNER="`/bin/ls ${HOME}/.ssh/APPLICATIONREPOSITORYOWNER:* | /usr/bin/awk -F':' '{print $NF}'`"
APPLICATION_REPOSITORY_USERNAME="`/bin/ls ${HOME}/.ssh/APPLICATIONREPOSITORYUSERNAME:* | /usr/bin/awk -F':' '{print $NF}'`"
APPLICATION_REPOSITORY_PASSWORD="`/bin/ls ${HOME}/.ssh/APPLICATIONREPOSITORYPASSWORD:* | /usr/bin/awk -F':' '{print $NF}'`"
APPLICATION_REPOSITORY_TOKEN="`/bin/ls ${HOME}/.ssh/APPLICATIONREPOSITORYTOKEN:* | /usr/bin/awk -F':' '{print $NF}'`"
CLOUDHOST_PASSWORD="`/bin/ls ${HOME}/.ssh/CLOUDHOSTPASSWORD:* | /usr/bin/awk -F':' '{print $NF}'`"
BUILD_ARCHIVE="`/bin/ls ${HOME}/.ssh/BUILDARCHIVE:* | /usr/bin/awk -F':' '{print $NF}'`"
DATASTORE_CHOICE="`/bin/ls ${HOME}/.ssh/DATASTORECHOICE:* | /usr/bin/awk -F':' '{print $NF}'`"
WEBSERVER_CHOICE="`/bin/ls ${HOME}/.ssh/WEBSERVERCHOICE:* | /usr/bin/awk -F':' '{print $NF}'`"
APPLICATION_IDENTIFIER="`/bin/ls ${HOME}/.ssh/APPLICATIONIDENTIFIER:* | /usr/bin/awk -F':' '{print $NF}'`"
APPLICATION_LANGUAGE="`/bin/ls ${HOME}/.ssh/APPLICATIONLANGUAGE:* | /usr/bin/awk -F':' '{print $NF}'`"
SOURCECODE_REPOSITORY="`/bin/ls ${HOME}/.ssh/APPLICATIONBASELINESOURCECODEREPOSITORY:* | /usr/bin/awk -F':' '{print $NF}'`"

##/bin/touch ${HOME}/.ssh/ASIP:`${HOME}/providerscripts/utilities/GetIP.sh`
##/bin/touch ${HOME}/.ssh/ASPUBLICIP:`${HOME}/providerscripts/utilities/GetPublicIP.sh`

#If it doesn't successfully build the webserver, try building another one up to a maximum of 3 attempts
/bin/echo "${0} `/bin/date`: ###############################################" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
/bin/echo "${0} `/bin/date`: Building a new webserver" >> ${HOME}/logs/MonitoringWebserverBuildLog.log

# Set up the webservers properties, like its name and so on.
RND="`/bin/cat /dev/urandom | /usr/bin/tr -dc 'a-zA-Z0-9' | /usr/bin/fold -w 4 | /usr/bin/head -n 1`"
SERVER_TYPE="webserver"
SERVER_NUMBER="`${HOME}/providerscripts/server/NumberOfServers.sh "${SERVER_TYPE}" ${CLOUDHOST}`"
WEBSITE_URL="`/bin/ls ${HOME}/.ssh | grep WEBSITEURL | /usr/bin/awk -F':' '{print $NF}'`"
webserver_name="webserver-${RND}-${WEBSITE_NAME}-${BUILD_IDENTIFIER}"
SERVER_INSTANCE_NAME="`/bin/echo ${webserver_name} | /usr/bin/cut -c -32 | /bin/sed 's/-$//g'`"
SSH_PORT="`/bin/ls ${HOME}/.ssh/SSH_PORT:* | /usr/bin/awk -F':' '{print $NF}'`"
DB_PORT="`/bin/ls ${HOME}/.ssh/DB_PORT:* | /usr/bin/awk -F':' '{print $NF}'`"


#If we have deployed to use DBaaS-secured, then we need to have an ssh tunnel setup.
#For scaling purposes we may have multiple remote proxy machines with our DB provider and so
#We allocate usage of these proxy machines to our webservers in a road robin fashion.
#In other words, if there are 3 ssh proxy machines runnning remotely, then for us,
# webserver 1 would use remote proxy 1
# webserver 2 would use remote proxy 2
# webserver 3 would use remote proxy 3
# webserver 4 would use remote proxy 1
# webserver 5 would use remote proxy 2
#and so on so, here is where we define the index for which proxy machine to use

proxyips="`/bin/ls ${HOME}/.ssh/DBaaSREMOTESSHPROXYIP:* | /usr/bin/awk -F':' '{$1=""}1'`"
if ( [ "${proxyips}" != "" ] )
then
    noproxyips="`/bin/echo "${proxyips}" | /usr/bin/wc -w`"
    index="`/usr/bin/expr ${SERVER_NUMBER} % ${noproxyips}`"
    index="`/usr/bin/expr ${index} + 1`"
    /bin/rm ${HOME}/.ssh/DBaaSREMOTESSHPROXYIPINDEX:*
    /bin/touch ${HOME}/.ssh/DBaaSREMOTESSHPROXYIPINDEX:${index}
fi

#What type of machine are we building - this will determine the size and so on with the cloudhost
SERVER_TYPE_ID="`${HOME}/providerscripts/server/GetServerTypeID.sh ${SIZE} "${SERVER_TYPE}" ${CLOUDHOST}`"

#Hell, what operating system are we running
ostype="`${HOME}/providerscripts/cloudhost/GetOperatingSystemVersion.sh ${SIZE} ${CLOUDHOST}`"

#Attempt to create a vanilla machine on which to build our webserver
#The build method tells us if we are using a snapshot or not
buildmethod="`${HOME}/providerscripts/server/CreateServer.sh "${ostype}" "${REGION}" "${SERVER_TYPE_ID}" "${SERVER_INSTANCE_NAME}" "${KEY_ID}" ${CLOUDHOST} "${DEFAULT_USER}" ${CLOUDHOST_PASSWORD}`"

count="0"
while ( [ "$?" != "0" ] && [ "${count}" -lt "10" ] )
do
    /bin/sleep 5
    buildmethod="`${HOME}/providerscripts/server/CreateServer.sh "${ostype}" "${REGION}" "${SERVER_TYPE_ID}" "${SERVER_INSTANCE_NAME}" "${KEY_ID}" ${CLOUDHOST} "${DEFAULT_USER}" ${CLOUDHOST_PASSWORD}`"
    count="`/usr/bin/expr ${count} + 1`"
done

if ( [ "${count}" = "10" ] )
then
    /bin/echo "${0} `/bin/date`: Failed to build server" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
    exit
fi

count="0"

# There is a delay between the server being created and started and it "coming online". The way we can tell it is online is when
# It returns an ip address, so try, several times to retrieve the ip address of the server
# We are prepared to wait a total of 300 seconds for the machine to come online
while ( [ "`/bin/echo ${ip} | /bin/grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"`" = "" ] && [ "${count}" -lt "30" ] || [ "${ip}" = "0.0.0.0" ] )
do
    /bin/sleep 20
    ip="`${HOME}/providerscripts/server/GetServerIPAddresses.sh ${SERVER_INSTANCE_NAME} ${CLOUDHOST}`"
    /bin/touch ${HOME}/config/webserverpublicips/${ip}
    private_ip="`${HOME}/providerscripts/server/GetServerPrivateIPAddresses.sh ${SERVER_INSTANCE_NAME} ${CLOUDHOST}`"
    /bin/touch ${HOME}/config/webserverips/${private_ip}
    count="`/usr/bin/expr ${count} + 1`"
done

if ( [ "${ip}" = "" ] )
then
    #This should never happen, and I am not sure what to do about it if it does. If we don't have an ip address, how can
    #we destroy the machine? I simply exit, therefore.
    /bin/echo "${0} `/bin/date`: Server didn't come online " >> ${HOME}/logs/MonitoringWebserverBuildLog.log
    exit
fi
DBaaS_DBSECURITYGROUP="`/bin/ls ${HOME}/.ssh/DBaaSDBSECURITYGROUP:* | /usr/bin/awk -F':' '{print $NF}'`"
if ( [ "${DBaaS_DBSECURITYGROUP}" != "" ] )
then
    IP_TO_ALLOW="${ip}"
    . ${HOME}/providerscripts/server/AllowDBAccess.sh
fi

INMEMORYCACHING_SECURITY_GROUP="`/bin/ls ${HOME}/.ssh/INMEMORYCACHINGSECURITYGROUP:* | /usr/bin/awk -F':' '{print $NF}'`"
INMEMORYCACHING_PORT="`/bin/ls ${HOME}/.ssh/INMEMORYCACHINGPORT:* | /usr/bin/awk -F':' '{print $NF}'`"
INMEMORYCACHING_HOST="`/bin/ls ${HOME}/.ssh/INMEMORYCACHINGHOST:* | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${INMEMORYCACHING_SECURITY_GROUP}" != "" ] )
then
    IP_TO_ALLOW="${ip}"
    . ${HOME}/providerscripts/server/AllowCachingAccess.sh
fi

#We add our IP address to a list of machines in the 'being built' stage. We can check this flag elsewhere when we want to
#distinguish between ip address of webservers which have been built and are still being built.
#The autoscaler monitors for this when it is looking for slow builds. The being built part of things is cleared out when
#we reach the end of the build process so if this persists for an excessive amount of time, the "slow builds" script on the
#autoscaler knows that something is hanging or has gone wrong with the build and it clears things up.
/usr/bin/touch ${HOME}/config/beingbuiltips/${private_ip}
/usr/bin/touch ${HOME}/config/webserverips/${private_ip}
/usr/bin/touch ${HOME}/config/webserverpublicips/${ip}

/usr/sbin/ufw allow from ${private_ip}
/usr/sbin/ufw allow from ${ip}

# Build our webserver
if ( [ "`/bin/echo ${buildmethod} | /bin/grep 'SNAPPED'`" = "" ] )
then
    #If we are here, then we are not building from a snapshot
    webserver_name="${SERVER_INSTANCE_NAME}"
    #Test to see if our server can be accessed using our build key
    count="0"

    $?="-1" 2>/dev/null

    while ( [ "$?" != "0" ] && [ "${count}" -lt "5" ] && [ "${CLOUDHOST_PASSWORD}" = "" ] )
    do
        count="`/usr/bin/expr ${count} + 1`"
        /bin/sleep 10
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -o "PasswordAuthentication no" ${DEFAULT_USER}@${ip} "exit"
    done

    if ( [ "${count}" = "5" ] || [ "${CLOUDHOST_PASSWORD}" != "" ] )
    then
        #If we get to here, it means the ssh key failed, lets, then, try authenticating by password
        if ( [ ! -f /usr/bin/sshpass ] )
        then
            /usr/bin/apt-get -qq install sshpass
        fi
        count="0"
        if ( [ "${CLOUDHOST_PASSWORD}" != "" ] )
        then
            /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/ssh ${OPTIONS} ${DEFAULT_USER}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/mkdir -p /root/.ssh" >/dev/null 2>&1
            /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/ssh ${OPTIONS} ${DEFAULT_USER}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/mkdir -p /home/${SERVER_USER}/.ssh"
            while ( [ "$?" != "0" ] )
            do
                /bin/echo "Haven't successfully connected to the Webserver, maybe it is still initialising, trying again...."
                /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/ssh ${OPTIONS} ${CLOUDHOST_USERNAME}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/mkdir -p /home/${SERVER_USER}/.ssh" >/dev/null 2>&1
                /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/ssh ${OPTIONS} ${CLOUDHOST_USERNAME}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/mkdir -p /root/.ssh" >/dev/null 2>&1
                /bin/sleep 5
                count="`/usr/bin/expr ${count} + 1`"
            done

            if ( [ "${count}" = "10" ] )
            then
                /bin/echo "${0} `/bin/date`: Failed to build server" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
                exit
            fi
        else
            /bin/echo "${0} `/bin/date`: Failed to build server -cloudhost password not set" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
            exit
        fi
        #Set up our ssh keys
        /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/ssh ${OPTIONS} ${CLOUDHOST_USERNAME}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/mkdir -p /home/${SERVER_USER}/.ssh" >/dev/null 2>&1
        /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/ssh ${OPTIONS} ${CLOUDHOST_USERNAME}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/chmod 700 /home/${SERVER_USER}/.ssh" >/dev/null 2>&1
        /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/ssh ${OPTIONS} ${CLOUDHOST_USERNAME}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/chmod 700 /root/.ssh" >/dev/null 2>&1
        /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/scp ${OPTIONS} ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}.pub ${CLOUDHOST_USERNAME}@${ip}:/root/.ssh/authorized_keys >/dev/null 2>&1
        /usr/bin/sshpass -p ${CLOUDHOST_PASSWORD} /usr/bin/scp ${OPTIONS} ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}.pub ${CLOUDHOST_USERNAME}@${ip}:/home/${SERVER_USER}/.ssh/authorized_keys >/dev/null 2>&1
    else
        #set up our ssh keys
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /bin/mkdir -p /home/${SERVER_USER}/.ssh"

        #Fine to here.........
        #/bin/cat ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}.pub | /usr/bin/ssh ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /bin/cat - >> /root/.ssh/authorized_keys"
        /bin/cat ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}.pub | /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /bin/chmod 777 /home/${DEFAULT_USER}/.ssh ; /bin/cat - >> /home/${DEFAULT_USER}/.ssh/authorized_keys ; ${SUDO} /bin/chmod 700 /home/${DEFAULT_USER}/.ssh"
        /bin/cat ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}.pub | /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /bin/chmod 777 /home/${SERVER_USER}/.ssh ; /bin/cat - >> /home/${SERVER_USER}/.ssh/authorized_keys ; ${SUDO} /bin/chmod  700 /home/${SERVER_USER}/.ssh"
    fi

    # These look complicated but really all it is is a list of scp and ssh commands with appropriate connection parameters and
    # the private key that is need to connect.

    #Add our own user. root access is disabled, so we will have to connect through our own unprivileged user
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}  ${OPTIONS} ${DEFAULT_USER}@${ip} "DEBIAN_FRONTEND=noninteractive /bin/sh -c '${SUDO} /usr/bin/apt-get update'"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /usr/bin/apt-get install -qq git"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /usr/sbin/useradd ${SERVER_USER}"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "/bin/echo ${SERVER_USER}:${SERVER_USER_PASSWORD} | /usr/bin/sudo -S -E /usr/sbin/chpasswd"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /usr/bin/gpasswd -a ${SERVER_USER} sudo"
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER}.pub ${DEFAULT_USER}@${ip}:/home/${SERVER_USER}/.ssh/authorized_keys
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /bin/chown -R ${SERVER_USER}.${SERVER_USER} /home/${SERVER_USER}/"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "${SUDO} /bin/sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${DEFAULT_USER}@${ip} "i${SUDO} /usr/sbin/service ssh restart"

    #Mark this as an autoscaled machine as distinct from one built during the initial build
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} '/bin/touch ${HOME}/.ssh/AUTOSCALED'

    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${SERVER_USER}@${ip}:${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "/bin/chmod 400 ${HOME}/.ssh/id_${ALGORITHM}"

    #If we are building for use of an ssh tunnel, then the webserver needs to know the private key of the remote proxy machine.
    #We have it on the autoscaler file system, so we simply pass it over to our new webserver which will know where to look and
    #what to do with it
    if ( [ -f ${HOME}/.ssh/DATABASEINSTALLATIONTYPE:DBaaS-secured ] )
    then
        /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/dbaas_server_key.pem ${SERVER_USER}@${ip}:${HOME}/.ssh/dbaas_server_key.pem
    fi

    #Configure the provider details
    ${HOME}/providerscripts/cloudhost/ConfigureProvider.sh ${CLOUDHOST} ${BUILD_IDENTIFIER} ${ALGORITHM} ${ip} ${SERVER_USER}

    #INSTALLING GIT
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "cd /home/${SERVER_USER}"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} '/usr/bin/git init'
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} '/bin/mkdir ${HOME}/bootstrap'
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/providerscripts/git/GitFetch.sh ${SERVER_USER}@${ip}:${HOME}/bootstrap
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/providerscripts/git/GitCheckout.sh ${SERVER_USER}@${ip}:${HOME}/bootstrap
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/providerscripts/git/GitPull.sh ${SERVER_USER}@${ip}:${HOME}/bootstrap
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} '/bin/chmod 700 ${HOME}/bootstrap/*'
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${HOME}/bootstrap/GitFetch.sh ${INFRASTRUCTURE_REPOSITORY_PROVIDER} ${INFRASTRUCTURE_REPOSITORY_USERNAME} ${INFRASTRUCTURE_REPOSITORY_PASSWORD} ${INFRASTRUCTURE_REPOSITORY_OWNER} agile-infrastructure-webserver-scripts"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${HOME}/bootstrap/GitCheckout.sh ${INFRASTRUCTURE_REPOSITORY_PROVIDER} ws.sh"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${HOME}/bootstrap/GitCheckout.sh ${INFRASTRUCTURE_REPOSITORY_PROVIDER} providerscripts/datastore/ConfigureDatastoreProvider.sh"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${HOME}/bootstrap/GitPull.sh ${INFRASTRUCTURE_REPOSITORY_PROVIDER} ${INFRASTRUCTURE_REPOSITORY_USERNAME} ${INFRASTRUCTURE_REPOSITORY_PASSWORD} ${INFRASTRUCTURE_REPOSITORY_OWNER} agile-infrastructure-webserver-scripts"

    #Configure our datastore for this server. This will enable us to use tools like s3cmd from our webserver for backups etc
    ${HOME}/providerscripts/datastore/ConfigureDatastoreProvider.sh ${DATASTORE_CHOICE} ${ip} ${CLOUDHOST} ${BUILD_IDENTIFIER} ${ALGORITHM} ${SERVER_USER}

    #Configuration values
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "/bin/touch ${HOME}/.ssh/MYPUBLICIP:${ip}"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "/bin/touch ${HOME}/.ssh/MYIP:${private_ip}"

    #Copy across all our configuration values
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/INMEMORYCACHINGHOST:* ${HOME}/.ssh/INMEMORYCACHING:* ${HOME}/.ssh/INMEMORYCACHINGPORT:* ${HOME}/.ssh/INMEMORYCACHINGSECURITYGROUP:* ${HOME}/.ssh/PRODUCTION:* ${HOME}/.ssh/ENABLEEFS:* ${HOME}/.ssh/BUILDOS:* ${HOME}/.ssh/BUILDOSVERSION:* ${HOME}/.ssh/BUILDCLIENTIP:* ${HOME}/.ssh/ALGORITHM:* ${HOME}/.ssh/BUILDARCHIVE:* ${HOME}/.ssh/BUILDCHOICE:* ${HOME}/.ssh/CLOUDHOST:* ${HOME}/.ssh/CLOUDHOSTPASSWORD:* ${HOME}/.ssh/DATASTORECHOICE:* ${HOME}/.ssh/INMEMORYCACHE:* ${HOME}/.ssh/KEYID:* ${HOME}/.ssh/REGION:* ${HOME}/.ssh/APPLICATIONREPOSITORYPASSWORD:* ${HOME}/.ssh/SIZE:* ${HOME}/.ssh/SNAPAUTOSCALE:* ${HOME}/.ssh/SOURCECODEREPOSITORY:* ${HOME}/.ssh/WEBSERVERCHOICE:* ${HOME}/.ssh/WEBSITEDISPLAYNAME:* ${HOME}/.ssh/APPLICATIONIDENTIFIER:* ${HOME}/.ssh/APPLICATIONLANGUAGE:* ${HOME}/.ssh/APPLICATIONBASELINESOURCECODEREPOSITORY:* ${HOME}/.ssh/GITUSER:* ${HOME}/.ssh/GITEMAILADDRESS:* ${HOME}/.ssh/BUILDIDENTIFIER:* ${HOME}/.ssh/SUPERSAFEWEBROOT:* ${HOME}/.ssh/DIRECTORIESTOMOUNT:* ${HOME}/.ssh/DB_PORT:* ${HOME}/.ssh/SSH_PORT:* ${HOME}/.ssh/SSLGENERATIONMETHOD:* ${HOME}/.ssh/SSLGENERATIONSERVICE:* ${HOME}/.ssh/DBaaSHOSTNAME:* ${HOME}/.ssh/DBaaSUSERNAME:* ${HOME}/.ssh/DBaaSPASSWORD:* ${HOME}/.ssh/DBaaSDBNAME:* ${HOME}/.ssh/DBaaSREMOTESSHPROXYIP:* ${HOME}/.ssh/DBaaSREMOTESSHPROXYIPINDEX:* ${HOME}/.ssh/DEFAULTDBaaSOSUSER:* ${HOME}/.ssh/DATABASEDBaaSINSTALLATIONTYPE:* ${HOME}/.ssh/SERVERTIMEZONECITY:* ${HOME}/.ssh/SERVERTIMEZONECONTINENT:* ${HOME}/.ssh/PHP_VERSION:* ${HOME}/.ssh/PERSISTASSETSTOCLOUD:* ${HOME}/.ssh/DISABLEHOURLY:* ${SERVER_USER}@${ip}:${HOME}/.ssh/
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "/bin/touch ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYPROVIDER:${INFRASTRUCTURE_REPOSITORY_PROVIDER} ; /bin/touch ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYUSERNAME:${INFRASTRUCTURE_REPOSITORY_USERNAME} ; /bin/touch ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYPASSWORD:${INFRASTRUCTURE_REPOSITORY_PASSWORD} ; /bin/touch ${HOME}/.ssh/INFRASTRUCTUREREPOSITORYOWNER:${INFRASTRUCTURE_REPOSITORY_OWNER} ; /bin/touch ${HOME}/.ssh/APPLICATIONREPOSITORYTOKEN:${APPLICATION_REPOSITORY_TOKEN} ; /bin/touch ${HOME}/.ssh/APPLICATIONREPOSITORYPROVIDER:${APPLICATION_REPOSITORY_PROVIDER} ; /bin/touch ${HOME}/.ssh/APPLICATIONREPOSITORYUSERNAME:${APPLICATION_REPOSITORY_USERNAME} ; /bin/touch ${HOME}/.ssh/APPLICATIONREPOSITORYPASSWORD:${APPLICATION_REPOSITORY_PASSWORD} ; /bin/touch ${HOME}/.ssh/APPLICATIONREPOSITORYOWNER:${APPLICATION_REPOSITORY_OWNER}"
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/WEBSITEURL:* ${HOME}/.ssh/FROMADDRESS:* ${HOME}/.ssh/TOADDRESS:* ${HOME}/.ssh/EMAILUSERNAME:* ${HOME}/.ssh/EMAILPASSWORD:* ${HOME}/.ssh/EMAILPROVIDER:* ${HOME}/.ssh/APPLICATION:* ${HOME}/.ssh/SERVERUSER:* ${HOME}/.ssh/SERVERUSERPASSWORD:* ${HOME}/.ssh/DNSUSERNAME:* ${HOME}/.ssh/DNSSECURITYKEY:* ${HOME}/.ssh/DNSCHOICE:* ${HOME}/.ssh/WEBSITEURL:* ${HOME}/.ssh/DATABASEINSTALLATIONTYPE:* ${SERVER_USER}@${ip}:${HOME}/.ssh/

    MACHINETYPE="`/bin/ls ${HOME}/.ssh/MACHINETYPE:* | /usr/bin/awk -F':' '{print $NF}'`"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /usr/bin/touch ${HOME}/${MACHINETYPE}"


    #Setup SSL Certificate
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/mkdir -p ${HOME}/ssl//live/${WEBSITE_URL}"
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/fullchain.pem ${SERVER_USER}@${ip}:/home/${SERVER_USER}/.ssh/fullchain.pem
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/privkey.pem ${SERVER_USER}@${ip}:/home/${SERVER_USER}/.ssh/privkey.pem
    /usr/bin/scp -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${HOME}/.ssh/${WEBSITE_URL}.json ${SERVER_USER}@${ip}:/home/${SERVER_USER}/.ssh/${WEBSITE_URL}.json
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/cp /home/${SERVER_USER}/.ssh/fullchain.pem ${HOME}/ssl/live/${WEBSITE_URL}/fullchain.pem"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/cp /home/${SERVER_USER}/.ssh/privkey.pem ${HOME}/ssl/live/${WEBSITE_URL}/privkey.pem"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/cp /home/${SERVER_USER}/.ssh/${WEBSITE_URL}.json ${HOME}/ssl/live/${WEBSITE_URL}/${WEBSITE_URL}.json"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/chown root.root ${HOME}/ssl/live/${WEBSITE_URL}/fullchain.pem"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/chmod 400  ${HOME}/ssl/live/${WEBSITE_URL}/fullchain.pem"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/chown root.root ${HOME}/ssl/live/${WEBSITE_URL}/privkey.pem"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/chmod 400  ${HOME}/ssl/live/${WEBSITE_URL}/privkey.pem"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/chown root.root ${HOME}/ssl/live/${WEBSITE_URL}/${WEBSITE_URL}.json"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/chmod 400  ${HOME}/ssl/live/${WEBSITE_URL}/${WEBSITE_URL}.json"

    #We have lots of backup choices to build from, hourly, daily and so on, so this will pick which backup we want to build from
    if ( [ "${BUILD_CHOICE}" = "0" ] )
    then
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} ${HOME}/ws.sh 'virgin' ${SERVER_USER}"
elif ( [ "${BUILD_CHOICE}" = "1" ] )
    then
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} ${HOME}/ws.sh 'baseline' ${SERVER_USER}"
elif ( [ "${BUILD_CHOICE}" = "2" ] )
    then
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO}  ${HOME}/ws.sh 'hourly' ${SERVER_USER}"
elif ( [ "${BUILD_CHOICE}" = "3" ] )
    then
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO}  ${HOME}/ws.sh 'daily' ${SERVER_USER}"
elif ( [ "${BUILD_CHOICE}" = "4" ] )
    then
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO}  ${HOME}/ws.sh 'monthly' ${SERVER_USER}"
elif ( [ "${BUILD_CHOICE}" = "5" ] )
    then
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO}  ${HOME}/ws.sh 'bimonthly' ${SERVER_USER}"
    fi
else
    /bin/echo "${0} `/bin/date`: Building a new machine from a snapshot or dynamically scaled" >> ${HOME}/logs/MonitoringWebserverBuildLog.log

    #If we got to here, then the server has been built from a snapshot.
    /usr/bin/touch ${HOME}/config/bootedwebserverips/${private_ip}

    #We want to make sure that our server has spawned correctly from our snapshot so give it plenty of time to connect. If the connection fails
    #then, as I have seen, something has gone wrong with spawning from a snapshot, so destroy the machine and the next run of the autoscaler
    #will spawn a fresh one, hopefully, without issue
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=30 -o ConnectionAttempts=20 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p ${SSH_PORT} ${SERVER_USER}@${ip} "exit"

    if ( [ "$?" != "0" ] )
    then
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=30 -o ConnectionAttempts=20 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p ${SSH_PORT} ${SERVER_USER}@${ip} "exit"
    fi

    if ( [ "$?" != "0" ] )
    then

        if ( [ "${CLOUDHOST}" = "vultr" ] )
        then
            #This is untidy, lol,
            #because vultr cloudhost doesn't let you destroy machines until they have been running for 5 mins or more
            /bin/sleep 300
        fi

        /bin/echo "${0} `/bin/date` : ${ip} is being destroyed because it couldn't be connected to after spawning it from a snapshot" >> ${HOME}/logs/MonitoringLog.log
        ${HOME}/providerscripts/server/DestroyServer.sh ${ip} ${CLOUDHOST}
        
        DBaaS_DBSECURITYGROUP="`/bin/ls ${HOME}/.ssh/DBaaSDBSECURITYGROUP:* | /usr/bin/awk -F':' '{print $NF}'`"
        if ( [ "${DBaaS_DBSECURITYGROUP}" != "" ] )
        then
            IP_TO_DENY="${ip}"
            . ${HOME}/providerscripts/server/DenyDBAccess.sh
        fi
        
        INMEMORYCACHING_SECURITY_GROUP="`/bin/ls ${HOME}/.ssh/INMEMORYCACHINGSECURITYGROUP:* | /usr/bin/awk -F':' '{print $NF}'`"
        INMEMORYCACHING_PORT="`/bin/ls ${HOME}/.ssh/INMEMORYCACHINGPORT:* | /usr/bin/awk -F':' '{print $NF}'`"

        if ( [ "${INMEMORYCACHING_SECURITY_GROUP}" != "" ] )
        then
            IP_TO_DENY="${ip}"
            . ${HOME}/providerscripts/server/DenyCachingAccess.sh
        fi

        /bin/rm ${HOME}/config/beingbuiltips/${private_ip}
        /bin/rm ${HOME}/runtime/autoscalelock.file
        exit
    fi

    #Our snapshot built machine will have "frozen" config settings from when it was snapshotted. These will likely be different
    #For example, the ip addresses will be different for the machines, so, we need to purge the bits of configuration that need
    #to be updated and replace it with fresh stuff
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -p ${SSH_PORT} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/rm -f /home/${SERVER_USER}/.ssh/BUILDARCHIVECHOICE:* /home/${SERVER_USER}/.ssh/MYIP:* /home/${SERVER_USER}/.ssh/MYPUBLICIP:* /home/${SERVER_USER}/runtime/NETCONFIGURED /home/${FULL_SNAPSHOT_ID}/runtime/SSHTUNNELCONFIGURED /home/${FULL_SNAPSHOT_ID}/runtime/APPLICATION_CONFIGURATION_PREPARED /home/${FULL_SNAPSHOT_ID}/runtime/APPLICATION_DB_CONFIGURED /home/${FULL_SNAPSHOT_ID}/runtime/*.lock"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -p ${SSH_PORT} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/touch /home/${SERVER_USER}/.ssh/BUILDARCHIVECHOICE:${BUILD_ARCHIVE} /home/${SERVER_USER}/.ssh/MYIP:${private_ip} /home/${SERVER_USER}/.ssh/MYPUBLICIP:${ip}"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -p ${SSH_PORT} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /home/${SERVER_USER}/providerscripts/utilities/RefreshNetworking.sh"

    #If we have deployed to use DBaaS-secured, then we need to have an ssh tunnel setup.
    #For scaling purposes we may have multiple remote proxy machines with our DB provider and so
    #We allocate usage of these proxy machines to our webservers in a road robin fashion.
    #In other words, if there are 3 ssh proxy machines runnning remotely, then for us,
    # webserver 1 would use remote proxy 1
    # webserver 2 would use remote proxy 2
    # webserver 3 would use remote proxy 3
    # webserver 4 would use remote proxy 1
    # webserver 5 would use remote proxy 2
    # and so on so, here is where we define the index for which proxy machine to use

    proxyips="`/bin/ls ${HOME}/.ssh/DBaaSREMOTESSHPROXYIP:* | /usr/bin/awk -F':' '{$1=""}1'`"
    if ( [ "${proxyips}" != "" ] )
    then
        noproxyips="`/bin/echo "${proxyips}" | /usr/bin/wc -w`"
        index="`/usr/bin/expr ${SERVER_NUMBER} % ${noproxyips} 2>/dev/null`"
        index="`/usr/bin/expr ${index} + 1`"
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -p ${SSH_PORT} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/rm /home/${SERVER_USER}/.ssh/DBaaSREMOTESSHPROXYIPINDEX:* /home/${SERVER_USER}/.ssh/DBaaSREMOTESSHPROXYIP:*"
        /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -p ${SSH_PORT} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/touch /home/${SERVER_USER}/.ssh/DBaaSREMOTESSHPROXYIPINDEX:${index} /home/${SERVER_USER}/.ssh/DBaaSREMOTESSHPROXYIP:`/bin/echo ${proxyips} | /bin/sed 's/ /:/g'`"
    fi
    
    /usr/bin/ssh -p ${SSH_PORT} -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=10 -o ConnectionAttempts=3 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} ${HOME}/providerscripts/utilities/InitialSyncFromWebrootTunnel.sh"
    /usr/bin/ssh -p ${SSH_PORT} -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=10 -o ConnectionAttempts=3 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} ${HOME}/applicationscripts/SyncLatestApplication.sh ${APPLICATION_REPOSITORY_PROVIDER} ${APPLICATION_REPOSITORY_USERNAME} ${APPLICATION_REPOSITORY_PASSWORD} ${APPLICATION_REPOSITORY_OWNER} ${BUILD_ARCHIVE} ${DATASTORE_CHOICE} ${BUILD_IDENTIFIER} ${WEBSITE_NAME}"

    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -p ${SSH_PORT} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /bin/touch /home/${SERVER_USER}/.ssh/AUTOSCALED"
    /usr/bin/ssh -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} ${OPTIONS} -p ${SSH_PORT} ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} /sbin/shutdown -r now"
fi

#Wait for the machine to become responsive before we check its integrity

/usr/bin/ping -c 10 ${ip}

while ( [ "$?" != "0" ] )
do
    /usr/bin/ping -c 10 ${ip}
done

/bin/sleep 10

/usr/bin/ssh -p ${SSH_PORT} -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=10 -o ConnectionAttempts=60 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} "exit"

if ( [ "$?" != "0" ] )
then
    /usr/bin/ssh -p ${SSH_PORT} -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=10 -o ConnectionAttempts=60 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} "exit"
fi

/bin/echo "${0} `/bin/date`: The main build has completed now just have to check that it's been dun right" >> ${HOME}/logs/MonitoringWebserverBuildLog.log

/bin/echo "${0} `/bin/date`: It can take a minute or so for a new machine to initialise after it is back online post reboot, so just gonna nap for 60 seconds..." >> ${HOME}/logs/MonitoringWebserverBuildLog.log

/bin/sleep 60

#Do some checks to make sure the machine has come online and so on
tries="0"
while ( [ "${tries}" -lt "20" ] && ( [ "`/usr/bin/ssh -p ${SSH_PORT} -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=10 -o ConnectionAttempts=3 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} ${HOME}/providerscripts/utilities/AreAssetsMounted.sh"`" != "MOUNTED" ] || [ "`/usr/bin/ssh -p ${SSH_PORT} -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=10 -o ConnectionAttempts=3 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} ${HOME}/providerscripts/utilities/CheckServerAlive.sh"`" != "ALIVE" ] ) )
do
    /bin/echo "${0} `/bin/date`: Doing integrity checks for ${ip}" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
    /bin/sleep 10
    tries="`/usr/bin/expr ${tries} + 1`"
done

if ( [ "${tries}" = "20" ] )
then
    /bin/echo "${0} `/bin/date`: Failed integrity checks for ${ip}" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
fi

/usr/bin/ssh -p ${SSH_PORT} -i ${HOME}/.ssh/id_${ALGORITHM}_AGILE_DEPLOYMENT_BUILD_KEY_${BUILD_IDENTIFIER} -o ConnectTimeout=10 -o ConnectionAttempts=3 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SERVER_USER}@${ip} "${CUSTOM_USER_SUDO} ${HOME}/providerscripts/utilities/InitialSyncFromWebrootTunnel.sh"

#Do a check, as best we can to make sure that the website application is actually running correctly
loop="0"
while ( [ "${loop}" -lt "7" ] )
do
    if ( [ -f ${HOME}/.ssh/APPLICATIONLANGUAGE:PHP ] )
    then
        file="index.php"
    else
        file=""
    fi

    if ( [ "`/usr/bin/curl -I --max-time 60 --insecure https://${ip}:443/${file} | /bin/grep -E 'HTTP/2 200|HTTP/2 301|HTTP/2 302|200 OK|302 Found|301 Moved Permanently'`" = "" ] )
    then
        /bin/echo "${0} `/bin/date`: Expecting ${ip} to be online, but can't curl it yet...." >> ${HOME}/logs/MonitoringWebserverBuildLog.log
        /bin/sleep 60
        loop="`/usr/bin/expr ${loop} + 1`"
    else
        /bin/echo "${0} `/bin/date`: ${ip} is online wicked..." >> ${HOME}/logs/MonitoringWebserverBuildLog.log
        break
    fi
done

if ( [ "${loop}" = "7" ] || [ "${tries}" = "20" ] )
then
    #If either of these are true, then somehow the machine/application didn't come online and so we need to destroy the machine
    if ( [ "${CLOUDHOST}" = "vultr" ] )
    then
        #because vultr cloudhost doesn't let you destroy machines until they have been running for 5 mins or more
        /bin/sleep 300
    fi
    /bin/echo "${0} `/bin/date` : ${ip} is being destroyed because it didn't come online." >> ${HOME}/logs/MonitoringLog.log
    /bin/echo "${0} `/bin/date`: ${ip} is being destroyed because it didn't come online" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
    ${HOME}/providerscripts/server/DestroyServer.sh ${ip} ${CLOUDHOST}
    
    DBaaS_DBSECURITYGROUP="`/bin/ls ${HOME}/.ssh/DBaaSDBSECURITYGROUP:* | /usr/bin/awk -F':' '{print $NF}'`"
    if ( [ "${DBaaS_DBSECURITYGROUP}" != "" ] )
    then
        IP_TO_DENY="${ip}"
        . ${HOME}/providerscripts/server/DenyDBAccess.sh
    fi
    INMEMORYCACHING_SECURITY_GROUP="`/bin/ls ${HOME}/.ssh/INMEMORYCACHINGSECURITYGROUP:* | /usr/bin/awk -F':' '{print $NF}'`"
    INMEMORYCACHING_PORT="`/bin/ls ${HOME}/.ssh/INMEMORYCACHINGPORT:* | /usr/bin/awk -F':' '{print $NF}'`"

    if ( [ "${INMEMORYCACHING_SECURITY_GROUP}" != "" ] )
    then
        IP_TO_DENY="${ip}"
        . ${HOME}/providerscripts/server/DenyCachingAccess.sh
    fi
else
    #For safety, our new machine needs to "settle down", lol, so, let's sleep for a couple of minutes to be nice to it
    #before we consider it alive and kicking
    /bin/sleep 120
    #If we got to here then we are a successful build as as best as we can tell, everything is online
    #So, we add the ip address of our new machine to our DNS provider and that machine is then ready
    #to start serving requests
    /bin/echo "${0} `/bin/date`: ${ip} is fully online and it's public ip is being added to the DNS provider" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
    /bin/rm ${HOME}/config/beingbuiltips/${private_ip}
    ${HOME}/autoscaler/AddIPToDNS.sh ${ip}
    /bin/echo "${ip}"
fi

/bin/echo "${0} `/bin/date`: Either way, successful or not the build process for machine with ip: ${ip} has completed" >> ${HOME}/logs/MonitoringWebserverBuildLog.log
#Remove our flag saying that this is still in the being built state
/bin/rm ${HOME}/config/beingbuiltips/${private_ip}
