FROM alpine:swarm
MAINTAINER Governikus KG <ausweisapp2@governikus.de>

ENV NAME=Docs LABELS=Docs

RUN apk --no-cache add cmake make py3-sphinx py3-setuptools icu poppler zziplib enscript ghostscript texlive-full && \
    pip3 install doc8 cloud_sptheme sphinx_rtd_theme sphinx-tabs

USER governikus

ENTRYPOINT ["/sbin/tini", "--"]
CMD sh -l -c /swarm.sh
