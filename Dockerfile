FROM centos:centos6

RUN yum install -q -y unzip

ADD agent.installer.linux.gtk.x86_64_*.zip /tmp/

RUN \
 unzip -qd /tmp/im /tmp/agent.installer.linux.gtk.x86_64_*.zip && \
 /tmp/im/installc \
   -acceptLicense \
   -showProgress \
   -installationDirectory /usr/lib/im \
   -dataLocation /var/im && \
 rm -rf /tmp/agent.installer.linux.gtk.x86_64_*.zip /tmp/im

RUN \
 REPO=http://www-912.ibm.com/software/repositorymanager/V85WASDeveloperILAN/repository.config && \
 /usr/lib/im/eclipse/tools/imutilsc saveCredential \
   -url $REPO \
   -userName USERNAME \
   -userPassword PASSWORD \
   -secureStorageFile /root/credentials && \
 /usr/lib/im/eclipse/tools/imcl install \
   com.ibm.websphere.DEVELOPERSILAN.v85_8.5.5003.20140730_1249 \
   -repositories $REPO \
   -acceptLicense \
   -showProgress \
   -secureStorageFile /root/credentials \
   -sharedResourcesDirectory /var/cache/im \
   -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false \
   -installationDirectory /usr/lib/was && \
 rm /root/credentials

RUN useradd --system -s /sbin/nologin -d /var/was was

RUN \
 hostname=$(hostname) && \
 /usr/lib/was/bin/manageprofiles.sh -create \
   -templatePath /usr/lib/was/profileTemplates/default \
   -profileName default \
   -profilePath /var/was \
   -cellName test -nodeName node1 -serverName server1 \
   -hostName $hostname && \
 echo -n $hostname > /var/was/.hostname && \
 chown -R was:was /var/was

USER was

RUN echo -en '#!/bin/bash\n\
set -e\n\
node_dir=/var/was/config/cells/test/nodes/node1\n\
launch_script=/var/was/bin/start_server1.sh\n\
old_hostname=$(cat /var/was/.hostname)\n\
hostname=$(hostname)\n\
if [ $old_hostname != $hostname ]; then\n\
  echo "Updating configuration with new hostname..."\n\
  sed -i -e "s/\"$old_hostname\"/\"$hostname\"/" $node_dir/serverindex.xml\n\
  echo $hostname > /var/was/.hostname\n\
fi\n\
if [ ! -e $launch_script ] ||\n\
   [ $node_dir/servers/server1/server.xml -nt $launch_script ]; then\n\
  echo "Generating launch script..."\n\
  /var/was/bin/startServer.sh server1 -script $launch_script\n\
fi\n\
' > /var/was/bin/updateConfig.sh && chmod a+x /var/was/bin/updateConfig.sh

# Speed up the first start of a new container
RUN /var/was/bin/updateConfig.sh

RUN echo -en '#!/bin/bash\n\
set -e\n\
/var/was/bin/updateConfig.sh\n\
echo "Starting server..."\n\
exec /var/was/bin/start_server1.sh\n\
' > /var/was/bin/start.sh && chmod a+x /var/was/bin/start.sh

CMD ["/var/was/bin/start.sh"]
