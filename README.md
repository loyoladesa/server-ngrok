

1. Instalar ffmpeg no Linux (pode ser wsl)

   1. sudo apt update
   2. sudo apt install ffmpeg -y
   3. ffmpeg -version
2. Executar os seguintes commandos com o arquivo gerar\_dash.sh na pasta dash.

   1. file gerar\_dash.sh
   2. sed -i 's/\\r$//' gerar\_dash.sh
   3. chmod +x gerar\_dash.sh
   4. Verificar se a linha do interpretador está correta (ex.: #!/bin/bash)

      1. head -n 1 gerar\_dash.sh
3. Gere segmentos de videos com o seguinte commando :

   1. ./gerar\_dash.sh meu\_video.mp4 manifest.
   2. Os segmentos criados devem ficar na pasta dash
4. Criar imagem com o Dockerfile : docker build -t server-dash:1.0 .
5. Executar container: 

   1. docker run --name nginx-dash-5215 -d -p 8080:5215 server-dash:1.0
   2. Coloca o servidor em um localhost na porta 8080 e conecta com a porta 5215 do container
6. Para testar basta abrir o vlc, abrir transmissão de rede e colocar o endereço:

   1. http://127.0.0.1:8080/dash/manifest.mpd







