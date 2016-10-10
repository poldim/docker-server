#!/bin/bash

# Variables

	#CONFIG=/opt/docker
	#MEDIA=/mnt/Storage/Media
	#DOWNLOADS=/mnt/Storage/Downloads

# Check if running as root

	if [ "$(id -u)" != "0" ]; then
   		echo "This script must be run as root" 1>&2
   		exit 1
	fi

# Functions

function _installdocker() {
    curl -sSL https://get.docker.com/ | sh
}

function _createcontainers() {

    cp -R ../systemd/*.service /etc/systemd/system
    systemctl daemon-reload

    # Plex
	docker pull linuxserver/plex
        docker create \
        --name=plex \
        --net=host \
        -e VERSION=latest \
        -e PUID=1000 -e PGID=1000 \
        -e TZ=America/Toronto \
        -v $CONFIG/plex:/config \
        -v $MEDIA:/data \
        linuxserver/plex
	docker start plex
	systemctl enable plex

    # CouchPotato
	docker pull linuxserver/couchpotato
        docker create \
        --name=couchpotato \
        -v $CONFIG/couchpotato:/config \
        -v $DOWNLOADS:/downloads \
        -v $MEDIA/Movies:/movies \
        -e PGID=1000 -e PUID=1000  \
        -e TZ=America/Toronto \
        -p 5050:5050 \
        linuxserver/couchpotato
	docker start couchpotato
	systemctl enable couchpotato

    # Sonarr
	docker pull linuxserver/sonarr
        docker create \
        --name sonarr \
        -p 8989:8989 \
        -e PUID=1000 -e PGID=1000 \
        -v /dev/rtc:/dev/rtc:ro \
        -v $CONFIG/sonarr:/config \
        -v $MEDIA/TV\ Shows:/tv \
        -v $DOWNLOADS:/downloads \
        linuxserver/sonarr
	docker start sonarr
	systemctl enable sonarr

    # PlexPy
	docker pull linuxserver/plexpy
        docker create \
        --name=plexpy \
        -v $CONFIG/plexpy:/config \
        -v $CONFIG/plex/Library/Application\ Support/Plex\ Media\ Server/Logs:/logs:ro \
        -e PGID=1000 -e PUID=1000  \
        -e TZ=America/Toronto \
        -p 8181:8181 \
        linuxserver/plexpy
	docker start plexpy
	systemctl enable plexpy

    # SABnzbd
	docker pull linuxserver/sabnzbd
        docker create \
        --name=sabnzbd \
        -v $CONFIG/sabnzbd:/config \
        -v $DOWNLOADS/Usenet:/downloads \
        -v $DOWNLOADS/Usenet/incomplete:/incomplete-downloads \
        -e PGID=1000 -e PUID=1000 \
        -e TZ=America/Toronto \
        -p 8080:8080 -p 9090:9090 \
        linuxserver/sabnzbd
	docker start sabnzbd
	systemctl enable sabnzbd

    # Deluge
	docker pull linuxserver/deluge
        docker create \
        --name deluge \
        --net=host \
        -e PUID=1000 -e PGID=1000 \
        -e TZ=America/Toronto \
        -v $DOWNLOADS/Torrents:/downloads \
        -v $CONFIG/deluge:/config \
        linuxserver/deluge
	docker start deluge
	systemctl enable deluge

    # Jackett
	docker pull linuxserver/jackett
        docker create \
        --name=jackett \
        -v $CONFIG/jackett:/config \
        -v $DOWNLOADS/Torrents/watch:/downloads \
        -e PGID=1000 -e PUID=1000 \
        -e TZ=America/Toronto \
        -p 9117:9117 \
        linuxserver/jackett
	docker start jackett
	systemctl enable jackett

    # PlexRequests
	docker pull linuxserver/plexrequests
        docker create \
        --name=plexrequests \
        -v /etc/localtime:/etc/localtime:ro \
        -v $CONFIG/plexrequests:/config \
        -e PGID=1000 -e PUID=1000  \
        -e URL_BASE=/requests \
        -p 3000:3000 \
        linuxserver/plexrequests
	docker start plexrequests
	systemctl enable plexrequests

    # Nginx
	docker pull linuxserver/nginx
        docker create \
        --name=nginx \
        -v /etc/localtime:/etc/localtime:ro \
        -v $CONFIG/nginx:/config \
        -e PGID=1000 -e PUID=1000  \
        -p 80:80 -p 443:443 \
        linuxserver/nginx
	docker start nginx
	systemctl enable nginx

    # CrashPlan
	docker pull jrcs/crashplan
        docker run -d \
        --name crashplan \
        -h $HOSTNAME \
        -e TZ=America/Toronto \
        -p 4242:4242 -p 4243:4243 \
        -v $CONFIG/crashplan:/var/crashplan \
        -v $MEDIA:/media \
        -v $CONFIG:/docker \
        jrcs/crashplan:latest
	docker start crashplan
	systemctl enable crashplan

    sleep 60 # wait for containers to start
}

spinner() {
    local pid=$1
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [${bold}${yellow}%c${normal}]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -ne "${OK}"
}

OK=$(echo -e "[ ${bold}${green}DONE${normal} ]")

echo -n "Please enter your username : "; read USER
echo -n "Please enter your password : "; read PASSWORD
echo -n "What is the path to docker container config files? : "; read CONFIG
echo -n "What is the path to media files? : "; read MEDIA
echo -n "What is the path to downloads? : "; read DOWNLOADS
echo -n "Installing docker ...";_installdocker >/dev/null 2>&1 & spinner $!;echo
usermod -aG docker $USER
newgrp docker
echo -n "Creating docker containers ...";_createcontainers >/dev/null 2>&1 & spinner $1;echo


#echo "Creating directories..."

	#mkdir -p $CONFIG/{plex,couchpotato,sonarr,plexpy,sabnzbd,deluge,jackett,plexrequests,nginx,crashplan}
	# Import zpool rather than create these directories in final script
	#mkdir -p $MEDIA/Movies
	#mkdir -p $MEDIA/TV\ Shows
	#mkdir -p $DOWNLOADS/Usenet/complete
	#mkdir -p $DOWNLOADS/Usenet/incomplete
	#mkdir -p $DOWNLOADS/Torrents/complete
	#mkdir -p $DOWNLOADS/Torrents/incomplete
	#mkdir -p $DOWNLOADS/Torrents/watch

echo -n "Setting permissions ..."; chown -R $USER:$USER $CONFIG $MEDIA $DOWNLOADS & spinner $1;echo


echo "Applying reverse proxy settings to containers..."

# CouchPotato
	docker stop couchpotato
	rm $CONFIG/couchpotato/config.ini
	cp ../apps/couchpotato/config.ini $CONFIG/couchpotato/
	docker start couchpotato

# Jackett
	docker stop jackett
	rm $CONFIG/jackett/Jackett/ServerConfig.json
	cp ../apps/jackett/ServerConfig.json $CONFIG/jackett/Jackett/
	docker start jackett

#PlexPy
	docker stop plexpy
	rm $CONFIG/plexpy/config.ini
	cp ../apps/plexpy/config.ini $CONFIG/plexpy/
	docker start plexpy

# Sonarr
	docker stop sonarr
	rm $CONFIG/sonarr/config.xml
	cp ../apps/sonarr/config.xml $CONFIG/sonarr/
	docker start sonarr

echo "Setting up nginx reverse proxies, basic authentication and SSL certificate..."

	docker stop nginx
	rm $CONFIG/nginx/nginx/site-confs/default # Adjust IP in this file as needed
	cp ../nginx/default $CONFIG/nginx/nginx/site-confs/
	cp ../nginx/.htpasswd $CONFIG/nginx/
	cp ../ssl/bergplex.* $CONFIG/nginx/keys
	docker start nginx

echo "BergPlex setup complete. Restore config data from CrashPlan now as needed. Ensure to stop affected containers first."
