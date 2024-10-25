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

# There are later versions of python available (e.g. 3.12) but when we have
# tested with those then the code (pyzeebe) fails, so we are sticking with
# python 3.11 for now.
FROM python:3.11

# Upgrade the underlying OS
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    rm -rf /var/lib/apt/lists/*

ENV SCRIPT_DIR=/scripts \
    MODEL_PATH=model

# Use this if we are using 'docker build' as opposed to 'kaniko'
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
        pip install --requirement /tmp/requirements.txt && \
    addgroup --gid 1000 bp3 && \
    adduser --uid 1000 --ingroup bp3 --home /home/bp3user --shell /bin/bash --disabled-password bp3user

COPY --chown=bp3user:bp3 python/*.py $SCRIPT_DIR/
COPY --chown=bp3user:bp3 --chmod=755 scripts/*.sh $SCRIPT_DIR/
COPY --chmod=755 docker-entrypoint.sh /

USER bp3user

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["help"]
