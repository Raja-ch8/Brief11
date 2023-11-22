FROM jenkins/jenkins:lts
USER root 
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y && \  
    apt install -y jq parallel  && \
    curl -sSL https://get.docker.com/ | sh
