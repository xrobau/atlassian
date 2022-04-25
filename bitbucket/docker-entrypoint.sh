#!/bin/bash
#
# A helper script for ENTRYPOINT.
#
# If first CMD argument is 'bitbucket' or blank then the script will start bitbucket
# Otherwise run that param

set -e

[[ ${DEBUG} == true ]] && set -x

export BITBUCKET_HOME=${PKG_HOME}
export PROPFILE=${PKG_HOME}/shared/bitbucket.properties

if [ -n "${DISABLE_EMBEDDED_SEARCH}" ]; then
  bitbucket_embedded_search="false"
else
  bitbucket_embedded_search="true"
fi

function updateBitbucketProperties() {
  local propertyfile=$1
  local propertyname=$2
  local propertyvalue=$3
  set +e
  grep -q "${propertyname}=" ${propertyfile}
  if [ $? -eq 0 ]; then
    set -e
    if [[ $propertyvalue == /* ]]; then
      sed -i "s/\(${propertyname/./\\.}=\).*\$/\1\\${propertyvalue}/" ${propertyfile}
    else
      sed -i "s/\(${propertyname/./\\.}=\).*\$/\1${propertyvalue}/" ${propertyfile}
    fi
  else
    set -e
    echo "${propertyname}=${propertyvalue}" >> ${propertyfile}
  fi
}

function processBitbucketProxySettings() {
  if [ ! -e ${PROPFILE} ]; then
    echo "# $(date): Auto-Created by docker-entrypoint" > ${PROPFILE}
  fi

  if [ -n "${BITBUCKET_CONTEXT_PATH}" ]; then
    updateBitbucketProperties ${PROPFILE} "server.context-path" ${BITBUCKET_CONTEXT_PATH}
  fi

  if [ -n "${PROXY_NAME}" ]; then
    updateBitbucketProperties ${PROPFILE} "server.proxy-name" ${PROXY_NAME}
  fi

  if [ -n "${PROXY_PORT}" ]; then
    updateBitbucketProperties ${PROPFILE} "server.proxy-port" ${PROXY_PORT}
  fi

  if [ -n "${PROXY_SCHEME}" ]; then
    if [ "${PROXY_SCHEME}" = 'https' ]; then
      local secure="true"
    else
      local secure="false"
    fi
    updateBitbucketProperties ${PROPFILE} "server.secure" ${secure}
    updateBitbucketProperties ${PROPFILE} "server.scheme" ${PROXY_SCHEME}
  fi

  if [ -n "${BITBUCKET_CROWD_SSO}" ] ; then
    updateBitbucketProperties ${PROPFILE} "plugin.auth-crowd.sso.enabled" ${BITBUCKET_CROWD_SSO}
  fi
}

if [ -n "${BITBUCKET_DELAYED_START}" ]; then
  sleep ${BITBUCKET_DELAYED_START}
fi

processBitbucketProxySettings

# If there is a 'ssh' directory, copy it to /home/bitbucket/.ssh
if [ -d ${PKG_HOME}/ssh ]; then
  mkdir -p ${HOMEDIR}/.ssh
  cp -R ${PKG_HOME}/ssh/* ${HOMEDIR}/.ssh
  chmod -R 700 /home/bitbucket/.ssh
fi

if [ "$1" = 'bitbucket' ] || [ "${1:0:1}" = '' ]; then
  umask 0027
  if [ "${bitbucket_embedded_search}" = 'true' ]; then
    exec ${PKG_INSTALL}/bin/start-bitbucket.sh -fg
  else
    exec ${PKG_INSTALL}/bin/start-bitbucket.sh --no-search -fg
  fi
else
  exec "$@"
fi
