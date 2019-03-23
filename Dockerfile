#
# Dockerfile for Cross-Compiling IoT/open-embedded Development builds
#
# https://docs.docker.com/develop/develop-images/dockerfile_best-practice
#
# To build:
# docker build --tag devbox --build-arg BUILD_USER=$(whoami) --build-arg UID=$(id -u) --build-arg GID=$(id -g) .
#

FROM ubuntu:16.04

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILDER_UID=1000
ARG BUILDER_GID=1000
ARG BUILD_USER=builder
ARG IMG_VERSION="0.0.1-alpha"
ARG IMG_DESCRIPTION="Container for cross-compiling IoT development builds (Incomplete)"


# Set identifying labels
LABEL devbox.user=$BUILD_USER \
    devbox.image.version=$IMG_VERSION \
    dev.image.description=$IMG_DESCRIPTION

# Set up locales
RUN apt-get update && apt-get upgrade -y && apt-get -y install locales apt-utils sudo \
    && dpkg-reconfigure locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG en_US.utf8

# Install basic utils (combining for cache purposes)
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#leverage-build-cache
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
        apt-transport-https \
        bc \
        bsdmainutils \
        ca-certificates \
        cifs-utils \
        curl \
        git \
        html2text \
        jq \
        linuxinfo \
        locales-all \
        nano \
        ncdu \
        net-tools \
        nmap \
        npm \
        p7zip-full \
        rar \
        rsync \
        samba \
        screen \
        socat \
        squashfs-tools \
        subversion \
        tasksel \
        tmux \
        tree \
        unace \
        unrar \
        unzip \
        vim-gtk \
        wget \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Install repo
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo \
    && chmod a+x /usr/local/bin/repo

# Replace dash with bash
RUN rm /bin/sh && ln -s bash /bin/sh

# User management
RUN groupadd --gid ${BUILDER_GID} ${BUILD_USER} \
    && useradd --no-log-init --uid ${BUILDER_UID} --gid ${BUILDER_GID} --create-home --home-dir /home/${BUILD_USER} --shell /bin/bash ${BUILD_USER} \
    && usermod -aG sudo ${BUILD_USER} \
    && usermod -aG users ${BUILD_USER}

# Give sudo permissions without needing password
RUN echo "${BUILD_USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${BUILD_USER} \
    && chmod 0440 /etc/sudoers.d/${BUILD_USER}

# Add tftp directory
RUN mkdir -p /tftpboot/libtool \
    && chown -R ${BUILD_USER}:${BUILD_USER} /tftpboot \
    && chmod 777 /tftpboot \
    && ln -sf /tftpboot /var/lib \
    && chown ${BUILD_USER}:${BUILD_USER} /var/lib/tftpboot

# Replace dash with bash needed by Yocto builds
RUN rm /bin/sh && ln -sf bash /bin/sh

# Create entrypoint with "sudo chmod ug+s `which unshare`" applied
# which requires privileged runtime container to take effect
COPY /docker-entrypoint.sh /
COPY requirements.txt /tmp

# Ensure it is executable
RUN chmod +x /docker-entrypoint.sh

# Install basic development tools
RUN set -xe \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        adb \
        ant \
        autoconf \
        autogen \
        automake \
        binutils-msp430 \
        bison \
        build-essential \
        checkinstall \
        chrpath \
        clang-format \
        cmake \
        cpio \
        cvs \
        debianutils \
        device-tree-compiler \
        diffstat \
        docbook \
        docbook-utils \
        dos2unix \
        fakeroot \
        fastboot \
        flex \
        gawk \
        gcc-msp430 \
        gcc-multilib \
        gettext \
        git-core \
        google-mock \
        gperf \
        gradle \
        help2man \
        iputils-ping \
        kmod \
        kpartx \
        lcov \
        lib32stdc++6 \
        lib32z1 \
        libacl1-dev \
        libbz2-dev \
        libc6-dev-i386 \
        libcap-dev \
        libexpat1-dev \
        libffi-dev \
        libgdbm-dev \
        libglib2.0-dev \
        libgtest-dev \
        liblz-dev \
        liblz1 \
        liblzma-dev \
        liblzo2-dev \
        libmxml-dev \
        libmxml1 \
        libncurses-dev \
        libncursesw5-dev \
        libsdl1.2-dev \
        libsqlite3-dev \
        libssl-dev \
        libtool \
        libusb-dev \
        libx11-dev \
        libxml2-dev \
        libzip-dev \
        libzip-ocaml-dev \
        libzip4 \
        libzstd-dev \
        linux-headers-generic \
        lrzsz \
        lua5.1 \
        maven \
        msp430-libc \
        nfs-common \
        nfs-kernel-server \
        nodejs \
        nodejs-legacy \
        ocaml-nox \
        openssh-client \
        openssh-server \
        procmail \
        pylint \
        pylint3 \
        python-dev \
        python-m2crypto \
        python-openssl \
        python-pip \
        python-pygccxml \
        python3-dev \
        python3-openssl \
        python3-pexpect \
        python3-pip \
        ruby-dev \
        scons \
        sharutils \
        texinfo \
        tk-dev \
        uuid-dev \
        virtualenv \
        xmlto \
        xterm \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Add Gtest for unit testing
RUN cd /usr/src/gtest \
    && cmake -E make_directory build \
    && cmake -E chdir build cmake .. \
    && cmake --build build \
    && cp build/libgtest* /usr/local/lib/

# Add Gmock for unit testing
RUN cd /usr/src/gmock \
    && cmake -E make_directory build \
    && cmake -E chdir build cmake .. \
    && cmake --build build \
    && cp build/libgmock* /usr/local/lib/

# Install perl XML parser (not in apt packages for this Ubuntu version)
RUN sudo perl -MCPAN -e 'install XML::Parser'

# Install typescript
RUN npm -g install typescript \
    && npm cache clean

# Update pip and pip3 as recommended
RUN pip install --upgrade pip
RUN pip3 install --upgrade pip

# Install any needed packages specified in requirements.txt (requires elevated permissions)
RUN pip3 install setuptools
RUN pip3 install --trusted-host pypi.python.org -r /tmp/requirements.txt
RUN /usr/local/bin/jupyter contrib nbextension install

# Clean any persistent temporary files to have pristine image (pip cache is in /tmp)
RUN apt-get clean && apt-get autoclean -y && apt-get autoremove -y
RUN rm -rf /tmp/* /var/tmp/*

# Make shared volume for mounting local files/directories for building
VOLUME /var/shared

# Finish off as build user to ensure proper ownership
USER ${BUILD_USER}

# Make /home/build the working directory
WORKDIR /home/${BUILD_USER}

# Make convenient directores in home
RUN mkdir -p /home/${BUILD_USER}/bin /home/${BUILD_USER}/lib /home/${BUILD_USER}/include /home/${BUILD_USER}/tmp

# generate general config
RUN /usr/local/bin/jupyter notebook --generate-config

# Link file from shared directory
RUN ln -s /var/shared /home/${BUILD_USER}/shared \
    && ln -s /var/shared/build_code \
    && ln -s /var/shared/.bash_history \
    && ln -s /var/shared/.dotfiles \
    && ln -s /var/shared/.vim_runtime \
    && ln -s /var/shared/.gitconfig \
    && ln -s /var/shared/.gitignore_global \
    && ln -s /var/shared/.ssh \
    && ln -s /var/shared/.subversion

ENV HOME /home/${BUILD_USER}
ENV PATH /home/${BUILD_USER}/bin:$PATH

# Make port 8888 available to the world outside this container
EXPOSE 8888

WORKDIR /home/${BUILD_USER}
