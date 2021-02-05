#!/bin/bash

#Make sure you're connected to your OpenShift cluster with admin user before running this script

echo "***********************************************"
echo "Installing RHOCS Operator"
echo "***********************************************"
echo "Creating RHOCS namespace"
oc apply -f ocs-namespace.yaml
echo " "
echo "Creating RHOCS OperatorGroup"
oc apply -f ocs-og.yaml
echo " "
echo "Creating RHOCS Subscription"
oc apply -f ocs-sub.yaml
echo " "
echo "Wait for RHOCS Operator"
sleep 30
OCS="$(oc get subs -o name -n openshift-storage | grep ocs-operator)"
oc -n openshift-storage wait --timeout=120s --for=condition=CatalogSourcesUnhealthy=False ${OCS}
sleep 60
echo "Creating NooBaa object storage"
oc apply -f ocs-noobaa-cr.yaml
echo " "
sleep 30
echo " "
echo "***********************************************"
echo "Installing Quay Operator"
echo "***********************************************"
echo "Creating Quay namespace"
oc apply -f quay-namespace.yaml
echo " "
echo "Creating Quay pull secret"
oc apply -f quay-secret.yaml
echo " "
echo "Creating Quay Subscription"
oc apply -f quay-sub.yaml
echo "Wait for Quay Operator to become ready"
sleep 30
QUAY="$(oc get subs -o name -n openshift-operators | grep quay-operator)"
oc -n openshift-operators wait --timeout=120s --for=condition=CatalogSourcesUnhealthy=False ${QUAY}
echo " "
sleep 30
echo "Deploying QuayRegistry CR"
oc apply -f quay-cr.yaml
echo " "
sleep 30
echo " "
echo "***********************************************"
echo "Quay Security Operator"
echo "***********************************************"
echo "Install Quay Security Operator"
oc apply -f quay-security-sub.yaml
echo "Quay Security Operator installed!"
echo " "
echo "Searching for available routes"
oc get routes -n quay
echo " "
echo "connect to the route named container-registry-quay using your browser"