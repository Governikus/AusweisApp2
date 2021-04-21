FROM ubuntu:swarm
MAINTAINER Governikus KG <ausweisapp2@governikus.de>

ARG ANDROID_CMDLINE_TOOLS=6609375
ARG ANDROID_NDK_VERSION=21.3.6528147
ARG CMAKE=3.17.3
ENV NAME=Android LABELS="Android" PACKAGES_DIR=/home/governikus/packages

ENV ANDROID_SDK_ROOT /opt/android-sdk
ENV ANDROID_NDK_ROOT $ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION

# Remove this later: https://github.com/openssl/openssl/pull/11206
ENV ANDROID_NDK $ANDROID_NDK_ROOT

RUN apt-get update && \
    apt-get -y install g++ make ccache ninja-build perl unzip gradle maven patch openjdk-8-jdk-headless && \
    ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/lib/jvm/java-8-openjdk && \
    rm -rf /var/lib/apt/lists/*

# CMake 3.16 is required for NDK r19+
RUN wget https://github.com/Kitware/CMake/releases/download/v$CMAKE/cmake-$CMAKE-Linux-x86_64.sh -O /tmp/cmake.sh && \
    sh /tmp/cmake.sh --prefix=/usr --skip-license --exclude-subdir && rm /tmp/cmake.sh

RUN mkdir -p /tmp/dl && cd /tmp/dl && wget -O sdk.zip https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip && \
    unzip sdk.zip && \
    yes | /tmp/dl/tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT "cmdline-tools;2.1" "build-tools;29.0.3" "platform-tools" "platforms;android-29" "ndk;${ANDROID_NDK_VERSION}" && \
    rm -rf /tmp/dl

USER governikus
RUN mkdir -p /home/governikus/.ccache && mkdir -p /home/governikus/workspace && mkdir -p /home/governikus/packages

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD /swarm.sh
