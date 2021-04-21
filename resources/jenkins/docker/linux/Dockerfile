FROM alpine:swarm
MAINTAINER Governikus KG <ausweisapp2@governikus.de>

ENV NAME=Linux LABELS="Linux g++ clang++" PACKAGES_DIR=/home/governikus/packages

RUN apk --no-cache add cmake make g++ clang clang-analyzer ccache gcovr cloc clazy cppcheck pkgconf ninja pcsc-lite-dev binutils-gold lld \
                       py3-setuptools py3-jsonschema mesa-dev libx11-dev libxkbcommon-dev xcb-util-wm-dev xcb-util-image-dev xcb-util-keysyms-dev && \
    ln -s /usr/libexec/c++-analyzer /usr/local/bin && ln -s /usr/libexec/ccc-analyzer /usr/local/bin

USER governikus
RUN mkdir -p /home/governikus/.ccache && mkdir -p /home/governikus/workspace && mkdir -p /home/governikus/packages

ENTRYPOINT ["/sbin/tini", "--"]
CMD /swarm.sh
