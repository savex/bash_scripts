#!/bin/sh
# Creating tenant
openstack project create --description 'Rally and Tempest testing project' testing
# Giving access to admin
openstack role add --user admin --project testing admin

# function to create user
function create_user() {
    openstack user create --project testing --password 1234 $1
    openstack user set $1 --email $1@example.com
}

function add_admin_role_for_user() {
    openstack role add --user $1 --project testing admin
}

#Creating users
create_user test_user1
add_admin_role_for_user test_user1
create_user test_user2
add_admin_role_for_user test_user2
create_user test_user3
create_user test_user4