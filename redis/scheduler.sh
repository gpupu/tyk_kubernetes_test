#!/bin/sh
#
# A kubernetes scheduler written in bash
# dependancies: kubectl, curl
# Runs against localhost:8001 by default
# Use `kubectl proxy` to proxy to master without https
#
# Author: Justin Garrison
# justingarrison.com
# @rothgar
# https://raw.githubusercontent.com/rothgar/bashScheduler/main/scheduler.sh

set -eo pipefail
# uncomment to see all commands in stdout
# set -x

#SERVER="${SERVER:-localhost:8001}"
SCHEDULER="${SCHEDULER:-redisScheduler}"
PROCESEDPODS=0


while [ $PROCESEDPODS -lt 6 ] 
do
  # Get a list of all our pods in pending state
  for POD in $(kubectl get pods \
              --output jsonpath='{.items..metadata.name}' \
              --all-namespaces \
              --field-selector=status.phase==Pending); do

    echo "Tratando el pod: "$POD
    SCHEDULER_NAME=$(kubectl -n redis get pod ${POD} \
                    --output jsonpath='{.spec.schedulerName}')
                    
    echo "El scheduler es: "$SCHEDULER_NAME                

    if [ "${SCHEDULER_NAME}" == "${SCHEDULER}" ]; then
      # Get the pod namespace
      NAMESPACE=$(kubectl -n redis get pod ${POD} \
                  --output jsonpath='{.metadata.namespace}')

      # Get an array for all of the nodes
      # We could optionally check if the nodes are ready
      NODES=($(kubectl -n redis get nodes \
              --output jsonpath='{.items..metadata.name}'))

      # Store a number for the length of our NODES array
      NODES_LENGTH=${#NODES[@]}

      # Randomly select a node from the array
      # $RANDOM % $NODES_LENGTH will be the remainder
      # of a random number divided by the length of our nodes
      # In the case of 1 node this is always ${NODES[0]}
      NODE=${NODES[$[$RANDOM % $NODES_LENGTH]]}
      echo "El nodo random es: "$NODE
      if [ "$POD" == "redis-cluster-0" ] || [ "$POD" == "redis-cluster-5" ] ;
      then
         echo "nodo 1 - "${NODES[1]}
         NODE=${NODES[1]}
      elif [ "$POD" == "redis-cluster-1" ] || [ "$POD" == "redis-cluster-3" ];
      then
         echo "nodo 2 - "${NODES[2]}
         NODE=${NODES[2]}
      elif [ "$POD" == "redis-cluster-2" ] || [ "$POD" == "redis-cluster-4" ];
      then    
         echo "nodo 3 - "${NODES[3]}
         NODE=${NODES[3]}
      fi
      

              
       FILE_BINDING='{"apiVersion":"v1","kind":"Binding","metadata": {"name": "%s"},"target": { "apiVersion": "v1","kind": "Node","name": "%s"}}'
       FILE_BIS=$(printf "$FILE_BINDING" "$POD" "$NODE")     
       
       
       destdir=/tmp/binding.json
       touch /tmp/binding.json
         
       if [ -f "$destdir" ]
       then 
            echo "$FILE_BIS" > "$destdir"
       fi   
                
                
       set -e
        EXIT_CODE=0
        kubectl -n redis apply -f $destdir || EXIT_CODE=$?
       echo $EXIT_CODE  \
        && echo "Assigned ${POD} to ${NODE}" \
        || echo "Failed to assign ${POD} to ${NODE}"
           
       PROCESEDPODS=$((PROCESEDPODS+1))     

    fi
  done
  echo "Nothing to do...sleeping."
  sleep 6s
done