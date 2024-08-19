# scripts

These are random scripts that have been helpful in some way

## `check_for_missing_capabilities.sh`

This script compares cluster group capabilities to the capabiliites applied to a space via it's profile(s) for Tanzu Platform.

## `get_cpu_memory_metrics.sh`

This script gets CPU and memory metrics (requests or limits) for either a list of namespaces or all namespaces of a k8s cluster and formats them as a table.

## `get_cpu_memory_metrics_manual.sh`

This script outputs CPU and memory requests and limits in a human readable table format

## `get_cpu_memory_metrics_manual_daemonsets_nondaemonsets.sh`

This script is similar to the last one but filters pods based on if they're a daemonset or not.
