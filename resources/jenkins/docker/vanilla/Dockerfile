FROM ubuntu:swarm
MAINTAINER Governikus KG <ausweisapp2@governikus.de>

ENV NAME=Vanilla LABELS="Vanilla"
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get -y install cmake make g++ clazy clang clang-tidy ccache gcovr cloc pkg-config ninja-build binutils-gold lld \
                       valgrind tree libpcsclite-dev libhttp-parser-dev libssl-dev libudev-dev \
                       qml-module-qt-labs-platform qml-module-qtquick-controls2 qml-module-qtquick-controls2 qml-module-qttest \
                       qml-module-qtgraphicaleffects qml-module-qtquick-layouts qml-module-qtqml-models2 \
                       qtdeclarative5-dev qtquickcontrols2-5-dev qttools5-dev libqt5svg5-dev \
                       libqt5websockets5-dev qtconnectivity5-dev && \
    rm -rf /var/lib/apt/lists/*

USER governikus
RUN mkdir -p /home/governikus/.ccache && mkdir -p /home/governikus/workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD /swarm.sh
