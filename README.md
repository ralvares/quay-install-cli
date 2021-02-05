# quay-install-cli
Deploy Red Hat Quay v3.3 container registry on OpenShift 4.5 using the Quay Operator.

## Setup Procedure

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

## Install an operator in a namespace using the CLI

To install an operator in a specific project (in case of cluster-wide false), you need to create first an OperatorGroup in the target namespace. An OperatorGroup is an OLM resource that selects target namespaces in which to generate required RBAC access for all Operators in the same namespace as the OperatorGroup.

### Create a Project
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

### Create an OperatorGroup
[quay-og.yaml](quay-og.yaml)
```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: quay-og #name of your OperatorGroup. free choice
  namespace: quay #the namespace in which you want to deploy your operator
spec:
  targetNamespaces:
  - quay #the namespace in which you want to deploy your operator (again)
```
```shell script
oc apply -f quay-og.yaml
```

### Create a Subscription
[quay-sub.yaml](quay-sub.yaml)
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: quay-operator
  namespace: quay
spec:
  channel: quay-v3.3
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
data:
  .dockerconfigjson: >-
    <YOUR-PULL-SECRET>
type: kubernetes.io/dockerconfigjson
```
```shell script
oc apply -f quay-secret.yaml -n quay
```

### Deploy QuayEcosystem CRD example

You can get details about the Custom Resource Definitions (CRD) supported by the operator or retrieve some sample CRDs.

Get the CSV name of the installed Quay operator
```shell script
oc get csv #get operator name
CSV=$(oc get csv -o name |grep /red-hat-quay.) #store the CSV data
```
Query the ClusterServiceVersion (CSV)
```shell script
oc get $CSV -o json |jq -r '.spec.customresourcedefinitions.owned[]|.name' #query the CRDs enabled by the operator
oc get $CSV -o json |jq -r '.metadata.annotations["alm-examples"]' #retrieve the sample CRDs if you need some help to get started
```
Crate a Quay instance using the provided sample CRD
```shell script
oc get $CSV -o json |jq -r '.metadata.annotations["alm-examples"]' |jq '.[0]' |oc apply -f -
```
or using the example [quay-cr.yaml](quay-cr.yaml)
```yaml
apiVersion: redhatcop.redhat.io/v1alpha1
kind: QuayEcosystem
metadata:
  name: quayecosystem
  namespace: quay
spec:
  clair:
    enabled: true
    imagePullSecretName: redhat-quay-pull-secret
  quay:
    imagePullSecretName: redhat-quay-pull-secret
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
You should see 2 routes:
- quayecosystem-quay — is for connecting to the registry
- quayecosystem-quay-config — is for modifying quay registry configurations.

connect to the route named **quayecosystem-quay** using your browser
and login using the default master credentials:

**username:** quay 

**password:** password

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
  channel: quay-v3.3
  installPlanApproval: Automatic
  name: container-security-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```
```shell script
oc apply -f quay-security.yaml
```