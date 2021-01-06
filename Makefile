project_root := $(shell pwd)
build:
	echo 'Stopping previously running container';
	
	docker stop blog && docker rm blog || echo "No container is running";

	echo 'Rebuilding blog content';
	rm -rf ${project_root}/src/public;
	rm -rf ${project_root}/src/resources;
	hugo --source ${project_root}/src/ --config ${project_root}/src/config/config.toml

	echo 'Restarting container with newly mounted site build'
	docker run --name blog -v ${project_root}/src/public:/var/www/html:ro -p 80:80 -p 443:443 -d sknginx;

run_certbot:
	echo 'Renewing TLS certs';

	systemctl stop nginx;
	certbot renew;
	cp -r /etc/letsencrypt/ letsencrypt;
	cp /etc/nginx/sites-available/default le.sksh.nginx.conf;
	systemctl stop nginx;

	# Modify le.sksh.nginx.conf to add error page
	
	@build 

