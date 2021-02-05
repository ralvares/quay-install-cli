# quay-install-cli
Deploy Red Hat Quay v3.4 container registry on OpenShift 4.6 using the Quay Operator.

This repo is based on official Quay documentation [DEPLOY RED HAT QUAY ON OPENSHIFT WITH THE QUAY OPERATOR](https://access.redhat.com/documentation/en-us/red_hat_quay/3.4/html/deploy_red_hat_quay_on_openshift_with_the_quay_operator/index)

## Object Storage setup ([PREREQUISITE](https://access.redhat.com/documentation/en-us/red_hat_quay/3.4/html/deploy_red_hat_quay_on_openshift_with_the_quay_operator/con-quay-openshift-prereq))
By default, the Red Hat Quay Operator uses the ObjectBucketClaim Kubernetes API to provision object storage. Consuming this API decouples the Operator from any vendor-specific implementation. OpenShift Container Storage provides this API via its NooBaa component, which will be used in this example.

Ensure that the RHOCS operator exists in the channel catalog.
```shell script
oc get packagemanifests -n openshift-marketplace | grep ocs
```

Query the available channels for RHOCS operator
```shell script
oc get packagemanifest -o jsonpath='{range .status.channels[*]}{.name}{"\n"}{end}{"\n"}' -n openshift-marketplace ocs-operator
```

Discover whether the operator can be installed cluster-wide or in a single namespace
```shell script
oc get packagemanifest -o jsonpath='{range .status.channels[*]}{.name}{" => cluster-wide: "}{.currentCSVDesc.installModes[?(@.type=="AllNamespaces")].supported}{"\n"}{end}{"\n"}' -n openshift-marketplace ocs-operator
```
To install an operator in a specific project (in case of cluster-wide false), you need to create first an OperatorGroup in the target namespace. An OperatorGroup is an OLM resource that selects target namespaces in which to generate required RBAC access for all Operators in the same namespace as the OperatorGroup.

Check the CSV information for additional details
```shell script
oc describe packagemanifests/quay-operator -n openshift-marketplace | grep -A36 Channels
```

### Create a Project for RHOCS
[ocs-namespace.yaml](ocs-namespace.yaml)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    openshift.io/description: "Red Hat OpenShift Container Storage"
    openshift.io/display-name: "RHOCS"
  name: openshift-storage
```
```shell script
oc apply -f ocs-namespace.yaml
```
or
```shell script
oc new-project openshift-storage
```

### Create an OperatorGroup
[ocs-og.yaml](ocs-og.yaml)
```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ocs-og
  generateName: ocs-
  namespace: openshift-storage
spec:
  targetNamespaces:
    - openshift-storage
```
```shell script
oc apply -f ocs-og.yaml
```

### Create an OCS Subscription
[ocs-sub.yaml](ocs-sub.yaml)
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ocs-operator
  namespace: openshift-storage
spec:
  channel: stable-4.6
  installPlanApproval: Automatic
  name: ocs-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```
```shell script
oc apply -f ocs-sub.yaml
```

### Create NooBaa object storage
[ocs-noobaa-cr.yaml](ocs-noobaa-cr.yaml)
```yaml
apiVersion: noobaa.io/v1alpha1
kind: NooBaa
metadata:
  name: noobaa
  namespace: openshift-storage
spec:
  dbResources:
    requests:
      cpu: '0.1'
      memory: 1Gi
  coreResources:
    requests:
      cpu: '0.1'
      memory: 1Gi
```
```shell script
oc apply -f ocs-noobaa-cr.yaml
```

## Quay Setup Procedure

Ensure that the Quay operator exists in the channel catalog.
```shell script
oc get packagemanifests -n openshift-marketplace | grep quay
```

Query the available channels for Quay operator
```shell script
oc get packagemanifest -o jsonpath='{range .status.channels[*]}{.name}{"\n"}{end}{"\n"}' -n openshift-marketplace quay-operator
```

Discover whether the operator can be installed cluster-wide or in a single namespace
```shell script
oc get packagemanifest -o jsonpath='{range .status.channels[*]}{.name}{" => cluster-wide: "}{.currentCSVDesc.installModes[?(@.type=="AllNamespaces")].supported}{"\n"}{end}{"\n"}' -n openshift-marketplace quay-operator
```

Check the CSV information for additional details
```shell script
oc describe packagemanifests/quay-operator -n openshift-marketplace | grep -A36 Channels
```

### Create a Project for Quay
[quay-namespace.yaml](quay-namespace.yaml)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    openshift.io/description: "Red Hat Quay Enterprise Container Image Repository"
    openshift.io/display-name: "Quay"
  name: quay
```
```shell script
oc apply -f quay-namespace.yaml
```
or
```shell script
oc new-project quay
```

### Create a Quay Subscription
[quay-sub.yaml](quay-sub.yaml)
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: quay-operator
  namespace: openshift-operators
spec:
  channel: quay-v3.4
  installPlanApproval: Automatic
  name: quay-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```
```shell script
oc apply -f quay-sub.yaml
```
create a pull secret in your project (get your evaluation sub here https://access.redhat.com/products/red-hat-quay/evaluation)

[quay-secret.yaml](quay-secret.yaml)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redhat-quay-pull-secret
  namespace: quay
data:
  .dockerconfigjson: >-
    <YOUR-PULL-SECRET>
type: kubernetes.io/dockerconfigjson
```
```shell script
oc apply -f quay-secret.yaml
```

### Deploy QuayRegistry CR example

[quay-cr.yaml](quay-cr.yaml)
```yaml
apiVersion: quay.redhat.com/v1
kind: QuayRegistry
metadata:
  name: container-registry
  namespace: quay
```
```shell script
oc apply -f quay-cr.yaml
```

Retrieve all the created objects belonging to the operator
```shell script
oc get $(oc get $CSV -o json |jq -r '[.spec.customresourcedefinitions.owned[]|.name]|join(",")')
```

### Access Quay GUI
```shell script
oc get routes
```
You should see 3 routes:
- container-registry-quay — is for connecting to the registry

connect to the route named **container-registry-quay** using your browser

you'll need to create an account

### Test
login to Quay
```shell script
podman login -u="quay" -p="password" quayecosystem-quay-quay.<YOUR-DOMAIN> --tls-verify=false
```
pull ubi image from registry.access.redhat.com
```shell script
podman pull registry.access.redhat.com/ubi8/ubi:latest
```
push ubi to quay/myrepo 
```shell script
podman push registry.access.redhat.com/ubi8/ubi quayecosystem-quay-quay.<YOUR-DOMAIN>/quay/myrepo:ubi --tls-verify=false
```
verify in quay that image is received and no vulnerabilities are found

pull minecraft-server from docker.io
```shell script
podman pull docker.io/itzg/minecraft-server:latest
```
push minecraft-server to quay/myrepo
```shell script
podman push docker.io/itzg/minecraft-server quayecosystem-quay-quay.<YOUR-DOMAIN>/quay/myrepo:minecraft --tls-verify=false
```
verify in quay that image is received and Clair has found vulnerabilities


## Install Quay Security Operator

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: container-security-operator
  namespace: openshift-operators
spec:
  channel: quay-v3.4
  installPlanApproval: Automatic
  name: container-security-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```
```shell script
oc apply -f quay-security.yaml
```