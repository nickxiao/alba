FROM centos:7
RUN rpm --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
RUN rpm -iUvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
RUN yum -y update
RUN yum -y install python-devel wget make m4 gcc install python-pip
RUN pip install fabric junit-xml
RUN yum -y install sudo
RUN yum -y install iproute
#
# Disable "ssh hostname sudo <cmd>", because it will show the password in clear.
#         You have to run "ssh -t hostname sudo <cmd>".
#
# Defaults    requiretty          # is line 56
RUN awk 'NR == 56 {next} {print}' /etc/sudoers >/tmp/__sudoers && mv /tmp/__sudoers /etc/sudoers
RUN useradd jenkins -u 1001 -g root
RUN echo "jenkins ALL=NOPASSWD: ALL" >/etc/sudoers.d/jenkins
