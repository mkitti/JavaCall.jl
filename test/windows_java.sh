echo $TRAVIS_JDK_VERSION
if [ $TRAVIS_OS_NAME == "windows" ]; then
    #From https://travis-ci.community/t/java-support-on-windows/286/7
    #export JAVA_HOME=${JAVA_HOME:-/c/jdk}
    #export PATH=${JAVA_HOME}/bin:${PATH}
    #choco install openjdk11 -params 'installdir=c:\\jdk' -y
    choco install openjdk11
fi
echo $JAVA_HOME
