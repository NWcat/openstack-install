#!/bin/bash

read -p "输入dbpass:" dbpass
read -p "输入KEYSTONE_DBPASS:" KEYSTONE_DBPASS
read -p "输入ADMIN_PASS:" ADMIN_PASS

mysql -u root -p$dbpass -e "CREATE DATABASE keystone"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
IDENTIFIED BY '$KEYSTONE_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
IDENTIFIED BY '$KEYSTONE_DBPASS'"

yum -y install openstack-keystone httpd python3-mod_wsgi

cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
cat > /etc/keystone/keystone.conf <<EOF
[DEFAULT]
[application_credential]
[assignment]
[auth]
[cache]
[catalog]
[cors]
[credential]
[database]
connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@$HOSTNAME/keystone
[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[federation]
[fernet_receipts]
[fernet_tokens]
[healthcheck]
[identity]
[identity_mapping]
[jwt_tokens]
[ldap]
[memcache]
[oauth1]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[policy]
[profiler]
[receipt]
[resource]
[revoke]
[role]
[saml]
[security_compliance]
[shadow_users]
[token]
provider = fernet
[tokenless_auth]
[totp]
[trust]
[unified_limit]
[wsgi]
EOF

su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
 keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://$HOSTNAME:5000/v3/ \
  --bootstrap-internal-url http://$HOSTNAME:5000/v3/ \
  --bootstrap-public-url http://$HOSTNAME:5000/v3/ \
  --bootstrap-region-id RegionOne

cp /etc/httpd/conf/httpd.conf{,.bak}
echo $HOSTNAME | sed -i "s?\#ServerName *?ServerName $HOSTNAME?" /etc/httpd/conf/httpd.conf 
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service
systemctl start httpd.service
cat > /root/admin-openrc << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$HOSTNAME:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

. /root/admin-openrc
openstack project create --domain default \
  --description "Service Project" service
