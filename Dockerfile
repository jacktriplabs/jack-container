# Jack Audio Connection Kit container image using Redhat Universal Base Image ubi-init
#
# Copyright (c) 2023-2024. MIT License.
#
# See https://jackaudio.org/
# To build this: "podman build -t jack ."

# container image versions
ARG FEDORA_VERSION=34
ARG REDHAT_UBI_VERSION=9.3

# -------------
# STAGE BUILDER
# -------------
# temporary container used to build jack
FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION} AS builder

# install tools required to build jack
RUN dnf install -y --nodocs gcc gcc-c++ git meson python3-pyyaml python3-jinja2

# you should probably never change these
ARG JACK_REPO=https://github.com/jackaudio/jack2.git
ARG JACK_TOOLS_REPO=https://github.com/jackaudio/jack-example-tools.git

# we will patch jack with these to allow for greater scalability
ARG JACK_CLIENTS=128

# these can be any tag or commit in the repositories
ARG JACK_VERSION=1.9.22

# download and install jack
RUN cd /root \
    && git clone ${JACK_REPO} --branch v${JACK_VERSION} --depth 1 --recurse-submodules --shallow-submodules \
    && cd jack2 \
    && sed -i 's/#define CLIENT_NUM 64/#define CLIENT_NUM ${JACK_CLIENTS}/' ./common/JackConstants.h \
    && sed -i 's/#define MAX_SHM_ID 256/#define MAX_SHM_ID 1024/' ./common/shm.h \
    && ./waf configure --clients=${JACK_CLIENTS} \
    && ./waf build \
    && ./waf install

# download and install jack example tools
RUN cd /root \
    && git clone ${JACK_TOOLS_REPO} --depth 1 --recurse-submodules --shallow-submodules \
    && cd jack-example-tools \
    && PKG_CONFIG_PATH=/usr/local/lib/pkgconfig meson setup -Ddefault_library=static --buildtype release builddir \
    && meson compile -C builddir \
    && meson install -C builddir

# stage files in INSTALLDIR
ENV INSTALLDIR=/opt
RUN mkdir -p ${INSTALLDIR}/usr/local/bin/ ${INSTALLDIR}/usr/lib64/ ${INSTALLDIR}/usr/local/lib/jack/ ${INSTALLDIR}/usr/sbin ${INSTALLDIR}/etc/security/limits.d/ ${INSTALLDIR}/etc/systemd/system/ \
    && cp /usr/local/bin/jackd /usr/local/bin/jack_* ${INSTALLDIR}/usr/local/bin/ \
    && cp /usr/local/lib/libjack.so.0 /usr/local/lib/libjackserver.so.0 ${INSTALLDIR}/usr/lib64/ \
    && cp /usr/local/lib/jack/* ${INSTALLDIR}/usr/local/lib/jack/
COPY --chmod=0755 defaults.sh ${INSTALLDIR}/usr/sbin/defaults.sh
COPY audio.conf ${INSTALLDIR}/etc/security/limits.d/
COPY jack.service defaults.service ${INSTALLDIR}/etc/systemd/system/


# ------------------
# STAGE JACK (FINAL)
# ------------------
# build the final container
FROM registry.access.redhat.com/ubi9/ubi-init:${REDHAT_UBI_VERSION}

ENV LD_LIBRARY_PATH=/usr/local/lib

# add JACK_PROMISCUOUS_SERVER to allow other users to access jackd - groups don't actually work so using the environment variable
# see: http://manpages.ubuntu.com/manpages/bionic/man1/jackd.1.html
# remove python3-setuptools: security patch for CVE-2022-40897
RUN echo "JACK_PROMISCUOUS_SERVER=audio" >> /etc/environment \
	&& useradd -r -m -N -G audio -s /usr/sbin/nologin jack \
	&& chown -R jack.audio /home/jack \
	&& chmod g+rwx /home/jack \
	&& usermod -G audio root \
	&& echo "export JACK_PROMISCUOUS_SERVER=audio" > /etc/profile.d/jack.sh \
	&& ln -s /etc/systemd/system/jack.service /etc/systemd/system/multi-user.target.wants \
	&& ln -s /etc/systemd/system/defaults.service /etc/systemd/system/multi-user.target.wants \
    && dnf remove -y python3-setuptools

# copy the artifacts we built into the final container image
COPY --from=builder /opt /
