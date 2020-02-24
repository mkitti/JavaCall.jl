echo $TRAVIS_JDK_VERSION
if [ $TRAVIS_OS_NAME == "windows" ]; then
    #From https://travis-ci.community/t/java-support-on-windows/286/7
    #export JAVA_HOME=${JAVA_HOME:-/c/jdk}
    #export PATH=${JAVA_HOME}/bin:${PATH}
    #choco install openjdk11 -params 'installdir=c:\\jdk' -y
    choco install openjdk11
    #export JAVA_HOME="C:\Program Files\OpenJDK\openjdk-11.0.5_10"
    export JAVA_HOME=`powershell -c "Import-Module \"\$env:ChocolateyInstall\\helpers\\chocolateyInstaller.psm1\" -Force; Get-EnvironmentVariable -Name 'JAVA_HOME' -Scope Machine"`
fi
echo $JAVA_HOME
