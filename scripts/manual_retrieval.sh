#!/usr/bin/env bash

# use a specific k8s context (comment out to just use current)
KUBECTL_CONTEXT=(--context mbentley-home-ns1-c1)

# which namespaces to get metrics from
#NAMESPACES="vmware-system-tmc tanzu-observability-saas vmware-system-tsm istio-system"

# ...or just get metrics from all namespaces
NAMESPACES="$(kubectl "${KUBECTL_CONTEXT[@]}" get ns --no-headers -o custom-columns=":metadata.name")"

# get metrics, outputted with custom columns of:
#    pod name, controller type, cpu reservation, memory reservation, cpu limit, memory limit
for NS in ${NAMESPACES}
do
  echo "${NS}"
  kubectl "${KUBECTL_CONTEXT[@]}" get pods -n "${NS}" -o custom-columns=NAME:.metadata.name,CONTROLLER:.metadata.ownerReferences[].kind,CPUR:.spec.containers[*].resources.requests.cpu,MEMR:.spec.containers[*].resources.requests.memory,CPUL:.spec.containers[*].resources.limits.cpu,MEML:.spec.containers[*].resources.limits.memory
  echo
done
