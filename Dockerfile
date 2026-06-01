FROM ubuntu:latest

LABEL maintainer="Sidney Loyola"

RUN apt-get -y update

RUN apt-get -y install sudo

RUN apt-get -y install python3

RUN apt-get -y update

RUN apt-get -y install python3-pip

RUN apt-get -y install vim

RUN apt-get -y install nginx

WORKDIR /app/

COPY videos /etc/nginx/sites-available/videos

RUN sudo ln -s /etc/nginx/sites-available/videos /etc/nginx/sites-enabled/

RUN sudo service nginx reload

RUN sudo service nginx start

#COPY hls /var/www/html/hls

COPY dash /var/www/html/dash

RUN apt-get -y install curl

RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list && sudo apt-get -y update && sudo apt-get -y install ngrok

RUN ngrok config add-authtoken 2fcZ1KzNGtWXIfMPdcPIqsw6irN_61L8B67QBYThwTYWzFJ5n

RUN ngrok http --url=qoernp.ngrok.app 80

EXPOSE 5215


CMD ["ngrok","http --url=qoernp.ngrok.app 80"]

#CMD ["nginx", "-g", "daemon off;"]






