install=$1

$install 
if [ "$?" -eq "0" ]; then
    exit 1
fi
darknode --version