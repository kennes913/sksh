# Assumes the local running container is named blog
docker stop blog;
docker rm blog;
rm -rf public;
hugo --config $(pwd)/config/config.toml;
docker run --name blog -v $(pwd)/public:/usr/share/nginx/html:ro -p 8000:80 -d nginx:1.17.7-alpine;
