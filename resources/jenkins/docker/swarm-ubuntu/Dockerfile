FROM ubuntu:20.04
MAINTAINER Governikus KG <ausweisapp2@governikus.de>

ARG JENKINS_SWARM_VERSION=3.24
ENV EXECUTOR=3 LABELS= NAME= PASSWORD=

RUN useradd -m governikus
RUN apt-get update && \
    apt-get -y install openjdk-8-jre-headless tini python3-pip wget && \
    pip3 install rbtools mercurial python-hglib && \
    rm -rf /var/lib/apt/lists/*
RUN wget -O /swarm-client.jar https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/$JENKINS_SWARM_VERSION/swarm-client-$JENKINS_SWARM_VERSION.jar

ADD swarm.sh /
