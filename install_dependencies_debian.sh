#!/bin/bash
#
# Install script made for ubuntu 14
# should work on most debian
#

# log as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# create user qaunix
useradd -g sysadmin -d /home/qaunix -m -p $(echo qaunix | openssl passwd -1 -stdin) -s /bin/bash qaunix

# set dns
echo "search mydns.test" >> /etc/resolvconf/resolv.conf.d/base
resolvconf -u
sed -i "s/^search.*/search mydns.test/" /etc/resolv.conf
resolvconf -u

# set max open file allowed upper. ulimit -Hn is 4096 by default... frack u monsoon
echo "qaunix hard nofile 1048576" >> /etc/security/limits.conf

#add proxies
export http_proxy=http://proxy:8080
export https_proxy=http://proxy:8080
export no_proxy=localhost,127.0.0.1,.corp

# Setup apt-get
echo deb http://archive.ubuntu.com/ubuntu precise universe >> /etc/apt/sources.list

apt-get install -q -y wget curl
wget -q http://package.perforce.com/perforce.pubkey -O - | apt-key add -
curl -sL https://deb.nodesource.com/setup_8.x | bash -
echo 'deb http://package.perforce.com/apt/ubuntu precise release' > /etc/apt/sources.list.d/perforce.sources.list

echo 'Acquire::http::Proxy "http://proxy:8080/";Acquire::https::Proxy "http://proxy:8080/";' > /etc/apt/apt.conf

# Install dependencies
apt-get update && apt-get clean
apt-get install -q -y git \
                      curl \
                      ca-certificates \
                      openjdk-7-jre-headless \
                      openssh-server \
                      unzip \
                      nodejs \
                      helix-cli \
                      python-pip \
                      && apt-get clean

# configure ssl
#RUN curl -sSL -f -k http://mycertificate.crt -o /usr/local/share/ca-certificates/mycertificate.crt  \
#    && keytool -noprompt -import -alias mycertificate -file /usr/local/share/ca-certificates/mycertificate.crt -keystore /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/cacerts -storepass changeit \
#    && update-ca-certificates

# Configure git
#git config --global http.sslVerify false
git config --global http.sslCAinfo /usr/local/share/ca-certificates/mycertificate.crt

# Upgrade pip
pip install --upgrade pip

unset http_proxy
unset https_proxy
unset no_proxy

npm config rm proxy
npm config rm https-proxy

npm install -g wpm yarn karma-cli gulp-cli pm2 --reg http://nexus.wdf.sap.corp:8081/nexus/content/groups/build.milestones.npm/
