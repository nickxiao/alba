FROM ubuntu:14.04.3
RUN echo "deb http://archive.ubuntu.com/ubuntu/ trusty-backports main restricted universe multiverse" > /etc/apt/sources.list.d/trusty-backports-universe.list
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential m4 apt-utils \
        libffi-dev libssl-dev \
        libbz2-dev \
        libgmp3-dev \
        libev-dev \
        libsnappy-dev \
        libxen-dev \
        help2man \
        pkg-config \
        time \
        aspcud \
        wget \
        rsync \
        darcs \
        git \
        unzip \
        protobuf-compiler \
        libgcrypt20-dev \
        libjerasure-dev \
        yasm \
        automake \
        python-dev \
        python-pip \
        debhelper \
        psmisc \
        strace \
        curl \
        g++ \
        libgflags-dev \
        sudo \
        libtool \
        libboost-all-dev \
        fuse \
        sysstat \
        ncurses-dev

RUN useradd jenkins -u 1001 -g root

RUN mkdir /home/alba
RUN wget https://raw.github.com/ocaml/opam/master/shell/opam_installer.sh
env ocaml_version=4.02.3
RUN sh ./opam_installer.sh /usr/local/bin ${ocaml_version}
env opam_root=/home/alba/OPAM
ENV opam_env="opam config env --root=${opam_root}"
RUN opam init --root=/home/alba/OPAM --comp ${ocaml_version}
RUN eval `${opam_env}` && \
    opam update && \
    opam install -y \
        ocamlfind \
        ssl.0.5.2 \
        camlbz2 \
        snappy \
        sexplib \
        bisect \
        lwt.2.5.1 \
        camltc \
        cstruct \
        ctypes \
        ctypes-foreign \
        uuidm \
        zarith \
        mirage-no-xen.1 \
        quickcheck.1.0.2 \
        cmdliner \
        conf-libev \
        depext \
        kinetic-client \
        tiny_json \
        ppx_deriving.3.1 \
        ppx_deriving_yojson \
        core.113.00.00 \
        redis \
        uri.1.9.1 \
        result

RUN wget https://01.org/sites/default/files/downloads/intelr-storage-acceleration-library-open-source-version/isa-l-2.14.0.tar.gz
RUN tar xfzv isa-l-2.14.0.tar.gz
RUN cd isa-l-2.14.0 && ./autogen.sh && ./configure
RUN cd isa-l-2.14.0 && make
RUN cd isa-l-2.14.0 && make install

# c++
RUN apt-get update && apt-get -y install libgtest-dev cmake
RUN cd /usr/src/gtest \
        && cmake . \
        && make \
        && mv libg* /usr/lib/


# install specific arakoon.
RUN git clone https://github.com/openvstorage/arakoon.git
RUN cd arakoon && git pull && git checkout tags/1.9.4
RUN cd arakoon && eval `${opam_env}` && make
RUN cd arakoon && eval `${opam_env}` \
    && export PREFIX=${opam_root}/${ocaml_version} \
    && export OCAML_LIBDIR=`ocamlfind printconf destdir` \
    && make install

# install specific orocksdb
RUN git clone https://github.com/domsj/orocksdb.git \
    && eval `${opam_env}` \
    && cd orocksdb \
    && git checkout 8bc61d8a451a2724399247abf76643aa7b2a07e9 \
    && ./install_rocksdb.sh \
    && make build install

#for now, install ordma manually
RUN apt-get update && apt-get -y install librdmacm-dev
RUN git clone https://github.com/toolslive/ordma.git \
    && cd ordma \
    && git checkout tags/0.0.2 \
    && eval `${opam_env}` \
    && make install
RUN echo "jenkins ALL=NOPASSWD: ALL" >/etc/sudoers.d/jenkins

RUN apt-get update && apt-get -y install clang-3.5

RUN echo "deb http://apt.openvstorage.org chicago-community main" > /etc/apt/sources.list.d/ovsaptrepo.list
RUN apt-get update && apt-get -y --force-yes install \
      libboost1.57-all liblttng-ust0 librdmacm1 libtokyocabinet9 \
      libstdc++6:amd64 libzmq3 librabbitmq1 libomnithread3c2 libomniorb4-1 \
      libhiredis0.10 \
      omniorb-nameserver

## This only works from inside the OVS lan...
# http://10.100.129.100:8080/job/volumedriver-alba-client-timeouts-release-ubuntu-14.04/4/artifact/volumedriver-core/build/debian/volumedriver-base-dbgsym_5.7.2-dev.201605030944.5d9e62c_amd64.ddeb
ENV voldrv_jenkins=http://10.100.129.100:8080/job/volumedriver-alba-client-timeouts-release-ubuntu-14.04/lastSuccessfulBuild/artifact/volumedriver-core/build/debian
ENV voldrv_version=5.7.2-dev.201605030944.5d9e62c_amd64
RUN wget ${voldrv_jenkins}/volumedriver-base_${voldrv_version}.deb \
    && dpkg -i volumedriver-base_${voldrv_version}.deb

RUN wget ${voldrv_jenkins}/volumedriver-pitreplication_${voldrv_version}.deb \
    && dpkg -i volumedriver-pitreplication_${voldrv_version}.deb

RUN wget ${voldrv_jenkins}/volumedriver-server_${voldrv_version}.deb \
    && dpkg -i volumedriver-server_${voldrv_version}.deb

RUN wget ${voldrv_jenkins}/volumedriver-test_${voldrv_version}.deb \
    && dpkg -i volumedriver-test_${voldrv_version}.deb

# Install alba 0.6, and arakoon.1.8.9 which we might need for compatibility tests
RUN apt-get update && apt-get install -y --force-yes alba arakoon
RUN ln -s /usr/bin/alba /usr/bin/alba.0.6
ENV UID 1001
ENV ARAKOON_BIN=arakoon
ENV VOLDRV_TEST=volumedriver_test
ENV VOLDRV_BACKEND_TEST=backend_test

# Install etcd:
RUN curl -L  https://github.com/coreos/etcd/releases/download/v2.2.4/etcd-v2.2.4-linux-amd64.tar.gz -o etcd-v2.2.4-linux-amd64.tar.gz
RUN tar xzvf etcd-v2.2.4-linux-amd64.tar.gz
RUN cp ./etcd-v2.2.4-linux-amd64/etcd /usr/bin \
    && cp ./etcd-v2.2.4-linux-amd64/etcdctl /usr/bin


CMD eval `${opam_env}` \
    && echo ${SUITE} \
    && ./jenkins/run.sh ${SUITE}
