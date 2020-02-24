# https://travis-ci.community/t/java-support-on-windows/286/7
export JAVA_HOME=${JAVA_HOME:-/c/jdk}
export PATH=${JAVA_HOME}/bin:${PATH}
choco install jdk8 -params 'installdir=c:\\jdk' -y
