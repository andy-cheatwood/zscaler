# Zscaler - Configuration - A Developer's Guide

## Overview

Whenever Zscaler’s SSL inspection feature is enabled to maintain secure connections on the corporate network, admins can use the organization generated certificate to connect to any secure website. By default, the root and intermediate certificates, which are required to trust the generated certificate of the organization are already added to the end user's system certificate store.

Some applications maintain a custom trust store instead of using the default system trust store.  As a result, the application will not be able to validate Zscaler generated server certificates and the TLS connection will fail. In such cases, the users will need to manually add the custom root CA to the custom trust store, or disable server certificate validation. (source: https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trusted-store )

## Things You’ll Need
### Zscaler Certificate(s)

ZscalerRootCertificate-2048-SHA256.crt (Only the Zscaler certificate. DER format)

ZscalerRootCertificate-2048-SHA256.pem (Only the Zscaler certificate. PEM format)

ZscalerRootCertificate-Bundle.pem (carefully curated collection of Root Certificates courtesy of Certifi with the ZscalerRootCertificate-2048-SHA256.pem cert appended)

```
# DESCRIPTION: A way to obtain the certificates programmatically 
# PREREQUISITES:
# - assumes that the certificate directory is: /var/cacerts (and that it already exists)(see: Initial Setup / Start Here)
#	- assumes that the macOS Zscaler application is installed (and has been logged into at least once)
#	- assumes that the Python/Python3 Certifi module is already installed. 
#		- to install Certifi (if ZIA is currently enabled):
#			- Run: `python -m pip config set global.trusted-host 'pypi.python.org pypi.org files.pythonhosted.org' &> /dev/null`
#			- Run: `python -m pip install certifi`

# Export Zscaler certificate from macOS Keychain (PEM)
/usr/bin/security find-certificate -c 'Zscaler' -p > "/var/cacerts/ZscalerRootCertificate-2048-SHA256.pem"

# Make a DER version of above PEM.
/usr/bin/openssl x509 -in "/var/cacerts/ZscalerRootCertificate-2048-SHA256.pem" -outform der -out "/var/cacerts/ZscalerRootCertificate-2048-SHA256.crt"

# Concatenate the Certifi and the Zscaler (PEM) cert as a "new" bundle cert (PEM) 
/bin/cat "$( python -m certifi )" "/var/cacerts/ZscalerRootCertificate-2048-SHA256.pem" > "/var/cacerts/ZscalerRootCertificate-Bundle.pem"
```

_Note:_

_A majority of the applications listed appear to expect the bundle cert (aka: ZscalerRootCertificate-Bundle.pem)._

_Java/Java-related things seem to expect only the Zscaler certificate (DER format. aka: ZscalerRootCertificate-2048-SHA256.crt_

### The Script (optional)

_In development_

Description: _should_ automate most of the documented configurations. (excluding: Docker, IntelliJ, gradlew and any of the tools missing documentation.)

[simple-zapp-config.sh](https://github.com/andy-cheatwood/zscaler/blob/main/simple-zapp-config.sh)

```
# usage
# In Terminal, run
sudo sh /path/to/simple-zapp-config.sh

# Optionally, one can define a "custom" directory for the certificates to be housed.
sudo sh /path/to/simple-zapp-config.sh ~"/cacerts"
```

There is also an _uninstall_ script available to "undo" the simple-zapp-config

[uninstall-zapp-config.sh](https://github.com/andy-cheatwood/zscaler/blob/main/uninstall-zapp-config.sh)

```
# usage
# In Terminal, run
sudo sh /path/to/uninstall-zapp-config.sh
```

## Initial Setup / Start Here
Create a directory to house the certificates (and put the certificates in it)

E.g. `mkdir -p /var/cacerts`

Create a custom shell configuration file (aka: a text file) with the following export(s)

In the following example, I am using cat to create a hidden file called .zapprc with the required exports. (CERT_PATH needs to be the actual path to the bundle cert on your device)

```
/bin/cat > "/var/cacerts/.zapprc" <<EOF
export CERT_PATH="/var/cacerts/ZscalerRootCertificate-Bundle.pem"
export DER_CERT_PATH="/var/cacerts/ZscalerRootCertificate-2048-SHA256.crt"
export SSL_CERT_FILE=\${CERT_PATH}
export SSL_CERT_DIR=\$(/usr/bin/dirname \${CERT_PATH})/
export REQUESTS_CA_BUNDLE=\${CERT_PATH}
export NODE_EXTRA_CA_CERTS=\${CERT_PATH}
EOF
``` 

Source the custom shell configuration file in your actual shell configuration file.

```
# bash
echo "source /var/cacerts/.zapprc" >> ~/.bash_profile
# zsh
echo "source /var/cacerts/.zapprc" >> ~/.zshrc
```

Quit and relaunch Terminal

May be able to just run: `exec -l $SHELL`

Should be able to complete the configurations documented below now.

***

## macOS Application Firewall

Source: https://help.zscaler.com/z-app/zscaler-app-processes-whitelist

Description: Whitelist Zscaler binaries in macOS application firewall

```
/usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Zscaler/Zscaler.app/Contents/MacOS/Zscaler --add /Applications/Zscaler/Zscaler.app/Contents/PlugIns/ZscalerTunnel --add /Applications/Zscaler/Zscaler.app/Contents/PlugIns/ZscalerService --add /Applications/Zscaler/.Updater/autoupdate-osx.app/Contents/MacOS/ZscalerUpdater
```

## Python

Sources: https://community.zscaler.com/t/installing-tls-ssl-root-certificates-to-non-standard-environments/7261#heading--macos, https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trusted-store#pip

Description: Configure python, pip, requests

_`"${CERT_PATH}"` is a global variable created during Initial Setup. It is the full path to the bundle cert._

```
# Python / pip Config
python -m pip config set global.cert "${CERT_PATH}"
python -m pip config set global.trusted-host 'pypi.python.org pypi.org files.pythonhosted.org'

# Python3 / pip Config
python3 -m pip config set global.cert "${CERT_PATH}"
python3 -m pip config set global.trusted-host 'pypi.python.org pypi.org files.pythonhosted.org'

# Pip3 Config
pip3 config set global.cert "${CERT_PATH}"
pip3 config set global.trusted-host 'pypi.python.org pypi.org files.pythonhosted.org'
```

## OpenSSL

Source:

Description: 

_`SSL_CERT_FILE` and `SSL_CERT_DIR` are global variables created during Initial Setup. Defining these is all that is needed for this config._

## Git

Source: https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trusted-store#git-macos

Description: Configure git

```
git config --global http.sslcainfo "${CERT_PATH}"
git config --system http.sslcainfo "${CERT_PATH}"
```

## Java

Source: https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trusted-store#java

Description: Configure java. Import DER formatted Zscaler cert using keytool.

_`"${DER_CERT_PATH}"` is a global variable created during Initial Setup._

```
/usr/bin/keytool -import -alias "ZscalerConfig" -noprompt -trustcacerts -cacerts -storepass changeit -file "${DER_CERT_PATH}"
```

_It may be necessary to do the above for all keystores/Java homes (that get used), if so_

```
# List all Java "homes"
/usr/libexec/java_home -V

# **Example result of above command**
# Matching Java Virtual Machines (3):
#     15.0.1 (x86_64) "UNDEFINED" - "OpenJDK 15.0.1" /usr/local/Cellar/openjdk/15.0.1/libexec/openjdk.jdk/Contents/Home
#     14.0.1 (x86_64) "Oracle Corporation" - "Java SE 14.0.1" /Library/Java/JavaVirtualMachines/jdk-14.0.1.jdk/Contents/Home
#     1.8.281.09 (x86_64) "Oracle Corporation" - "Java" /Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home
# /usr/local/Cellar/openjdk/15.0.1/libexec/openjdk.jdk/Contents/Home

# Note: keystore should be located at .../Contents/home/lib/security/cacerts (for each)
# Example:
/usr/bin/keytool -import -noprompt -trustcacerts \
  -keystore /Library/Java/JavaVirtualMachines/jdk-14.0.1.jdk/Contents/Home/lib/security/cacerts -storepass changeit -alias 'ZscalerConfig' -file "${DER_CERT_PATH}"
```

## NPM

Source: https://docs.npmjs.com/cli/v6/using-npm/config#cafile, https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trusted-store#cafile

Description: Configure NPM.

_`NODE_EXTRA_CA_CERTS` is a global variable created during Initial Setup._

`npm config set cafile "${CERT_PATH}"`

## Yarn

Source: https://github.com/gatsbyjs/gatsby/issues/15807#issue-468873069 

Description: Configure yarn

`yarn config set cafile "${CERT_PATH}"`

## Docker

Source:

Description: Configure docker image

Depends of docker tool used (Docker Desktop for Mac ? Docker toolbox ? ).

Depending of the images you’re building

The general principle is that Zscaler certificate needs to be pushed inside the image you’re building, for your curl and other https call to go through.

An example which works with ubuntu (and so debian) based images

On your computer

copy ZscalerRootCertificate-2048-SHA256.pem in the docker build folder and rename it as ZscalerRootCertificate-2048-SHA256.crt (if you keep the .pem extension, the following steps will fail)

In the Dockerfile , after the FROM import of the image, copy the certificate into the certificate target of the image you’re running.

```
ADD ZscalerRootCertificate-2048-SHA256.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
```
Another example with CentOS images
```
ADD ZscalerRootCertificate-2048-SHA256.crt /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust extract
```

Example Dockerfile

1. The Zscaler certificate must be in the same directory as the Dockerfile
2. Additionally, the certificate must be PEM formatted, **BUT** with a `.crt` extension.
3. (maybe optional) 
  - Obtain "Zscaler IP" from [http://ip.zscaler.com/](http://ip.zscaler.com/)
  - Locate similar IP (CIDR notation) from [https://config.zscaler.com/zscaler.net/cenr](https://config.zscaler.com/zscaler.net/cenr)
    - E.g. `165.225.8.0/23`
  - Update Docker network preferences: **Docker > Preferences > Resources > Network > Docker Subnet > 165.225.8.0/23**

```
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ADD ZscalerRootCertificate-2048-SHA256-PEM.crt /usr/local/share/ca-certificates/ZscalerRootCertificate-2048-SHA256-PEM.crt
RUN apt update && apt upgrade -y
RUN apt install wget -y && \
	wget --no-check-certificate http://snapshot.debian.org/archive/debian-archive/20190328T105444Z/debian/pool/main/c/ca-certificates/ca-certificates_20141019%2Bdeb8u3_all.deb && \
	apt install --allow-downgrades -y ./ca-certificates_20141019+deb8u3_all.deb && \
	update-ca-certificates

RUN apt install openssl curl -y
```

The location of the certs as well as the command to update the CA certs is image-dependent. The example above is for Ubuntu / Debian and CentOS based docker images. If you use another distribution flavor, please update this documentation accordingly.

## IntelliJ Platform

Source: https://www.jetbrains.com/help/idea/settings-tools-server-certificates.html, https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trusted-store#intellij

Description: Configure IntelliJ Platform.

I believe it expects only the Zscaler cert (PEM) (aka: ZscalerRootCertificate-2048-SHA256.pem )

Add the certificate it to the trust store based on the instructions provided in IntelliJ IDEA documentation

## Android Studio

Source: https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trusted-store#android

Description: Configure Android Studio.

```
# Ensure that you specify the full path to the Android Studio Keystore.
/usr/bin/keytool -import -noprompt -trustcacerts -keystore /Applications/Android\ Studio.app/Contents/jre/jdk/Contents/Home/jre/lib/security/cacerts -storepass changeit -alias ZscalerConfigAndroid -file "${DER_CERT_PATH}"
```
Unrelated: To use Zscaler Private Access on an Android emulated device, you’ll want to comment out all name-servers in resolv.conf and add nameserver $ZPA_IP_ADDR (using the actual IP)

## ScaleFT

Source: https://help.okta.com/en/prod/Content/Topics/Adv_Server_Access/docs/client.htm

Description: Configure sft

`sft config network.tls_use_bundled_cas false`

## Gradlew

_This configuration has not been tested yet._

Source: https://serviceorientedarchitect.com/using-gradle-wrapper-behind-a-proxy-server-with-self-signed-ssl-certificates/ , https://stackoverflow.com/questions/8938994/gradlew-behind-a-proxy 

Description: Configure gradlew (gradle wrapper)

```
# create file named gradle.properties
systemProp.http.proxyHost=http://localhost
systemProp.http.proxyPort=9000
```

## Kubernetes

Source:

Description: Configure Kubernetes

## AWS

Source:

Description: Configure AWS

## gcloud

_This configuration has not been tested yet._

Source: https://cloud.google.com/sdk/gcloud/reference/config (see: custom_ca_certs_file)

Description: Configure gcloud

```
gcloud config set custom_ca_certs_file "${CERT_PATH}"
```

## Terraform

Source:

Description: Configure Terraform

## Additional Configurations

_IMPORTANT NOTE: These have **not** been tested, but _may_ be useful in certain scenarios. Use at your own risk._

**HTTP_PROXY**

_exports to add to your shell config files(s) (e.g. `~/.bash_profile`, `~/.zshrc`))_

```
export HTTP_PROXY=http://gateway.zscaler.net:80/
export HTTPS_PROXY=http://gateway.zscaler.net:80/
```

**git**

```
git config --system http.proxy http://gateway.zscaler.net:80/
git config --global http.proxy http://gateway.zscaler.net:80/ 
```

**npm**

```
npm config set proxy http://gateway.zscaler.net:80/
npm config set registry http://registry.npmjs.org/ --global
```

**yarn**

```
yarn config set proxy http://gateway.zscaler.net:80/
```

**sft**

```
sft config network.forward_proxy http://gateway.zscaler.net:80/
```

**Python | pip**

Source: https://pip.pypa.io/en/stable/user_guide/#using-a-proxy-server

Note: pip _should_ respect the http_proxy environment variable(s) too.

```
python -m pip config set global.proxy http://gateway.zscaler.net:80/
python3 -m pip config set global.proxy http://gateway.zscaler.net:80/
pip3 config set global.proxy http://gateway.zscaler.net:80/

```

## Getting Help

The Zscaler application has the ability to perform a packet capture (if enabled/allowed by admin). A packet capture is a networking term for intercepting a data packet that is crossing a specific point in a data network and it can be helpful when diagnosing _some_ issues.

Instructions for starting a packet capture and locating the .pcap file (aka: packet capture file) can be found on Zscaler's support site: https://help.zscaler.com/z-app/enabling-packet-capture-zscaler-app#using-start-packet-capture-option

Instructions for exporting Zscaler logs can be found on Zscaler’s support site: https://help.zscaler.com/z-app/about-zscaler-app-menu-bar-options-macos

_Note: The resulting .zip from Zscaler’s export logs feature should include the .pcap from the packet capture if a packet capture was run._

## Additional Resources

none
