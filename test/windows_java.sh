if [ $TRAVIS_OS_NAME == "windows" ]; then
    #From https://travis-ci.community/t/java-support-on-windows/286/7
    echo $TRAVIS_JDK_VERSION
    export JAVA_HOME=${JAVA_HOME:-/c/jdk}
    export PATH=${JAVA_HOME}/bin:${PATH}
    choco install jdk8 -params 'installdir=c:\\jdk' -y
fi
