# SPDX-License-Identifier: Apache-2.0
# Copyright 2020-present Open Networking Foundation
# Copyright 2019 Intel Corporation

# Multi-stage Dockerfile

# Stage bess-deps: fetch BESS dependencies
FROM ubuntu:focal AS bess-deps
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y git \
    build-essential ninja-build \
    python3-pip pkg-config \
    libnuma-dev python3-pyelftools \
    clang llvm lld m4 vim wget  \
    gcc-multilib libdbus-1-dev \
    libgoogle-glog-dev \
    apt-transport-https \
    ca-certificates g++ make pkg-config \
    libunwind8-dev liblzma-dev zlib1g-dev \
    libpcap-dev libssl-dev libnuma-dev git \
    libgflags-dev libgoogle-glog-dev \
    libgraph-easy-perl libgtest-dev libgrpc++-dev \
    libprotobuf-dev libc-ares-dev libbenchmark-dev \
    libgtest-dev protobuf-compiler-grpc python3-scapy \
    python3-pip python3 meson python3-pyelftools curl \
    build-essential libbsd-dev libelf-dev libjson-c-dev \
    libnl-3-dev libnl-cli-3-dev libnuma-dev libpcap-dev \
    meson pkg-config libbpf-dev gcc-multilib clang llvm \
    lld m4 vim wget libprotobuf17

RUN pip install protobuf grpcio scapy pyelftools meson


# BESS pre-reqs
WORKDIR /
ARG BESS_COMMIT=dpdk-2303-patched-cni-map-pinning
RUN git clone https://github.com/maryamtahhan/bess
WORKDIR /bess
RUN git pull
RUN git checkout ${BESS_COMMIT}
RUN cp -a protobuf /protobuf

# Stage bess-build: builds bess with its dependencies
FROM bess-deps AS bess-build
ARG CPU=native
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
        ca-certificates \
        libelf-dev \
        libbpf0 \
        libgoogle-glog-dev

ARG MAKEFLAGS
ENV PKG_CONFIG_PATH=/usr/lib64/pkgconfig
WORKDIR /bess

# Patch and build DPDK
RUN ./build.py -v dpdk

# Build CNDP
RUN ./build.py -v cndp

# Plugins
RUN mkdir -p plugins

## SequentialUpdate
RUN mv sample_plugin plugins

## Network Token
ARG ENABLE_NTF
ARG NTF_COMMIT=master
COPY scripts/install_ntf.sh .
RUN ./install_ntf.sh

# Build and copy artifacts
COPY scripts/build_bess.sh .
RUN ./build_bess.sh && \
    cp bin/bessd /bin && \
    mkdir -p /bin/modules && \
    cp core/modules/*.so /bin/modules && \
    mkdir -p /opt/bess && \
    cp -r bessctl pybess /opt/bess && \
    cp -r core/pb /pb

# Stage bess: creates the runtime image of BESS
#FROM python:3.11.3-slim AS bess
FROM ubuntu:focal AS bess
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        tcpdump \
        libgoogle-glog-dev \
        libprotobuf-c-dev \
        libprotobuf-c1 \
        libprotobuf-dev \
        libprotobuf17 \
        python3-pip \
        libgrpc++-dev \
        libgrpc++ \
        kmod \
        libgraph-easy-perl \
        python3-protobuf && \
    rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir \
        flask \
        grpcio \
        iptools \
        mitogen \
        protobuf==3.20.0 \
        psutil \
        pyroute2 \
        glog \
        scapy

COPY --from=bess-build /opt/bess /opt/bess
COPY --from=bess-build /bin/bessd /bin/bessd
COPY --from=bess-build /bin/modules /bin/modules
COPY conf /opt/bess/bessctl/conf
RUN ln -s /opt/bess/bessctl/bessctl /bin

# CNDP: Install dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    ethtool \
    libbsd0 \
    libbpf0 \
    libelf1 \
    libgflags2.2 \
    libjson-c[45] \
    libnl-3-200 \
    libnl-cli-3-200 \
    libnuma1 \
    libpcap0.8 \
    pkg-config \
    libgoogle-glog-dev \
    libprotobuf-dev \
    libprotobuf-c1 \
    libprotobuf17 \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir \
        flask \
        grpcio \
        iptools \
        mitogen \
        protobuf==3.20.0 \
        psutil \
        pyroute2 \
        glog \
        scapy
#COPY --from=bess-build /usr/bin/cndpfwd /usr/bin/
COPY --from=bess-build /usr/local/lib/x86_64-linux-gnu/*.so /usr/local/lib/x86_64-linux-gnu/
COPY --from=bess-build /usr/local/lib/x86_64-linux-gnu/*.a /usr/local/lib/x86_64-linux-gnu/
COPY --from=bess-build /usr/lib/libxdp* /usr/lib/
COPY --from=bess-build /lib/x86_64-linux-gnu/libjson-c.so* /lib/x86_64-linux-gnu/

ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

ENV PYTHONPATH="/opt/bess"
WORKDIR /opt/bess/bessctl
ENTRYPOINT ["bessd", "-f"]

# Stage build bess golang pb
FROM golang AS protoc-gen
RUN go install github.com/golang/protobuf/protoc-gen-go@latest

FROM bess-deps AS go-pb
COPY --from=protoc-gen /go/bin/protoc-gen-go /bin
RUN mkdir /bess_pb && \
    protoc -I /usr/include -I /protobuf/ \
        /protobuf/*.proto /protobuf/ports/*.proto \
        --go_opt=paths=source_relative --go_out=plugins=grpc:/bess_pb

FROM bess-deps AS py-pb
RUN pip install grpcio-tools==1.26
RUN apt-get update && apt-get install libgoogle-glog-dev
RUN mkdir /bess_pb && \
    python -m grpc_tools.protoc -I /usr/include -I /protobuf/ \
        /protobuf/*.proto /protobuf/ports/*.proto \
        --python_out=plugins=grpc:/bess_pb \
        --grpc_python_out=/bess_pb

FROM golang AS pfcpiface-build
ARG GOFLAGS
WORKDIR /pfcpiface

COPY go.mod /pfcpiface/go.mod
COPY go.sum /pfcpiface/go.sum

RUN if [[ ! "$GOFLAGS" =~ "-mod=vendor" ]] ; then go mod download ; fi

COPY . /pfcpiface
RUN CGO_ENABLED=0 go build $GOFLAGS -o /bin/pfcpiface ./cmd/pfcpiface

# Stage pfcpiface: runtime image of pfcpiface toward SMF/SPGW-C
FROM alpine AS pfcpiface
COPY conf /opt/bess/bessctl/conf
COPY --from=pfcpiface-build /bin/pfcpiface /bin
ENTRYPOINT [ "/bin/pfcpiface" ]

# Stage pb: dummy stage for collecting protobufs
FROM scratch AS pb
COPY --from=bess-deps /bess/protobuf /protobuf
COPY --from=go-pb /bess_pb /bess_pb

# Stage ptf-pb: dummy stage for collecting python protobufs
FROM scratch AS ptf-pb
COPY --from=bess-deps /bess/protobuf /protobuf
COPY --from=py-pb /bess_pb /bess_pb

# Stage binaries: dummy stage for collecting artifacts
FROM scratch AS artifacts
COPY --from=bess /bin/bessd /
COPY --from=pfcpiface /bin/pfcpiface /
COPY --from=bess-build /bess /bess
