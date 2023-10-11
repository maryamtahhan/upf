#!/bin/bash
docker stop pktgen; docker rm pktgen;
docker run --name pktgen -td --restart unless-stopped --cpuset-cpus=23,25,27,29 --ulimit memlock=-1 --cap-add IPC_LOCK -v /dev/hugepages:/dev/hugepages -v "$PWD/conf":/opt/bess/bessctl/conf --device=/dev/vfio/vfio --device=/dev/vfio/noiommu-0 --cap-add=ALL --privileged -v /lib/firmware/intel:/lib/firmware/intel upf-epc-bess:v0.4.0-dev -grpc-url=0.0.0.0:10514
