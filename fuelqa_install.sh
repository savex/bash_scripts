# Locale for Perl
export LANG=C
export LANGUAGE=C
export LC_ALL=C

#User creds
ATT_ID=os7734
SSH_KEY=$1
SSH_KEY_PASS=$2

# repo base link
REPO_BASE=ssh://${ATT_ID}@gerrit.mtn5.cci.att.com:29418

# pypi index mirror
PYPI_INDEX=http://ubuntumirror.it.att.com:8080/pip/simple/
PYPI_HOST=ubuntumirror.it.att.com

#fuel-qa repos
FUEL_QA_REPO=${REPO_BASE}/fuel-qa

# venv name and path
FUEL_DEVOPS_VENV_NAME=fuel-devops-venv
VENV_PATH_BASE=~

#fuel qa repo link
FUEL_DEVOPS_REPO=${REPO_BASE}/fuel-devops
# not used. just for notice on internet version of Fuel-Devops to clone
FUEL_DEVOPS_VERSION=2.9.9

#pass
DB_PASS=fuel_devops
DB_NAME=fuel_devops
DB_USER_NAME=fuel_devops

# ISO related
export ISO_PATH=~/
export NODES_COUNT=4

export ENV_NAME=fuel_qa_tests
export VENV_PATH=${VENV_PATH_BASE}/${FUEL_DEVOPS_VENV_NAME}

# activate Fuel-Devops virtual environment
activate_fuel_devops_env() {
	source  ${VENV_PATH_BASE}/${FUEL_DEVOPS_VENV_NAME}/bin/activate
}

# configure distutils inside venv to work with our internal environment
configure_distutils() {
	echo "
# This is a config file local to this virtualenv installation
# You may include options that will be used by all distutils commands,
# and by easy_install.  For instance:
#
[easy_install]
index_url = ${PYPI_INDEX}
" > ${VENV_PATH_BASE}/${FUEL_DEVOPS_VENV_NAME}/lib/python2.7/distutils/distutils.cfg
}

# init ssh-agent and add identity
ssh_init() {
        eval $(ssh-agent -s)
        expect -c "
spawn ssh-add $SSH_KEY
expect -nocase \"id_rsa:\"
send \"${SSH_KEY_PASS}\r\"; interact
"
}

# installing system and virtual env libs
install_system_libs() {
	# Libs to install
	echo ====== Installing needed libs...
	apt-get install expect
	apt-get install git \
	postgresql \
	postgresql-server-dev-all \
	libyaml-dev \
	libffi-dev \
	python-dev \
	python-libvirt \
	python-pip \
	qemu-kvm \
	qemu-utils \
	libvirt-bin \
	libvirt-dev \
	ubuntu-vm-builder \
	bridge-utils

	apt-get update && apt-get upgrade -y
	apt-get install python-virtualenv libpq-dev libgmp-dev
}

# Cteate virtual environment and install devops there from internal GIT repo
create_devops_venv() {
	echo ====== Configuring virtual environment
	pip install pip virtualenv --upgrade --trusted-host ${PYPI_HOST}

	virtualenv --system-site-packages ${VENV_PATH_BASE}/${FUEL_DEVOPS_VENV_NAME}

	activate_fuel_devops_env
	configure_distutils
	pip install git+${FUEL_DEVOPS_REPO} --upgrade --trusted-host ${PYPI_HOST}
}

# Configure KVM
configure_kvm() {
	echo ====== Configuring KVM and permissions
	#setup virsh pool
	virsh pool-define-as --type=dir --name=default --target=/var/lib/libvirt/images
	virsh pool-autostart default
	virsh pool-start default

	# Permissions to run KVM
	usermod $(whoami) -a -G libvirtd,sudo
}

#Configure Django DB with specific user and table used by Devops tool
configure_django() {
	echo ====== Configuring DJango
	sed -ir 's/peer/trust/' /etc/postgresql/9.*/main/pg_hba.conf
	service postgresql restart
	expect -c "
spawn sudo -u postgres createuser -P fuel_devops
expect -nocase \"role:\"
send \"${DB_PASS}\r\"
expect -nocase \"again:\"
send \"${DB_PASS}\r\"; interact
"
	sudo -u postgres createdb ${DB_NAME} -O ${DB_USER_NAME}
	pwd
	django-admin.py syncdb --settings=devops.settings
	django-admin.py migrate devops --settings=devops.settings
}

# show info on nested paging parameter for KVM
check_nested_paging() {
	# Nested paging test
	echo ====== Nested paging status
	cat /etc/modprobe.d/qemu-system-x86.conf
	kvm-ok && cat /sys/module/kvm_intel/parameters/nested
}

# Install Fuel-QA from local repository, master branch
install_fuel_qa() {
	# Downloading fuel-qa
	echo ====== Downloading and configuring fuel-qa
	git clone ${FUEL_QA_REPO} # fuel-main for 6.0 and earlier
	cd fuel-qa/
	git checkout mirror
	activate_fuel_devops_env
	configure_distutils
	pip install -r ./fuelweb_test/requirements.txt --upgrade --trusted-host ${PYPI_HOST}
}

# Main
main() {
	if [ "$(id -u)" != "0" ]; then
   		echo "====== Running as user $(id -u). In order to install all needed libs, this script must be run as root" 1>&2
		echo "Trying to create venv and install Fuel-QA"
		ssh_init
		create_devops_venv
		install_fuel_qa
        else
	        echo "====== Running as 'root'"
		install_system_libs
		ssh_init
		create_devops_venv
	        configure_kvm
	        configure_django
	        check_nested_paging

	        install_fuel_qa
        fi
}

main

