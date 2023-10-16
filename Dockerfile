FROM registry.gitlab.ics.muni.cz:443/cloud/container-registry/almalinux:8

ARG VERSION=unknown-version
ARG BUILD_DATE=unknown-date
ARG CI_COMMIT_SHA=unknown
ARG CI_BUILD_HOSTNAME
ARG CI_BUILD_JOB_NAME
ARG CI_BUILD_ID

COPY src/*.sh src/*.awk  /usr/local/bin/
COPY requirements.*  /

RUN yum -y update && \
    install-pkgs.sh /requirements.yum && \
    install-pymodules.sh /requirements.pip && \
    yum clean all

ENTRYPOINT ["/usr/local/bin/ostack-entity-dump.sh"]

LABEL maintainer="MetaCentrum Cloud Team <cloud[at]ics.muni.cz>" \
      org.label-schema.schema-version="1.0.0-rc.1" \
      org.label-schema.vendor="Masaryk University, ICS" \
      org.label-schema.name="infrastructure-entity-exporter" \
      org.label-schema.version="$VERSION" \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.build-ci-job-name="$CI_BUILD_JOB_NAME" \
      org.label-schema.build-ci-build-id="$CI_BUILD_ID" \
      org.label-schema.build-ci-host-name="$CI_BUILD_HOSTNAME" \
      org.label-schema.url="https://gitlab.ics.muni.cz/cloud/infrastructure-entity-exporter" \
      org.label-schema.vcs-url="https://gitlab.ics.muni.cz/cloud/infrastructure-entity-exporter" \
      org.label-schema.vcs-ref="$CI_COMMIT_SHA"
