#!/bin/bash

### USAGE
###
### Make sure everything is updated
sudo apt-get update && sudo apt-get -y upgrade

### Install pre-requisites
sudo apt-get -y install git curl build-essential pwgen wget netcat python-software-properties apt-transport-https

### Install Java 8
cd ~
sudo apt-get remove --purge openjdk*
sleep 1
sudo apt-get install python-software-properties -y
sleep 1
sudo add-apt-repository ppa:webupd8team/java -y
sleep 1
sudo apt-get update
sleep 1
sudo apt-get install oracle-java8-installer -y
sleep 1
sudo echo "#### You should now see the version of Java 8 installed ####"
sudo java -version
sleep 5


### Install MongoDB
### Check https://www.mongodb.org/downloads for latest version of MongoDB

### Remove existing mongodb packages
sudo service mongod stop
sudo apt-get -y purge mongodb-org*
sudo apt-key del 7F0CEB10
sudo apt-key del EA312927
sudo rm -r /var/log/mongodb
sudo rm -r /var/lib/mongodb
sudo rm -rf /etc/apt/sources.list.d/mongodb*
sudo apt-get update

### Get version of Ubuntu installed
ver=`lsb_release -r | awk '{print $2}'`
echo ""
printf "Please select the version of MongoDB to install"
echo ""
PS3='Please enter your choice: '
#options=("Option 1" "Option 2" "Option 3" "Quit")
options=("MongoDB 10gen (2.x)" "MongoDB 3.x")
select opt in "${options[@]}"
do
    case $opt in
        "MongoDB 10gen (2.x)")
			### Download and install the Public Signing Key
			sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
            sudo echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
			sleep 1
			break
            ;;
        "MongoDB 3.x")
			sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
            if [ "$ver" = "12.04" ]
				then
				echo "deb http://repo.mongodb.org/apt/ubuntu precise/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
				sleep 1
			elif [ "$ver" = "14.04" ]
			 	then
				sudo echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
				sleep 1
				else
				echo "This script only supports 12.04 (Precise) & 14.04 (Trusty) releases of Ubuntu"
				return
				break
				fi
				break
            ;;
        *) echo invalid option;;
    esac
done

### continue with installation
sudo apt-get update
sleep 1
sudo apt-get install -y mongodb-org
sleep 1
#sudo echo -e "\033[31m You will now see if mongo is listening on port 27017. BE PATIENT"
sudo echo "#### Starting mongo and check if listening on port 27017. BE PATIENT ####"
sleep 1
#Test to see if mongo is listening
while ! nc -q0 localhost 27017 </dev/null >/dev/null 2>&1; do sleep 1 && printf '.'; done
printf "\n"
while ! nc -vz localhost 27017; do sleep 1; done
sleep 5

# Determine if mondo version will be pinned.
read -p "Would you like to pin the current version of MongoDB (Y/N)? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "mongodb-org hold" | sudo dpkg --set-selections
	echo "mongodb-org-server hold" | sudo dpkg --set-selections
	echo "mongodb-org-shell hold" | sudo dpkg --set-selections
	echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
	echo "mongodb-org-tools hold" | sudo dpkg --set-selections
fi



### Install ElasticSearch - (latest version - version 2.3.3 2016/5/18)

# Download and install the Public Signing Key
sudo wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
# Setup Repository
sudo echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
# Update & install
sudo apt-get update && sudo apt-get install elasticsearch -y

## Configure Elasticsearch to automatically start during bootup
sudo update-rc.d elasticsearch defaults 95 10

## Start ElasticSearch 
sudo service elasticsearch start

## Lets wait a little while ElasticSearch starts
#sleep 5
### Make sure service is running before proceeding
#curl http://localhost:9200
sudo echo -e "#### Waiting for ElasticSearch to start ####"
until $(curl --output /dev/null --silent --head --fail http://localhost:9200); do
    printf '.'
    sleep 5
done
printf "\n"
### Should return something like this:
##{
#  "name" : "Futurist",
#  "cluster_name" : "elasticsearch",
#  "version" : {
#    "number" : "2.3.3",
#    "build_hash" : "218bdf10790eef486ff2c41a3df5cfa32dadcfde",
#    "build_timestamp" : "2016-05-17T15:40:04Z",
#    "build_snapshot" : false,
#    "lucene_version" : "5.5.0"
#  },
#  "tagline" : "You Know, for Search"
#}

## edit config ElasticSearch

sudo echo "cluster.name: graylog2" >> /etc/elasticsearch/elasticsearch.yml
sudo echo "network.bind_host: localhost" >> /etc/elasticsearch/elasticsearch.yml
sudo echo "discovery.zen.ping.unicast.hosts: localhost" >> /etc/elasticsearch/elasticsearch.yml
sleep 1
sudo service elasticsearch restart

### Install Graylog
cd ~
wget https://packages.graylog2.org/repo/packages/graylog-2.0-repository_latest.deb
sleep 1
sudo dpkg -i graylog-2.0-repository_latest.deb
sleep 1
sudo apt-get update
sleep 1
sudo apt-get install graylog-server
sleep 1
sudo rm -f /etc/init/graylog-server.override

### Config for Graylog

## edit Graylog config

secret=$(pwgen -N 1 -s 96)
sudo sed -i "s/password_secret =/password_secret = $secret/g" /etc/graylog/server/server.conf

# Read Password
echo "Setting up your admin password!"
echo -n Password:
read -s password
echo
## Run Command
#echo $password
#hash=$(echo -n $password | sha256sum)
hash=$(echo -n $password | sha256sum | sed 's/\s.*$//')
#hash=$(echo -n $password | sha256sum | sed 's/\s.*$//' | sed 's/ *$//')
#hash=$(echo -n $password | sha256sum | sed 's/\s.*$//' | sed 's/[ \t]*$//')
#echo $hash
sudo sed -i "s/root_password_sha2 =/root_password_sha2 = $hash/g" /etc/graylog/server/server.conf

#Setup timezone in Graylog config
#timezone=$(date +%Z)
timezone=$(</etc/timezone)
#sudo echo "root_timezone = $timezone" >> /etc/graylog/server/server.conf
sudo echo "root_timezone = $timezone" >> /etc/graylog/server/server.conf
#Get ip address for computer and store as variable
ip=$(ifconfig | awk -F':' '/inet addr/&&!/127.0.0.1/{split($2,_," ");print _[1]}')
#Configure IP address in graylog config
sudo sed -i "s/127.0.0.1:12900/${ip}:12900/g" /etc/graylog/server/server.conf
#Configure URI in graylog config
sudo echo "rest_transport_uri = http://${ip}:12900" >> /etc/graylog/server/server.conf
#Change shards from 4 to 1
sudo sed -i "s/elasticsearch_shards = 4/elasticsearch_shards = 1/g" /etc/graylog/server/server.conf

#sudo sed -i "s/elasticsearch_index_prefix = graylog/elasticsearch_index_prefix = graylog2/g" /etc/graylog/server/server.conf
sleep 1
sudo echo "allow_leading_wildcard_searches = false" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "elasticsearch_discovery_zen_ping_unicast_hosts = 127.0.0.1:9300" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "dead_letters_enabled = false" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "web_listen_uri = http://0.0.0.0:9000/" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "elasticsearch_cluster_name = graylog2" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "elasticsearch_discovery_zen_ping_multicast_enabled = false" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "elasticsearch_cluster_discovery_timeout = 55000" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "dns_resolver_enabled = true" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "dns_resolver_run_before_extractors = true" >> /etc/graylog/server/server.conf
sleep 1
sudo echo "dns_resolver_timeout = 2s" >> /etc/graylog/server/server.conf
sleep 1
sudo start graylog-server
#Test for graylog-server listening before proceeding
until $(curl --output /dev/null --silent --head --fail http://localhost:9000); do
    printf '.'
    sleep 5
done
printf "\n"
sudo echo "#### Graylog server available at http://${ip}:9000 ####"
sudo echo "#### Username is admin and use the password you set earlier ####"

