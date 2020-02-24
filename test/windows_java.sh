echo "TRAVIS_JDK_VERSION: "$TRAVIS_JDK_VERSION
if [ $TRAVIS_OS_NAME == "windows" ]; then
    #From https://travis-ci.community/t/java-support-on-windows/286/7
    #export JAVA_HOME=${JAVA_HOME:-/c/jdk}
    #export PATH=${JAVA_HOME}/bin:${PATH}
    #choco install openjdk11 -params 'installdir=c:\\jdk' -y
    choco install openjdk11
    #export JAVA_HOME="C:\Program Files\OpenJDK\openjdk-11.0.5_10"
    JAVA_ROOT_DIR='C:\Program Files\OpenJDK\'
    export JAVA_HOME=`find $JAVA_ROOT_DIR -name "openjdk-11*" | tail -n 1`
fi
echo "JAVA_HOME: "$JAVA_HOME
