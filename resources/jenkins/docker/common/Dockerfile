FROM alpine:swarm
MAINTAINER Governikus KG <ausweisapp2@governikus.de>

ENV NAME=Common LABELS=Common

RUN apk --no-cache add cmake make uncrustify

USER governikus

ENTRYPOINT ["/sbin/tini", "--"]
CMD /swarm.sh
