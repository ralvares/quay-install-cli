#!/bin/bash

#Make sure you're connected to your OpenShift cluster with admin user before running this script

echo "Creating Quay namespace"
oc apply -f quay-namespace.yaml
echo "Quay namespace created!"
echo " "
echo "Creating Quay OperatorGroup"
oc apply -f quay-og.yaml
echo "Quay OperatorGroup created!"
echo " "
echo "Creating Quay pull secret"
oc apply -f quay-secret.yaml
echo "Quay secret created!"
echo " "
echo "Creating Quay Subscription"
oc apply -f quay-sub.yaml
echo "Quay Subscription created!"
echo " "
echo "Deploying QuayEcosystem CR"
HOSTNAME=$(oc config view --minify -o jsonpath='{.clusters[*].cluster.server}' | rev | cut -d':' -f2 | rev | cut -b 6-)
sed -i -e "s|.cluster-cd57.cd57.example.opentlc.com|$HOSTNAME|g" quay-cr.yaml
oc apply -f quay-cr.yaml
echo "QuayEcosystem created!"
echo " "
echo "Install Quay Security Operator"
oc apply -f quay-security-sub.yaml
echo "Quay Security Operator installed!"
echo " "
#echo "Searching for available routes"
#oc get routes -n quay
#echo "connect to the route named quay using your browser \
#and login using quay\password credentials"