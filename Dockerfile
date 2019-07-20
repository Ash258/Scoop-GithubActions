FROM mcr.microsoft.com/powershell:6.2.1-alpine-3.8

LABEL org.label-schema.maintainer="Jakub <Ash258> Čábera <cabera.jakub@gmail.com>" \
    org.label-schema.description="Universal image for scoop repositories." \
    org.label-schema.url="https://github.com/Ash258/Scoop-GithubActions" \
    org.label-schema.vcs-url="https://github.com/Ash258/Scoop-GithubActions" \
    org.label-schema.schema-version="1.0.0"

ENV SCOOP /SCOOP
ENV SCOOP_HOME /SCOOP/apps/scoop/current
ENV SCOOP_DEBUG 1

RUN apk add --no-cache --virtual .scoop-deps git p7zip aria2 \
    && apk add hub --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    && git clone 'https://github.com/lukesampson/scoop.git' ${SCOOP_HOME}

COPY Entrypoint.ps1 /

# Debug:
# COPY LocalTestEnvironment.ps1 /
# COPY cosi.json /
# ENTRYPOINT [ "pwsh" ]

ENTRYPOINT [ "pwsh", "-File", "/Entrypoint.ps1" ]
