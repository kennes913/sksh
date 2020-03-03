project_root := $(shell pwd)
build:
	echo 'Stopping previously running container';
	docker stop blog && docker rm blog || echo "No container is running";

	echo 'Rebuilding blog content';
	rm -rf ${project_root}/src/public;
	rm -rf ${project_root}/src/resources;
	hugo --source ${project_root}/src/ --config ${project_root}/src/config/config.toml

	echo 'Restarting container with newly mounted site build'
	docker run --name blog -v ${project_root}/src/public:/usr/share/nginx/html:ro -p 8000:80 -d nginx:1.17.7-alpine;

