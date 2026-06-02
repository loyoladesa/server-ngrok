#!/bin/bash
# Inicia o Nginx em background
nginx

# Inicia o ngrok em foreground (mantém o container vivo)
ngrok http --url=qoernp.ngrok.app 80