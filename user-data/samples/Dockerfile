FROM jenkins/jenkins:lts

USER root

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY --chown=jenkins:jenkins jenkins-data/casc.yaml /var/jenkins_home/casc.yaml

ENV CASC_JENKINS_CONFIG /var/jenkins_home/casc.yaml
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
ENV JENKINS_OPTS --httpPort=-1 --httpsPort=8443 --httpsCertificate=/var/lib/jenkins/COMMONNAME.crt --httpsPrivateKey=/var/lib/jenkins/COMMONNAME.key

RUN apt-get update && \
     apt-get -y install apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common && \
     curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey; apt-key add /tmp/dkey && \
     add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
     $(lsb_release -cs) \
     stable" && \
     apt-get update && \
     apt-get -y install docker-ce

RUN apt-get update && \
    apt-get install -y \
        python \
        python-dev \
        python-pip \
        python-setuptools \
        groff \
        less \
    && pip install --upgrade awscli \
    && apt-get clean

RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

RUN usermod -aG docker jenkins
USER jenkins

EXPOSE 8443
