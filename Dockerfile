FROM mcr.microsoft.com/powershell:6.2.1-alpine-3.8

LABEL name="Scoop Bucket Minion" \
    maintainer="Jakub <Ash258> Čábera <cabera.jakub@gmail.com>" \
    description="Universal image for scoop bucket automatization used in Github Actions." \
    url="https://github.com/Ash258/Scoop-GithubActions" \
    repository="https://github.com/Ash258/Scoop-GithubActions" \
    homepage="https://github.com/Ash258/Scoop-GithubActions" \
    com.github.actions.name="Bucket Minion" \
    com.github.actions.description="Set of actions to automate maintaining of bucket." \
    com.github.actions.icon="package" \
    com.github.actions.color="purple"

ENV SCOOP /SCOOP
ENV SCOOP_HOME ${SCOOP}/apps/scoop/current
ENV SCOOP_DEBUG 1

RUN apk add --no-cache --virtual .scoop-deps git p7zip aria2 \
    && apk add hub --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    && git clone 'https://github.com/lukesampson/scoop.git' ${SCOOP_HOME}

COPY Entrypoint.ps1 /
COPY src /src

# Debug:
# COPY LocalTestEnvironment.ps1 /
# COPY cosi.json /
# ENTRYPOINT [ "pwsh" ]

ENTRYPOINT [ "pwsh", "-File", "/Entrypoint.ps1" ]
