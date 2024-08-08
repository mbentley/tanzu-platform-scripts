#!/usr/bin/env bash

# based on a script by Orf Gelbrich
# compares cluster group capabilities to the capabiliites applied to a space via it's profile(s)
# usage:
#   - update the 'TARGET_*' env vars to specify the project, space, and clustergroup
# when using 'git diff' as the diff tool, green capabilities are those that need to be installed to the cluster group as they're missing

# set the target project, space, and cluster group to inspect
TARGET_PROJECT="AMER-East"
TARGET_SPACE="cro-fxg-space"
TARGET_CLUSTERGROUP="cro-fxg-cg"

#TARGET_PROJECT="AMER-East"
#TARGET_SPACE="mbentley-space"
#TARGET_CLUSTERGROUP="mbentley-clustergroup"

#TARGET_PROJECT="AMER-East"
#TARGET_SPACE="orf-rabbitmq-01"
#TARGET_CLUSTERGROUP="orfclustergroup2"

# set the diff tool to use
#DIFF_TOOL="sdiff"
DIFF_TOOL="git diff"

### END USER MODIFYABLE OBJECTS; DO NOT CHANGE BELOW HERE

# save current context as "previous" to restore later
PREVIOUS_CONTEXT="$(tanzu context current --short)"
PREVIOUS_CONTEXT_PROJECT="$(echo "${PREVIOUS_CONTEXT}" | awk -F ':' '{print $2}')"
PREVIOUS_CONTEXT_SPACE="$(echo "${PREVIOUS_CONTEXT}" | awk -F ':' '{print $3}')"

# get current org info
TANZU_CONTEXT_LIST="$(tanzu context list -o json)"

# check the org (just make sure the active context is type tanzu
if [ -z "$(echo "${TANZU_CONTEXT_LIST}" | jq -r '.[] | select((.type == "tanzu") and (.iscurrent == "true")) | .name')" ]
then
  # we need to change the org
  echo "ERROR: make sure to have created a 'tanzu' context; for example:"
  echo "  export TANZU_CLI_CLOUD_SERVICES_ORGANIZATION_ID=\"77aee83b-308f-4c8e-b9c4-3f7a6f19ba75\" TANZU_API_TOKEN=\"<your-cloud-token-here>\""
  echo "  tanzu context create sa-tanzu-platform --endpoint https://api.tanzu.cloud.vmware.com --type tanzu"
  exit 1
else
  # we don't need to change the org
  echo "INFO: check passed; current context ($(echo "${TANZU_CONTEXT_LIST}" | jq -r '.[] | select((.type == "tanzu") and (.iscurrent == "true")) | .name')) is a 'tanzu' type context"
fi

# variable to output a line of standard length
LINE="-----------------------------------------------------------------"

# set the project
echo "INFO: setting project to ${TARGET_PROJECT}..."
tanzu project use "${TARGET_PROJECT}"

# set the clustergroup, if different
echo "INFO: setting clustergroup to ${TARGET_CLUSTERGROUP}..."
tanzu operations clustergroup use "${TARGET_CLUSTERGROUP}"

# start output for the clustergroup
echo "INFO: getting the capabilities for the clustergroup '${TARGET_CLUSTERGROUP}'..."
CLUSTERGROUP_OUTPUT="$(echo -e "${LINE}\nCluster Group Capabilities\n${LINE}")"

# get one of the clusters from the clustergroup to get data on
CLUSTERS="$(tanzu operations cluster list -o json)"
CLUSTER_NAME="$(echo "${CLUSTERS}" | jq -r '.clusters.[] | select(.spec.clusterGroupName == "'"${TARGET_CLUSTERGROUP}"'") | .fullName.name' | head -n 1)"
CLUSTERGROUP_OUTPUT="$(echo "${CLUSTERGROUP_OUTPUT}" && kubectl --kubeconfig "${HOME}/.config/tanzu/kube/config" get kubernetescluster "${CLUSTER_NAME}" -o json | jq -r '.status.capabilities.[].name' | sort)"

# set the space
echo "INFO: setting space to ${TARGET_SPACE}..."
tanzu space use "${TARGET_SPACE}"
echo

SPACE_OUTPUT="$(echo -e "${LINE}\nSpace Capabilities\n${LINE}")"

# get the capabilities provided by the space
echo "INFO: getting the capabilities for the space '${TARGET_SPACE}'..."
SPACE_OUTPUT="$(echo "${SPACE_OUTPUT}" && tanzu space get "${TARGET_SPACE}" -o json | jq -r '.status.providedCapabilities.[].name' | sort)"

# do a diff to see the changes side by side
echo -e "\nINFO: ${DIFF_TOOL} between the clustergroup and space:"
${DIFF_TOOL} <(echo "${CLUSTERGROUP_OUTPUT}") <(echo "${SPACE_OUTPUT}")

# get info about the profiles set on the space
for PROFILE in $(tanzu space get "${TARGET_SPACE}" -o json | jq -r '.spec.template.spec.profiles.[].name')
do
  PROFILE_OUTPUT="$(tanzu profile get mbentley-profile -o json)"
  echo -e "\n${LINE}\nProfile: ${PROFILE}\n${LINE}"
  echo "Capabilities:"
  echo "${PROFILE_OUTPUT}" | jq -r '.spec.requiredCapabilities.[].name'

  echo -e "\nTraits:"
  echo "${PROFILE_OUTPUT}" | jq -r '.spec.traits.[].name'
  echo -e "${LINE}\n"
done

# return to previous settings, if present
echo -e "\nINFO: setting context back to previous settings; if set..."
if [ -n "${PREVIOUS_CONTEXT_PROJECT}" ] && [ "${PREVIOUS_CONTEXT_PROJECT}" != "${TARGET_PROJECT}" ]
then
  echo "INFO: setting project back to '${PREVIOUS_CONTEXT_PROJECT}' from '${TARGET_PROJECT}'..."
  tanzu project use "${PREVIOUS_CONTEXT_PROJECT}"
fi

if [ -n "${PREVIOUS_CONTEXT_SPACE}" ] && [ "${PREVIOUS_CONTEXT_SPACE}" != "${TARGET_SPACE}" ]
then
  echo "INFO: setting space back to '${PREVIOUS_CONTEXT_SPACE}' from '${TARGET_SPACE}'..."
  tanzu space use "${PREVIOUS_CONTEXT_SPACE}"
fi
