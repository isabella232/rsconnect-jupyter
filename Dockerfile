ARG BASE_IMAGE
FROM ${BASE_IMAGE}
LABEL maintainer="RStudio Connect <rsconnect@rstudio.com>"

ARG NB_UID
ARG NB_GID
ARG PY_VERSION
RUN apt-get update -qq \
    && apt-get install -y make
RUN getent group ${NB_GID} || groupadd -g ${NB_GID} builder
RUN useradd --password password \
    --create-home \
    --home-dir /home/builder \
    --uid ${NB_UID} \
    --gid ${NB_GID} \
    builder

USER ${NB_UID}:${NB_GID}
RUN cd /home/builder \
    && conda create --yes --name py${PY_VERSION} jupyter