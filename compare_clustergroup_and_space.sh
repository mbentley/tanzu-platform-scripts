#!/usr/bin/env bash

# save current context
CURRENT_CONTEXT="$(tanzu context current --short)"
#CURRENT_CONTEXT_ORG="$(echo "${CURRENT_CONTEXT}" | awk -F ':' '{print $1}')"
CURRENT_CONTEXT_PROJECT="$(echo "${CURRENT_CONTEXT}" | awk -F ':' '{print $2}')"
CURRENT_CONTEXT_SPACE="$(echo "${CURRENT_CONTEXT}" | awk -F ':' '{print $3}')"

#export KUBECONFIG="${HOME}/.config/tanzu/kube/config"

# set the target project, space, and cluster group to inspect
TARGET_PROJECT="AMER-East"
TARGET_SPACE="cro-fxg-space"
TARGET_CLUSTERGROUP="cro-fxg-cg"

#TARGET_PROJECT="AMER-East"
#TARGET_SPACE="mbentley-space"
#TARGET_CLUSTERGROUP="mbentley-clustergroup"

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

# do a diff using sdiff to see the changes side by side
echo -e "\nINFO: sdiff between the clustergroup and space:"
sdiff <(echo "${CLUSTERGROUP_OUTPUT}") <(echo "${SPACE_OUTPUT}")

# get info about the profiles set on the space
for PROFILE in $(tanzu space get "${TARGET_SPACE}" -o json | jq -r '.spec.template.spec.profiles.[].name')
do
  PROFILE_OUTPUT="$(tanzu profile get mbentley-profile -o json)"
  echo -e "\n${LINE}\n${PROFILE}\n${LINE}"
  echo "Capabilities:"
  echo "${PROFILE_OUTPUT}" | jq -r '.spec.requiredCapabilities.[].name'

  echo -e "\nTraits:"
  echo "${PROFILE_OUTPUT}" | jq -r '.spec.traits.[].name'
done

# return to previous settings, if present
echo -e "\nINFO: setting context back to previous settings; if set..."
if [ -n "${CURRENT_CONTEXT_PROJECT}" ] && [ "${CURRENT_CONTEXT_PROJECT}" != "${TARGET_PROJECT}" ]
then
  echo "INFO: setting project back to '${CURRENT_CONTEXT_PROJECT}' from '${TARGET_PROJECT}'..."
  tanzu project use "${CURRENT_CONTEXT_PROJECT}"
fi

if [ -n "${CURRENT_CONTEXT_SPACE}" ] && [ "${CURRENT_CONTEXT_SPACE}" != "${TARGET_SPACE}" ]
then
  echo "INFO: setting space back to '${CURRENT_CONTEXT_SPACE}' from '${TARGET_SPACE}'..."
  tanzu space use "${CURRENT_CONTEXT_SPACE}"
fi
