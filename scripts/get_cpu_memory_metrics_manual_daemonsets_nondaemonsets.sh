#!/usr/bin/env bash

# manual tables of requests & limits

# daemonsets
kubectl get pods -n istio-system -o custom-columns=NAME:.metadata.name,CONTROLLER:.metadata.ownerReferences[].kind,CPUR:.spec.containers[*].resources.requests.cpu,MEMR:.spec.containers[*].resources.requests.memory,CPUL:.spec.containers[*].resources.limits.cpu,MEML:.spec.containers[*].resources.limits.memory | grep DaemonSet

# non-daemonsets
kubectl get pods -n istio-system -o custom-columns=NAME:.metadata.name,CONTROLLER:.metadata.ownerReferences[].kind,CPUR:.spec.containers[*].resources.requests.cpu,MEMR:.spec.containers[*].resources.requests.memory,CPUL:.spec.containers[*].resources.limits.cpu,MEML:.spec.containers[*].resources.limits.memory | grep -v DaemonSet

