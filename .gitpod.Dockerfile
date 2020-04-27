FROM gitpod/workspace-full
USER root
ARG SHELLCHECK_VERSION=stable
ARG SHELLCHECK_FORMAT=gcc
RUN apt-get update -q && apt-get install -yq curl \
    strace \
    debootstrap \
    binfmt-support \
    qemu-user-static \

    RUN curl -fsSL \
    https://raw.githubusercontent.com/da-moon/rootfs-builder/master/bin/fast-apt | sudo bash -s -- \
    --init || true;
RUN aria2c "https://storage.googleapis.com/shellcheck/shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"
RUN tar -xvf shellcheck-"${SHELLCHECK_VERSION}".linux.x86_64.tar.xz
RUN cp shellcheck-"${SHELLCHECK_VERSION}"/shellcheck /usr/bin/
RUN shellcheck --version
RUN echo 'export PATH="/workspace/rootfs-builder/bin:$PATH"' >>~/.bashrc
RUN wget -q -O /usr/bin/stream-dl https://raw.githubusercontent.com/da-moon/rootfs-builder/master/bin/stream-dl
RUN chmod +x "/usr/bin/stream-dl"
RUN stream-dl --init || true;
RUN curl -fsSL \
    https://raw.githubusercontent.com/da-moon/rootfs-builder/master/bin/get-hashi | sudo bash -s -- 
RUN wget -q -O /usr/bin/run-sc https://raw.githubusercontent.com/da-moon/rootfs-builder/master/bin/run-sc
RUN chmod +x "/usr/bin/run-sc"
RUN wget -q -O /usr/bin/gitt https://raw.githubusercontent.com/da-moon/rootfs-builder/master/bin/gitt
RUN chmod +x "/usr/bin/gitt"
RUN gitt --init || true;
# RUN echo 'alias make=''make -j$(nproc)''' >>~/.bashrc
CMD ["bash"] 
