FROM jenkins/jnlp-slave:3.27-1

USER root

COPY files/jenkins-slave /usr/local/bin/jenkins-slave
RUN chmod +x /usr/local/bin/jenkins-slave

RUN cat /etc/issue


# Set nameservers
COPY /files/resolv.conf /etc/resolv.conf

# # Frontend crap
# ENV DEBIAN_FRONTEND noninteractive
# ENV NPM_CONFIG_LOGLEVEL info
# ENV NODE_VERSION 10.0.0

# RUN apt-get update \
#     && apt-get install -y sudo \
#     && curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash - && sudo apt-get install -y nodejs

# # Yarn Unstalation

# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - && \
# echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && \
# sudo apt update -y && \
# sudo apt install -y yarn && \
# export PATH=$PATH:`yarn global dir`

# # Global YAarn dependencies
# RUN yarn global add skypager skypager-cli now firebase-tools firebase-admin
# RUN curl https://bootstrap.pypa.io/get-pip.py | python3

# # Install frontend dependencies
# RUN dpkg --add-architecture i386 && \
#     apt-get update && \
#     apt-get install -yq libc6:i386 libstdc++6:i386 zlib1g:i386 libncurses5:i386 --no-install-recommends

RUN echo 'deb http://ftp.de.debian.org/debian testing main' >> /etc/apt/sources.list \
    && echo 'APT::Default-Release "stretch";' | tee -a /etc/apt/apt.conf.d/00local && apt-get update -y \
    && apt-get install -y apt-transport-https software-properties-common expect\
    && apt-get -t testing install -y python3.6 python3-pip

# RUN pip3 install --upgrade awscli

# # gpg keys listed at https://github.com/nodejs/node
# RUN set -ex \
#   && for key in \
#     9554F04D7259F04124DE6B476D5A82AC7E37093B \
#     94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
#     0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
#     FD3A5288F042B6850C66B31F09FE44734EB7990E \
#     71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
#     DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
#     B9AE9905FFD7803F25714661B63B535A4C206CA9 \
#     C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
#   ; do \
#     gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
#   done

# RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
# RUN curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.4/gosu-$(dpkg --print-architecture)" \
#     && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.4/gosu-$(dpkg --print-architecture).asc" \
#     && gpg --verify /usr/local/bin/gosu.asc \
#     && rm /usr/local/bin/gosu.asc \
#     && chmod +x /usr/local/bin/gosu

# # Download and untar SDK
# ENV ANDROID_SDK_URL https://dl.google.com/android/repository/tools_r25.2.3-linux.zip
# RUN curl -L "${ANDROID_SDK_URL}" -o /tmp/android-sdk-linux.zip \
#   && unzip /tmp/android-sdk-linux.zip -d /usr/local/ \
#   && rm /tmp/android-sdk-linux.zip \
#   && mkdir /usr/local/android-sdk-linux \
#   && mv /usr/local/tools /usr/local/android-sdk-linux/

# ENV ANDROID_HOME /usr/local/android-sdk-linux
# ENV ANDROID_SDK /usr/local/android-sdk-linux
# ENV PATH ${ANDROID_HOME}/tools:$ANDROID_HOME/platform-tools:/home/jenkins/.local/binÇ$PATH

# # Install Android SDK components

# ENV ANDROID_COMPONENTS platform-tools,build-tools-23.0.1,build-tools-23.0.3,android-23
# ENV GOOGLE_COMPONENTS extra-android-m2repository,extra-google-m2repository,extra-google-google_play_services,extra-google-gcm

# RUN echo y | android update sdk --no-ui --all --filter "${ANDROID_COMPONENTS}" ; \
#     echo y | android update sdk --no-ui --all --filter "${GOOGLE_COMPONENTS}"

# # Adding ANDROID dependencies licenses
# RUN mkdir -p $ANDROID_HOME/licenses/
# RUN chown -R jenkins:jenkins $ANDROID_HOME

# Addind apt-get packages
RUN apt-get update -y && apt-get install -y

# Install docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/debian \
        $(lsb_release -cs) \
        stable" \
    && apt-get update -y
RUN apt-get install -y gnupg2 build-essential docker-ce=17.06.1~ce-0~debian
# RUN curl -L https://github.com/docker/compose/releases/download/1.20.0/docker-compose-`uname -s`-`uname -m` -o /usr/bin/docker-compose \
#     && chmod +x /usr/bin/docker-compose

# Downloads spin cli
RUN curl -LO https://storage.googleapis.com/spinnaker-artifacts/spin/$(curl -s https://storage.googleapis.com/spinnaker-artifacts/spin/latest)/linux/amd64/spin && mv ./spin /usr/local/bin/spin \
  && chmod +x /usr/local/bin/spin \
  && chown jenkins:jenkins /usr/local/bin/spin

# Jenkins user configuration 
ENV JENKINS_HOME /home/jenkins
RUN echo "jenkins  ALL=(ALL)  NOPASSWD:ALL" >> /etc/sudoers
RUN usermod -aG docker jenkins

# RUN mkdir /home/jenkins/.spin
# RUN chown -R jenkins:jenkins /home/jenkins

# # Sonar scanner
# ENV SONAR_DIST=sonar-scanner-3.3.0.1492-linux
# RUN curl --output /tmp/sonar.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.3.0.1492-linux.zip
# RUN unzip /tmp/sonar.zip -d /tmp/ && mv /tmp/$SONAR_DIST /opt/$SONAR_DIST

# COPY files/jenkins-slave /usr/local/bin/jenkins-slave
# RUN chmod +x /usr/local/bin/jenkins-slave
# USER jenkins

# # Installs Helm
# ENV HELM_VERSION v2.9.1
# ENV HELM_TMP /tmp/helm
# ENV PATH $PATH:/usr/local/bin/jenkins-slave:/home/jenkins/.local/bin:/opt/sonar-scanner-3.3.0.1492-linux/bin/
# RUN mkdir $HELM_TMP && curl -sSL https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar -zxv --strip-components=1 -C $HELM_TMP
# RUN sudo mv ${HELM_TMP}/helm /usr/local/bin/helm && rm -rf ${HELM_TMP} \
#     && helm init --client-only \
#     && helm plugin install https://github.com/hypnoglow/helm-s3.git

# RUN pip install requests
# RUN pip3 install --user --upgrade pip awscli
# RUN pip install --user --upgrade pip
# RUN sudo apt-get install -y jq
# # Fixes python stack size issue
# RUN ulimit -s unlimited


USER root