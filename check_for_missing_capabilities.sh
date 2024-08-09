#!/usr/bin/env bash

# based on a script by Orf Gelbrich
# compares cluster group capabilities to the capabiliites applied to a space via it's profile(s)
# usage:
#   - update the 'TARGET_*' env vars to specify the project, space, and clustergroup
# when using 'git diff' as the diff tool, green capabilities are those that need to be installed to the cluster group as they're missing

# set the target project, space, and cluster group to inspect
TARGET_PROJECT="AMER-East"
# TODO: try to be able to find the clustergroup from the space via the availability target (there might be multiple cluster groups)
# TODO: verify that we can see the space and clustergroup
# TODO: make sure all jq commands go to 2>/dev/null to catch errors

#TARGET_SPACE="cro-fxg-space"
#TARGET_SPACE="cro-fxd-space"
#TARGET_SPACE="cro-fxg-space-2"
#TARGET_CLUSTERGROUP="cro-fxg-cg"

#TARGET_SPACE="mbentley-space"
#TARGET_CLUSTERGROUP="mbentley-clustergroup"

TARGET_SPACE="orf-rabbitmq-01"
TARGET_CLUSTERGROUP="orfclustergroup2"

# set the diff tool to use
DIFF_TOOL="sdiff"
#DIFF_TOOL="diff --color -u"

### END USER MODIFYABLE OBJECTS; DO NOT CHANGE BELOW HERE

# function that just indents output
_indent() {
  sed 's/^/  /'
}

# let user know what we're checking
echo -e "INFO: checking capabilities for:
  Project:          ${TARGET_PROJECT}
  Space:            ${TARGET_SPACE}
  Cluster Group:    ${TARGET_CLUSTERGROUP}\n"

# save current context as "previous" to restore later
PREVIOUS_CONTEXT="$(tanzu context current --short)"
PREVIOUS_CONTEXT_PROJECT="$(echo "${PREVIOUS_CONTEXT}" | awk -F ':' '{print $2}')"
PREVIOUS_CONTEXT_SPACE="$(echo "${PREVIOUS_CONTEXT}" | awk -F ':' '{print $3}')"

# get current org info
TANZU_CONTEXT_LIST="$(tanzu context list -o json)"

# check the org (just make sure the active context is type tanzu
ACTIVE_TANZU_CONTEXT="$(echo "${TANZU_CONTEXT_LIST}" | jq -r '.[] | select((.type == "tanzu") and (.iscurrent == "true")) | .name')"
if [ -z "${ACTIVE_TANZU_CONTEXT}" ]
then
  # we need to configure the context
  echo "ERROR: make sure to have created a 'tanzu' context and is set set as the current context; for example:"
  echo "  export TANZU_CLI_CLOUD_SERVICES_ORGANIZATION_ID=\"77aee83b-308f-4c8e-b9c4-3f7a6f19ba75\""
  echo "  tanzu login"
  echo -e "\nCurrent contexts:\n$(tanzu context list 2>/dev/null)"
  exit 1
else
  # we have a 'tanzu' context that is current
  echo "INFO: check passed; current context (${ACTIVE_TANZU_CONTEXT}) is a 'tanzu' type context"
fi

# variable to output a line of standard length
LINE="-------------------------------------------------------------"
#LINE="-------------------------------------------------"

# set the project
echo "INFO: setting project to ${TARGET_PROJECT}..."
tanzu project use "${TARGET_PROJECT}"

# set the clustergroup, if different
echo "INFO: setting clustergroup to ${TARGET_CLUSTERGROUP}..."
tanzu operations clustergroup use "${TARGET_CLUSTERGROUP}"

# start output for the clustergroup
echo "INFO: retrieving capabilities for the clustergroup '${TARGET_CLUSTERGROUP}'..."
CLUSTERGROUP_OUTPUT="$(echo -e "${LINE}\nCluster Group Capabilities\n${LINE}")"

# get one of the clusters from the clustergroup to get data on
CLUSTERS="$(tanzu operations cluster list -o json)"
CLUSTER_NAME="$(echo "${CLUSTERS}" | jq -r '.clusters[] | select(.spec.clusterGroupName == "'"${TARGET_CLUSTERGROUP}"'") | .fullName.name' | head -n 1)"

# verify we found a cluster
if [ -z "${CLUSTER_NAME}" ]
then
  echo "ERROR: no clusters found in clustergroup (${TARGET_CLUSTERGROUP})!"
  exit 1
fi
CLUSTERGROUP_CAPABILITIES="$(kubectl --kubeconfig "${HOME}/.config/tanzu/kube/config" get kubernetescluster "${CLUSTER_NAME}" -o json | jq -r '.status.capabilities[].name' | sort)"
CLUSTERGROUP_OUTPUT="$(echo -e "${CLUSTERGROUP_OUTPUT}\n${CLUSTERGROUP_CAPABILITIES}")"

# set the space
echo "INFO: setting space to ${TARGET_SPACE}..."
tanzu space use "${TARGET_SPACE}"
echo

SPACE_OUTPUT="$(echo -e "${LINE}\nSpace Capabilities\n${LINE}")"

# get the capabilities provided by the space
echo "INFO: retrieving capabilities for the space '${TARGET_SPACE}'..."
SPACE_CAPABILITIES="$(tanzu space get "${TARGET_SPACE}" -o json | jq -r '.status.providedCapabilities[].name' 2>/dev/null | sort)"
SPACE_OUTPUT="$(echo -e "${SPACE_OUTPUT}\n${SPACE_CAPABILITIES}")"

# see if we have any capabilities in the list
if [ -z "${SPACE_CAPABILITIES}" ]
then
  echo "WARN: there are no capabilities assigned to your space (${TARGET_SPACE})!"
fi

# get info about the profiles set on the space
PROFILES_ASSIGNED="$(tanzu space get "${TARGET_SPACE}" -o json | jq -r '.spec.template.spec.profiles[].name' 2>/dev/null)"

# check to see if we have anything for profiles assigned
if [ -z "${PROFILES_ASSIGNED}" ]
then
  # no profiles assigned
  echo "WARN: there are no profiles assigned to your space (${TARGET_SPACE})!"
else
  # there are profiles assigned
  echo "INFO: the following profiles are configured for your space (${TARGET_SPACE}):"
  for PROFILE in ${PROFILES_ASSIGNED}
  do
    PROFILE_OUTPUT="$(tanzu profile get "${PROFILE}" -o json)"
    echo -e "${LINE}\nProfile: ${PROFILE}\n${LINE}"
    echo "Capabilities:"
    echo "${PROFILE_OUTPUT}" | (jq -r '.spec.requiredCapabilities[].name' 2>/dev/null || echo "<none found>") | _indent

    echo -e "Traits:"
    echo "${PROFILE_OUTPUT}" | (jq -r '.spec.traits[].name' 2>/dev/null || echo "<none found>") | _indent
    echo -e "${LINE}\n"
  done
fi

# do a diff to see the changes side by side between the clustergroup and space
echo -e "\nINFO: ${DIFF_TOOL%% *} between the clustergroup and space:"
${DIFF_TOOL} <(echo "${CLUSTERGROUP_OUTPUT}") <(echo "${SPACE_OUTPUT}")
echo "${LINE}"

# final output
echo -e "\n\n${LINE}\nSummary of clustergroup and space capabilities\n${LINE}"
# output extra capabilities not required
EXTRA_CAPABILITIES="$(diff -u <(echo "${CLUSTERGROUP_OUTPUT}") <(echo "${SPACE_OUTPUT}") | grep -vE '(^---)|(^-Cluster Group Capabilities$)' | grep '^-')"
if [ -z "${EXTRA_CAPABILITIES}" ]
then
  # no extra
  echo -e "INFO: there are no extra/unused capabilities installed to the clustergroup"
else
  # extra
  echo -e "INFO: the following capabilities are NOT required by the profile(s) selected but have been installed (this is not a problem; just FYI):"
  echo "${EXTRA_CAPABILITIES}" | cut -c 2- | _indent
fi

# output missing capabilities
MISSING_CAPABILITIES="$(diff -u <(echo "${CLUSTERGROUP_OUTPUT}") <(echo "${SPACE_OUTPUT}") | grep -vE '(^\+\+\+)|(^\+Space Capabilities$)' | grep '^+')"
if [ -z "${MISSING_CAPABILITIES}" ]
then
  # no missing
  echo -e "\nINFO: all of the required capabilities were found installed to the clustergroup; the space should be 'ready'"
else
  # missing
  echo -e "\nWARN: the following capabilities ARE required by the profile(s) selected but have not been installed; the space will not be 'ready' until they're installed:"
  echo "${MISSING_CAPABILITIES}" | cut -c 2- | _indent
fi
echo "${LINE}"

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
