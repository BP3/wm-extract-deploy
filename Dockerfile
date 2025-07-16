############################################################################
#
# Licensed Materials - Property of BP3
#
# Web Modeler Extract Deploy (WMED)
#
# Copyright © BP3 Global Inc. 2024. All Rights Reserved.
# This software is subject to copyright protection under
# the laws of the United States and other countries.
#
############################################################################
FROM python:3.13.3-alpine3.21

RUN addgroup --gid 1000 bp3 && \
    adduser --uid 1000 --ingroup bp3 --home /home/bp3user --shell /bin/bash --disabled-password bp3user

RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    apk add --no-cache 'git>2.47.2' 'openssh>9.9' && \
    pip install --requirement /tmp/requirements.txt

WORKDIR /app
COPY --chown=bp3user:bp3 LICENSE .
COPY --chmod=755 docker-entrypoint.sh .
COPY --chown=bp3user:bp3 python/*.py scripts/
COPY --chown=bp3user:bp3 --chmod=755 scripts/*.sh scripts/

USER bp3user

VOLUME /local
WORKDIR /local

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["help"]
