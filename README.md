# Embedded Development Docker Container

The first start of setting up a consistent and managed development environment.

## Install

#### Linux

`sudo apt install docker.io docker-compose`

#### Windows

Not recommended for normal builds since these are typically light-weight VMs.
If you chose to do something so https://docs.docker.com/docker-for-windows/install/

### Configure Host

```bash
# Note: to add DNS entries in containers you need to run on host machine (system-wide)
# or override it in the 'docker run' command 
cat << EOF > daemon.json
{
    "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF
sudo mv daemon.json /etc/docker
sudo service docker restart
```

Add yourself to the docker group so you don't need to run sudo to use docker

```bash
sudo usermod -aG docker $(whoami)
# logout and back into OS session for permissions to be applied
```

## Build Container image

`docker build --tag devbox --build-arg BUILD_USER=$(whoami) --build-arg UID=$(id -u) --build-arg GID=$(id -g) .`

## Run Image (Make container)

Optional method to test is to run docker-compose with the Dockerfile and docker-compose.yml.  This is not how this 

`docker-compose up`

Other method is to issue from command-line.  This will be integrated in a similar form below. 

A sample commandline

```bash
# TODO: need to figure out which capability is getting in the way instead of doing sys_admin
# I opened up the container completely in this example
# run privileged bash for any image
# add '--dns X.X.X.X' to docker run command if you need to override default dns
# add '--entrypoint <new_entrypoint>' to override set entrypoint
# add '--publish xxxx:8888' to expose port 8888 from container to host as xxxx
dkadminrun() { 
    docker run \
     --privileged \
     --rm \
     --interactive \
     --tty \
     --env TERM=xterm-256color \
     --volume ~/.ssh:/var/shared/.ssh \
     --volume ~/.bash_history:/var/shared/.bash_history \
     --volume ~/.subversion:/var/shared/.subversion \
     --volume ~/.gitconfig:/var/shared/.gitconfig \
     --volume ~/.dotfiles:/var/shared/.dotfiles \
     --volume ~/.vim_runtime:/var/shared/.vim_runtime \
     --volume /opt/cross:/opt/cross \
     --volume $(pwd):/var/shared/build_code \
     --workdir '/var/shared/build_code' \
     $@
}
```

To execute command in the container is then as simple as 

`dkadminrun devbox  # This will create a new container with a shell instance to that container` 

or 

for a one-shot command run:

`dkadminrun devbox ls`
z
## Build inside container

From root of workspace directory run  `dkadminrun devbox /docker-entrypoint.sh <build command>` 

For example, if build command is `make all`, then run:

# one-shot (with unshare fix)
`dkadminrun devbox /docker-entrypoint.sh make all`

# shell session
run via going in bash session of the container

```bash
$ dkadminrun ntc_dev_box /docker-entrypoint.sh                                                                       
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

builder@68787f85824c:/var/shared/build_code$ make all
```
