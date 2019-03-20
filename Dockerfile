#
# Dockerfile for Development builds
#
#
# Note: to add DNS entries in containers you need to run on host machine (system-wide)
# or override it in the 'docker run' command 
#     cat << EOF > daemon.json
#     {
#        "dns": ["8.8.8.8", "8.8.4.4"]
#     }
#     EOF
#     sudo mv daemon.json /etc/docker
#     sudo service docker restart
#

# # run (read-only system file systems) bash for any image
# function dbash {
#   docker run \
#     --privileged \
#     --rm \
#     --interactive \
#     --tty \
#     --env TERM=xterm-256color \
#     --volume ~/.ssh:/var/shared/.ssh \
#     --volume ~/.bash_history:/var/shared/.bash_history \
#     --volume ~/.subversion:/var/shared/.subversion \
#     --volume ~/.gitconfig:/var/shared/.gitconfig \
#     --volume ~/.dotfiles:/var/shared/.dotfiles \
#     --volume ~/.vim_runtime:/var/shared/.vim_runtime \
#     --entrypoint /bin/bash \
#     --volume $(pwd):/var/shared/build_code \
#     $1 
# }

FROM ubuntu:16.04

ARG DEBIAN_FRONTEND=noninteractive

# Update the apt (Package Manager)
RUN apt-get update && apt-get upgrade -y

# Install basic development tools
RUN set -xe \
    && apt-get install -y --no-install-recommends \
           cvs gperf libtool automake autoconf help2man xmlto libglib2.0-dev libncurses-dev nodejs \
           nodejs-legacy texinfo lrzsz libusb-dev chrpath procmail autogen scons sharutils \
           libxml2-dev libcap-dev liblzo2-dev libbz2-dev libacl1-dev python-dev libzip-dev uuid-dev \
           dos2unix libmxml1 libmxml-dev libexpat1-dev python-dev python3-dev python-pip python3-pip \
           virtualenv python-pygccxml pylint pylint3  python-openssl python3-openssl python-m2crypto \
           build-essential cmake net-tools openssh-server openssh-client git git-core subversion \
           linux-headers-generic bison flex clang-format lcov google-mock libgtest-dev liblzma-dev \
           libzip-dev ocaml-nox docbook docbook-utils tasksel nfs-kernel-server nfs-common ruby-dev \
           curl tree device-tree-compiler maven gradle ant kpartx libx11-dev gawk msp430-libc \
           binutils-msp430 gcc-msp430 liblz-dev liblz1 libssl-dev libffi-dev gcc-multilib lib32z1 \
           adb fastboot libgdbm-dev libsqlite3-dev tk-dev checkinstall libncursesw5-dev \
           libzip-dev libzstd-dev libzip-ocaml-dev libzip4 android-libziparchive-dev libc6-dev-i386 \
           flex autogen scons libcap-dev zlib1g-dev lib32z1 lib32stdc++6 diffstat wget cpio \
           xterm python3-pexpect xz-utils debianutils iputils-ping libsdl1.2-dev gawk lua5.1 \
           fakeroot gettext  # only if I have to since this is a long install texlive-full

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

# Set up locales
RUN apt-get -y install locales apt-utils sudo \
    && dpkg-reconfigure locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG en_US.utf8

# Finish Installing basic utilities now that other dependencies are taken care of
RUN apt-get install -y --no-install-recommends \
    unace unrar zip unzip p7zip-full p7zip-rar rar apt-transport-https ca-certificates net-tools \
    cifs-utils ncdu nmap npm locales-all linuxinfo screen tmux jq vim-gtk nano samba bc rsync \
    squashfs-tools socat html2text bsdmainutils

# Install perl XML parser (not in apt packages for this Ubuntu version)
RUN sudo perl -MCPAN -e 'install XML::Parser'

# Install typescript 
RUN npm -g install typescript

# Update pip and pip3 as recommended
RUN pip install --upgrade pip 
RUN pip3 install --upgrade pip

# Clean up APT when done.
RUN apt-get clean && apt-get autoclean -y && apt-get autoremove -y

# Replace dash with bash
RUN rm /bin/sh && ln -s bash /bin/sh

ENV BUILD_USER builder

# User management
RUN groupadd --gid 1000 ${BUILD_USER} \
    && useradd --uid 1000 --gid 1000 --create-home --home-dir /home/${BUILD_USER} --shell /bin/bash ${BUILD_USER} \
    && usermod -aG sudo ${BUILD_USER} \
    && usermod -aG users ${BUILD_USER}

# Give sudo permissions without needing password
RUN echo "${BUILD_USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${BUILD_USER} \
    && chmod 0440 /etc/sudoers.d/${BUILD_USER}

# Install repo
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo \
    && chmod a+x /usr/local/bin/repo

# Add tftp directory
RUN mkdir -p /tftpboot/libtool
RUN chown -R ${BUILD_USER}:${BUILD_USER} /tftpboot
RUN chmod 777 /tftpboot
RUN ln -sf /tftpboot /var/lib
RUN chown ${BUILD_USER}:${BUILD_USER} /var/lib/tftpboot

# Replace dash with bash needed by Yocto builds
RUN rm /bin/sh && ln -sf bash /bin/sh

# Give group permission to unshare
RUN chmod ug+s `which unshare`

# Make shared volume for mounting local files/directories for building
VOLUME /var/shared
VOLUME /home/${BUILD_USER}/tmp

USER ${BUILD_USER}

# Make /home/build the working directory
WORKDIR /home/${BUILD_USER}

# Make convenient directores in home
RUN mkdir -p /home/${BUILD_USER}/bin /home/${BUILD_USER}/lib /home/${BUILD_USER}/include

ENV HOME /home/${BUILD_USER}
ENV PATH /home/${BUILD_USER}/bin:$PATH

ADD requirements.txt /home/${BUILD_USER}/tmp/requirements.txt

# Finish last installations as root
USER root

# Install any needed packages specified in requirements.txt (requires elevated permissions)
RUN pip3 install setuptools
RUN pip3 install --trusted-host pypi.python.org -r /home/${BUILD_USER}/tmp/requirements.txt
RUN /usr/local/bin/jupyter contrib nbextension install

# Clean any persistent temporary files to have pristine image
RUN rm -rf /tmp/* /var/tmp/*

# Return to build user to ensure proper ownership
USER ${BUILD_USER}

# generate general config
RUN /usr/local/bin/jupyter notebook --generate-config

# Make port 8888 available to the world outside this container
EXPOSE 8888

# Link file from shared directory
RUN ln -s /var/shared /home/${BUILD_USER}/shared
RUN ln -s /var/shared/build_code
RUN ln -s /var/shared/.bash_history
RUN ln -s /var/shared/.dotfiles
RUN ln -s /var/shared/.vim_runtime
RUN ln -s /var/shared/.gitconfig
RUN ln -s /var/shared/.gitignore_global
RUN ln -s /var/shared/.ssh
RUN ln -s /var/shared/.subversion

WORKDIR /home/${BUILD_USER}
