if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

apt-get install  libssl-dev libffi-dev python-dev libxml2-dev libxslt1-dev libpq-dev git python-pip
apt-get install screen
wget https://raw.githubusercontent.com/openstack/rally/master/install_rally.sh
chmod +x install_rally.sh
echo "    "
echo "============================"
echo "You can now install rally"
echo "  "
echo "./install_rally.sh -d /root/myrally"
echo "  " 
echo "============================="