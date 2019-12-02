# Container image that runs your code
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive
ENV AWS_FOLDER=/tmp/aws
ENV AWS_SHARED_CREDENTIALS_FILE=${AWS_FOLDER}/credentials
ENV AWS_CONFIG_FILE=${AWS_FOLDER}/config
ARG USERNAME=securityhub
ARG USERID=34000

# Upgrade and install dependencies
RUN apt-get update \
  && apt-get upgrade -yqq \
  && apt-get install -yqq --no-install-recommends \
    python3-pip \
    bash \
    curl \
    jq \
    file \
    git \
  && mkdir -p /${USERNAME} \
  && git clone https://github.com/awslabs/aws-securityhub-multiaccount-scripts /${USERNAME} \
  && pip3 install --upgrade setuptools \
  && pip3 install --upgrade wheel \
  && pip3 install --upgrade PyYAML \
  && pip3 install --upgrade awscli \
  && pip3 install --upgrade pyyaml \
  && pip3 install --upgrade boto3 \
  && pip3 freeze

RUN addgroup --gid ${USERID} ${USERNAME} \
  && useradd --shell /bin/bash -g ${USERNAME} ${USERNAME} \
  && chown -R ${USERNAME} /${USERNAME}/ \
  && chmod +x /${USERNAME}/*.py \
  && mdkr -p ${AWS_FOLDER} \
  && chown -R ${USERNAME} ${AWS_FOLDER} \

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY launch.sh /entrypoint.sh

# Switch to ${USERNAME} user
USER ${USERNAME}

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
CMD []
