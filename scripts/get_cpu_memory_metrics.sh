#!/usr/bin/env bash

# use a specific k8s context (comment out to just use current)
KUBECTL_CONTEXT=(--context mbentley-home-ns1-c1)

# which namespaces to get metrics from
#   TMC = vmware-system-tmc
#   TO = tanzu-observability-saas
#   TSM = vmware-system-tsm AND istio-system
#NAMESPACES="vmware-system-tmc tanzu-observability-saas vmware-system-tsm istio-system"
#NAMESPACES="vmware-system-tmc istio-system"

# ...or just get metrics from all namespaces
NAMESPACES="$(kubectl "${KUBECTL_CONTEXT[@]}" get ns --no-headers -o custom-columns=":metadata.name")"

# which metrics we want to get (requests and/or limits)
METRICS="requests"
#METRICS="requests limits"


### do not change anything below here

# loop through metrics
for METRIC in ${METRICS}
do
  # start grand totals
  GRAND_TOTAL_CPU=0
  GRAND_TOTAL_MEMORY=0

  # start CSV out
  #CSV_OUT="NAMESPACE,CPUs,MEMORY"
  CSV_OUT=""

  # output Metric
  echo -n "INFO: collecting metrics for '${METRIC}'..."

  # loop through namespaces
  for NS in ${NAMESPACES}
  do
    echo -n " ${NS}"
    ### cpu
    # get cpu values
    CPU_METRIC=$(kubectl "${KUBECTL_CONTEXT[@]}" -n "${NS}" get pods -o=jsonpath='{.items[*]..resources.'"${METRIC}"'.cpu}')

    # initialize count value
    TOTAL_CPU=0

    # go through metric to calculate total
    for i in ${CPU_METRIC}
    do
      # check if in millicores
      if [[ "${i}" =~ "m" ]];
      then
        # value in millicores
        i=$(echo "${i}" | awk -F 'm' '{print $1}')
        TOTAL_CPU=$(( TOTAL_CPU + i ))
      else
        # value in CPUs
        TOTAL_CPU=$(( TOTAL_CPU + i*1000 ))
      fi
    done

    # add CPUs to grand total
    GRAND_TOTAL_CPU=$(( GRAND_TOTAL_CPU + TOTAL_CPU ))

    # output total in millicores
    #printf "  %.2f CPUs  " $((10**2 * TOTAL_CPU/1000))e-2

    ### memory
    # get memory values
    MEMORY_METRIC=$(kubectl "${KUBECTL_CONTEXT[@]}" -n "${NS}" get pods -o=jsonpath='{.items[*]..resources.'"${METRIC}"'.memory}')

    # initialize count value
    TOTAL_MEMORY=0

    # go through metric to calculate total
    for i in ${MEMORY_METRIC}
    do
      # check if in a particular value to convert to MiB
      if [[ "${i}" =~ "Mi" ]]
      then
        # value in MiB
        i=$(echo "${i}" | awk -F 'Mi' '{print $1}')
        TOTAL_MEMORY=$(( TOTAL_MEMORY + i ))
      elif [[ "${i}" =~ "M" ]]
      then
        # value in MB
        i=$(echo "${i}" | awk -F 'M' '{print $1}')
        TOTAL_MEMORY=$(( TOTAL_MEMORY + i*954/1000 ))
      elif [[ "${i}" =~ "Gi" ]]
      then
        # value in GiB
        i=$(echo "${i}" | awk -F 'Gi' '{print $1}')
        TOTAL_MEMORY=$(( TOTAL_MEMORY + i*1024 ))
      elif [[ "${i}" =~ "G" ]]
      then
        # value in GB
        i=$(echo "${i}" | awk -F 'G' '{print $1}')
        TOTAL_MEMORY=$(( TOTAL_MEMORY + i*954 ))
      else
        echo "ERROR: unknown value (${i})"
      fi
    done

    # add CPUs to grand total
    GRAND_TOTAL_MEMORY=$(( GRAND_TOTAL_MEMORY + TOTAL_MEMORY ))

    # output total in GB (convert MiB to GB)
    #printf "  %.2f GB memory\n\n" $((10**2 * TOTAL_MEMORY/954))e-2

    # generate CSV output
    CSV_OUT="$(echo "${CSV_OUT}"; echo "${NS},${METRIC},$(printf "%.2f" $((10**2 * TOTAL_CPU/1000))e-2),$(printf "%.2f" $((10**2 * TOTAL_MEMORY/954))e-2)")"
  done

  #echo "Total metrics for '${METRIC}':"
  # output total in millicores
  #printf "Total metrics for '${METRIC}'\n  %.2f CPUs  " $((10**2 * GRAND_TOTAL_CPU/1000))e-2

  # output total in GB (convert MiB to GB)
  #printf "  %.2f GB memory\n\n\n" $((10**2 * GRAND_TOTAL_MEMORY/954))e-2

  # generate CSV output for totals
  CSV_OUT="$(echo "${CSV_OUT}"; echo ",,,,"; echo "Total,${METRIC},$(printf "%.2f" $((10**2 * GRAND_TOTAL_CPU/1000))e-2),$(printf "%.2f" $((10**2 * GRAND_TOTAL_MEMORY/954))e-2)")"

  echo;echo

  # output CSV to columns
  echo "${CSV_OUT}" | column --separator , --table --table-columns NAMESPACE,METRIC,CPUs,MEMORY --table-right CPUs,MEMORY
done
