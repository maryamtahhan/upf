<!--
SPDX-License-Identifier: Apache-2.0
Copyright 2019 Intel Corporation
-->

# UPF with DPDK 23.07 patched with the AF_XDP DP integration support and pinned map support

[![Go Report Card](https://goreportcard.com/badge/github.com/omec-project/upf)](https://goreportcard.com/report/github.com/omec-project/upf)

[![Build Status](https://jenkins.onosproject.org/buildStatus/icon?job=bess-upf-linerate-tests&subject=Linerate+Tests)](https://jenkins.onosproject.org/job/bess-upf-linerate-tests/)

This project implements a 4G/5G User Plane Function (UPF) compliant with 3GPP
TS23.501. It follows the 3GPP Control and User Plane Separation (CUPS)
architecture, making use of the PFCP protocol for the communication between
SMF (5G) / SPGW-C (4G) and UPF.

This UPF implementation is actively used as part of the
[Aether platform](https://opennetworking.org/aether/) in conjunction with the
SD-Core mobile core control plane.

### Table Of Contents
  * [Overview](#overview)
  * [Feature List](#feature-list)
  * [Getting Started](#getting-started)
  * [Contributing](#contributing)
  * [Support](#support)
  * [License](#license)


## Overview

The UPF implementation consists of two layers:

- **PFCP Agent (_pfcpiface_)**: a Go-based implementation of the PFCP northbound API used to interact with the mobile core control plane.
- **Datapath:** responsible for the actual data plane packet processing.

The PFCP Agent implements datapath plugins that translate
  PFCP messages to datapath-specific configurations. We currently support two
  datapath implementations:
  - [BESS](https://github.com/omec-project/bess): a software-based datapath
    built on top of the Berkeley Extensible Software Switch (BESS) framework.
    For more details, please see the ONFConnect 2019 [talk](https://www.youtube.com/watch?v=fqJGWcwcOxE)
    and demo videos [here](https://www.youtube.com/watch?v=KxK64jalKHw) and
    [here](https://youtu.be/rWnZuJeUWi4).
    > Note: The source code for the BESS-based datapath is in https://github.com/omec-project/bess
  - [UP4](https://github.com/omec-project/up4): an implementation leveraging
    ONOS and P4-programmable switches to realize a hardware-based datapath.

The combination of PFCP Agent and UP4 is usually referred to as P4-UPF. While
BESS-UPF denotes the combination of PFCP Agent and the BESS datapath.

PFCP Agent internally abstracts different datapaths using a common API, while
the different plug-ins can use specific southbound protocols to communicate with
the different datapath instances. Support for new datapaths can be provided by
implementing new plugins.

![UPF overview](./docs/images/upf-overview.jpg)

This repository provides code to build two Docker images: `pfcpiface` (the PFCP
Agent) and `bess` (the BESS-based datapath).

To build all Docker images run:

```
make docker-build
```

To build a selected image use `DOCKER_TARGETS`:

```
DOCKER_TARGETS=pfcpiface make docker-build
```

The latest Docker images are also published in the OMEC project's DockerHub
registry: [upf-epc-bess](https://hub.docker.com/r/omecproject/upf-epc-bess),
[upf-epc-pfcpiface](https://hub.docker.com/r/omecproject/upf-epc-pfcpiface).

### BESS-UPF Components

![upf](docs/images/upf.svg)

### Zoom-in

![bess-programming](docs/images/bess-programming.svg)

## Feature List

### PFCP Agent
* PFCP Association Setup/Release and Heartbeats
* Session Establishment/Modification with support for PFCP entities such as
  Packet Detection Rules (PDRs), Forwarding Action Rules (FARs), QoS Enforcement
  Rules (QERs).
* UPF-initiated PFCP association
* UPF-based UE IP address assignment
* Application filtering using SDF filters
* Generation of End Marker Packets
* Downlink Data Notification (DDN) using PFCP Session Report
* Integration with Prometheus for exporting PFCP and data plane-level metrics.
* Application filtering using application PFDs (_**experimental**_).

### BESS-UPF
* IPv4 support
* N3, N4, N6, N9 interfacing
* Single & Multi-port support
* Monitoring/Debugging capabilities using
  - tcpdump on individual BESS modules
  - visualization web interface
  - command line shell interface for displaying statistics
* Static IP routing
* Dynamic IP routing
* Support for IPv4 datagrams reassembly
* Support for IPv4 packets fragmentation
* Support for UE IP NAT
* Service Data Flow (SDF) configuration via N4/PFCP
* I-UPF/A-UPF ULCL/Branching i.e., simultaneous N6/N9 support within PFCP session
* Downlink Data Notification (DDN) - notification only (no buffering)
* Basic QoS support, with per-slice and per-session rate limiting
* Per-flow latency and throughput metrics
* DSCP marking of GTPu packets by copying the DSCP value from the inner IP packet
* Network Token Functions (_**experimental**_)
* Support for DPDK, CNDP

### P4-UPF
P4-UPF implements a core set of features capable of supporting requirements for
a broad range of enterprise use cases.

See the [ONF's blog post](https://opennetworking.org/news-and-events/blog/using-p4-and-programmable-switches-to-implement-a-4g-5g-upf-in-aether/)
for an overview of P4-UPF. Additionally, refer to the [SD-Fabric documentation](https://docs.sd-fabric.org/master/advanced/p4-upf.html)
for the detailed feature set.

## Getting started

### Installation

Please see installation document [here](docs/INSTALL.md) for details on how to
set up the PFCP Agent with BESS-UPF.

To install the PFCP Agent with UP4 please follow the [SD-Fabric documentation](https://docs.sd-fabric.org/master/index.html).

### Configuration

Please see the configuration guide [here](docs/configuration-guide.md) to learn
more about the different configurations.

### Testing

The UPF project currently implements three types of tests:
  - Unit tests
  - E2E integration tests
  - PTF tests for BESS-UPF

**Unit tests** for the PFCP Agent's code. To run unit tests use:

```
make test
```

**E2E integration tests** that verify the inter-working between the PFCP Agent
and a datapath.

We provide two modes of E2E integration tests: `native` and `docker`.

The `native` mode invokes Go objects directly from the `go test` framework, thus
it makes the test cases easier to debug. To run E2E integration tests for
BESS-UPF in the `native` mode use:

```
make test-bess-integration-native
```

The `docker` mode uses fully containerized environment and runs all components
(the PFCP Agent and a datapath mock) as Docker containers. It ensures the
correct behavior of the package produced by the UPF project. To run E2E
integration tests for UP4 in the `docker` mode use:

```
make test-up4-integration-docker
```

> NOTE: The `docker` mode for BESS-UPF and the `native` mode for UP4 are not implemented yet.

**PTF tests for BESS-UPF** verify the BESS-based implementation of the UPF
datapath (data plane). Details to run PTF tests for BESS-UPF can be found [here](./ptf/README.md).

## Contributing

The UPF project welcomes new contributors. Feel free to propose a new feature,
integrate a new UPF datapath or fix bugs!

Before contributing, please follow these guidelines:

* Check out [open issues](https://github.com/omec-project/upf/issues).
* Check out [the developer guide](./docs/developer-guide.md).
* We follow the best practices described in https://google.github.io/eng-practices/review/developer/.
  Get familiar with them before submitting a PR.
* Both unit and E2E integration tests must pass on CI. Please make sure that
  tests are passing with your change (see [Testing](#testing) section).

## Support

To report any other kind of problem, feel free to open a GitHub Issue or reach
out to the project maintainers on the ONF Community Slack ([aether-dev](https://app.slack.com/client/T095Z193Q/C01E4HMLBNV)).

## License

The project is licensed under the [Apache License, version 2.0](./LICENSES/Apache-2.0.txt).

## UPF in K8s with DPDK-AF_XDP instructions

Ensure to interfaces are bound to DPDK

```
[upf]# ls /etc/cni/net.d
[upf]# rm -rf /etc/cni/net.d/*
[upf]# swapoff -av
[upf]# free -h
[upf]# kubeadm init --pod-network-cidr=10.244.0.0/16
[upf]# export KUBECONFIG=/etc/kubernetes/admin.conf
[upf]# kubectl taint nodes --all node-role.kubernetes.io/control-plane-
[upf]# kubectl label node wsfd-advnetlab47.anl.lab.eng.bos.redhat.com cndp="true"
[upf]# kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
[upf]# kubectl describe node
[upf]# kubectl get node #### wait for ready
[upf]# kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
[upf]# kubectl create -f deployments/sriovdp-config.yaml
[upf]# kubectl create -f deployments/sriovdp-daemonset.yaml
```

```
[upf]#  kubectl get ds -n kube-system kube-sriov-device-plugin-amd64
NAME                             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR              AGE
kube-sriov-device-plugin-amd64   1         1         1       1            1           kubernetes.io/arch=amd64   64s

[upf]# kubectl get node  -o json | jq '.items[].status.allocatable'
{
  "cpu": "64",
  "ephemeral-storage": "106539201155",
  "hugepages-1Gi": "0",
  "hugepages-2Mi": "8704Mi",
  "intel.com/intel_sriov_access": "1",
  "intel.com/intel_sriov_vfio_core": "1",
  "memory": "187608100Ki",
  "pods": "110"
}

[upf]# kubectl create -f deployments/upf-k8s-af-xdp-dpdk.yaml
networkattachmentdefinition.k8s.cni.cncf.io/access-net created
networkattachmentdefinition.k8s.cni.cncf.io/core-net created
configmap/upf-conf created
pod/upf created
```

```
[upf]# kubectl port-forward  upf 8000:8000
```

Assuming you've ssh'd to your test machine with port forwarding:

```
ssh -L 8000:localhost:8000 user@dut.example.com
```

You can now use your browser to view the UPF pipeline by navigating to `localhost:8000`.

This next command to install the PDRs takes a while. Be Patient. You can see the PDRs updating.

```
[upf]# kubectl exec  upf --container pfcpiface -- pfcpiface -config /opt/bess/bessctl/conf/upf.json -bess localhost:10514  -simulate create
time="2023-10-11T09:49:07Z" level=info msg="{Mode:af_xdp AccessIface:{IfName:ens3f0np0} CoreIface:{IfName:ens3f1np1} CPIface:{Peers:[148.162.12.214] UseFQDN:false NodeID: HTTPPort:8080 Dnn:internet EnableUeIPAlloc:false UEIPPool:10.250.0.0/16} P4rtcIface:{SliceID:0 AccessIP:172.17.0.1/32 P4rtcServer:onos P4rtcPort:51001 QFIToTC:map[] DefaultTC:3 ClearStateOnRestart:false} EnableP4rt:false EnableFlowMeasure:false SimInfo:{MaxSessions:50000 StartUEIP:16.0.0.1 StartENBIP:11.1.1.129 StartAUPFIP:13.1.1.199 N6AppIP:6.6.6.6 N9AppIP:9.9.9.9 StartN3TEID:0x30000000 StartN9TEID:0x90000000} ConnTimeout:0 ReadTimeout:15 EnableNotifyBess:false EnableEndMarker:false NotifySockAddr: EndMarkerSockAddr: LogLevel:debug QciQosConfig:[{QCI:0 CBS:50000 PBS:50000 EBS:50000 BurstDurationMs:10 SchedulingPriority:7} {QCI:9 CBS:2048 PBS:2048 EBS:2048 BurstDurationMs:0 SchedulingPriority:6} {QCI:8 CBS:2048 PBS:2048 EBS:2048 BurstDurationMs:0 SchedulingPriority:5}] SliceMeterConfig:{N6RateBps:500000000 N6BurstBytes:625000 N3RateBps:500000000 N3BurstBytes:625000} MaxReqRetries:5 RespTimeout:2s EnableHBTimer:false HeartBeatInterval:}" func=main.main file="/pfcpiface/cmd/pfcpiface/main.go:37"
time="2023-10-11T09:49:07Z" level=info msg="SetUpfInfo bess" func="github.com/omec-project/upf-epc/pfcpiface.(*bess).SetUpfInfo" file="/pfcpiface/pfcpiface/bess.go:675"
time="2023-10-11T09:49:07Z" level=info msg="bessIP  localhost:10514" func="github.com/omec-project/upf-epc/pfcpiface.(*bess).SetUpfInfo" file="/pfcpiface/pfcpiface/bess.go:679"
time="2023-10-11T09:49:07Z" level=debug msg="Clearing all the state in BESS" func="github.com/omec-project/upf-epc/pfcpiface.(*bess).clearState" file="/pfcpiface/pfcpiface/bess.go:631"
time="2023-10-11T09:49:07Z" level=info msg="create sessions: 50000" func="github.com/omec-project/upf-epc/pfcpiface.(*upf).sim" file="/pfcpiface/pfcpiface/grpcsim.go:72"
time="2023-10-11T09:58:07Z" level=info msg="Sessions/s: 92.67690409334031" func="github.com/omec-project/upf-epc/pfcpiface.(*upf).sim" file="/pfcpiface/pfcpiface/grpcsim.go:271"
```
### Kubeadm reset

```
[upf]# kubeadm reset
[upf]# unset KUBECONFIG
[upf]# rm -rf $HOME/.kube/
[upf]# systemctl daemon-reload
[upf]# systemctl restart kubelet
[upf]# systemctl restart containerd
[upf]# ls /etc/cni/net.d
[upf]# rm -rf /etc/cni/net.d/*
[upf]# swapoff -av
[upf]# free -h
```

Then jump back to the previous section where `kubeadm init ...` is called.

### Common issues

#### Loopback CNI issue when creating UPF:

```
Events:
  Type     Reason                  Age                   From               Message
  ----     ------                  ----                  ----               -------
  Normal   Scheduled               13m                   default-scheduler  Successfully assigned default/upf to wsfd-advnetlab47.anl.lab.eng.bos.redhat.com
  Warning  FailedCreatePodSandBox  13m                   kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "5805bc533a32ad79bf5a2bc87a9d831017190eb83d904b151d9c28ca38a5f4f4": plugin type="loopback" failed (add): failed to find plugin "loopback" in path [/opt/cni/bin]
  Normal   SandboxChanged          3m10s (x49 over 13m)  kubelet            Pod sandbox changed, it will be killed and re-created.
```

Soln: Build and install all the default cni plugins.

```
[plugins]# dnf install golang
[plugins]# git clone https://github.com/containernetworking/plugins.git
[plugins]# cd plugins
[plugins]# ./build_linux.sh
[plugins]# ls bin/
bandwidth  bridge  dhcp  dummy  firewall  host-device  host-local  ipvlan  loopback  macvlan  portmap  ptp  sbr  static  tap  tuning  vlan  vrf
[plugins]# cp /root/git-workspace/plugins/bin/loopback /opt/cni/bin/

[plugins]#  cat >/etc/cni/net.d/99-loopback.conf <<EOF
{
	"cniVersion": "0.2.0",
	"name": "lo",
	"type": "loopback"
}
EOF
```

#### Disable zram swap Fedora 38

Details can be found (here)[https://fedoraproject.org/wiki/Changes/SwapOnZRAM#:~:text=The%20swap%2Don%2Dzram%20feature,and%20customized%20by%20editing%20it].

```
sudo touch /etc/systemd/zram-generator.conf
```


#### If you are using VFs rather than a PF

Note, this won't work for AF_XDP as there's no VF driver that supports AF_XDP right now.
But in the case of DPDK PMD you will need to move from the HostDevice CNI used in `upf-k8s-af-xdp-dpdk.yaml`
to the SR_IOV CNI.

Install the SR_IOV CNI
```
 git clone https://github.com/k8snetworkplumbingwg/sriov-cni.git
 cd sriov-cni/
 kubectl apply -f images/sriov-cni-daemonset.yaml
```

Then update the `deployments/upf-k8s.yaml` to use it.

#### NO IP addresses available in range error

```
Events:
  Type     Reason                  Age   From               Message
  ----     ------                  ----  ----               -------
  Normal   Scheduled               17s   default-scheduler  Successfully assigned default/upf to wsfd-advnetlab47.anl.lab.eng.bos.redhat.com
  Normal   AddedInterface          17s   multus             Add eth0 [10.244.0.2/24] from cbr0
  Warning  FailedCreatePodSandBox  16s   kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "ed81c0503efcab93b8e2f0510e9b1417fb259b3f0e055209c6d59b759b897b64": plugin type="multus" name="multus-cni-network" failed (add): [default/upf/0a9c5e41-58b0-4ebe-9ada-bfcd142349a0:access-net]: error adding container to network "access-net": failed to allocate for range 0: no IP addresses available in range set: 198.18.0.1-198.18.0.1
  Normal   AddedInterface          4s    multus             Add eth0 [10.244.0.3/24] from cbr0
  Warning  FailedCreatePodSandBox  3s    kubelet            Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "267307c6f3aa6205c26ce780f26f91d86d7738888a76f620652a9396b7a45bd3": plugin type="multus" name="multus-cni-network" failed (add): [default/upf/0a9c5e41-58b0-4ebe-9ada-bfcd142349a0:access-net]: error adding container to network "access-net": failed to allocate for range 0: no IP addresses available in range set: 198.18.0.1-198.18.0.1
[upf]# ls /var/lib/cni/networks/kubernetes/
ls: cannot access '/var/lib/cni/networks/kubernetes/': No such file or directory
[upf]# ls /var/lib/cni/networks/
access-net  cbr0  core-net
[upf]# ls /var/lib/cni/networks/access-net/
198.18.0.1  last_reserved_ip.0  lock
[upf]#  kubectl describe upf^C
[upf]# rm -rf  /var/lib/cni/networks/
access-net/ cbr0/       core-net/
[upf]# rm -rf  /var/lib/cni/networks/
access-net/ cbr0/       core-net/
[upf]# rm -rf  /var/lib/cni/networks/access-net/*
[upf]# rm -rf  /var/lib/cni/networks/core-net/*
```
