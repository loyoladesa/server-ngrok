#!/bin/bash

# =============================================================
# Script de transcodificação para DASH usando FFmpeg
# 
# Este script gera múltiplas resoluções (1080p, 720p, 480p, 360p)
# com segmentação DASH, manifesto .mpd e GOP alinhado.
#
# Como executar:
#   chmod +x script.sh
#   ./script.sh video_entrada.mp4 prefixo_saida
#
# Input: arquivo de vídeo com pelo menos uma faixa de áudio.
# Output: arquivos de segmento (inicialização, mídia) e manifesto .mpd.
# =============================================================

# --- Verifica argumentos ---
if [ $# -ne 2 ]; then
    echo "Uso: $0 <arquivo_entrada> <prefixo_saida>"
    exit 1
fi

INPUT="$1"
PREFIX="$2"

# --- Definição das resoluções e bitrates de vídeo ---
# Cada resolução tem um bitrate alvo (b:v), máx (maxrate) e buffer (bufsize).
# 1080p: Alta definição, recomendado para telas grandes.
# 720p: HD padrão, bom para a maioria das conexões.
# 480p: SD, ideal para conexões móveis mais lentas.
# 360p: Baixa resolução, para conexões muito limitadas.
declare -A VIDEO_OPTS
VIDEO_OPTS[1080p]="scale=-2:1080:flags=lanczos,format=yuv420p"
VIDEO_OPTS[720p]="scale=-2:720:flags=lanczos,format=yuv420p"
VIDEO_OPTS[480p]="scale=-2:480:flags=lanczos,format=yuv420p"
VIDEO_OPTS[360p]="scale=-2:360:flags=lanczos,format=yuv420p"

declare -A BITRATE
BITRATE[1080p]=5000k
BITRATE[720p]=3000k
BITRATE[480p]=1500k
BITRATE[360p]=800k

declare -A MAXRATE
MAXRATE[1080p]=6000k
MAXRATE[720p]=4000k
MAXRATE[480p]=2000k
MAXRATE[360p]=1000k

declare -A BUFSIZE
BUFSIZE[1080p]=10000k
BUFSIZE[720p]=8000k
BUFSIZE[480p]=4000k
BUFSIZE[360p]=2000k

# --- Parâmetros do DASH ---
SEGMENT_DURATION=4            # Duração de cada segmento em segundos
GOP_SIZE=2                   # Tamanho do GOP em segundos (para alinhamento)

# --- Obtém taxa de quadros do vídeo de entrada (assume constante) ---
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT" | bc -l)
# Arredonda para inteiro (caso fracionário, ex: 29.97 -> 30)
FPS_INT=$(printf "%.0f" "$FPS")
# Se falhar, assume 30 fps
if [ -z "$FPS_INT" ] || [ "$FPS_INT" -eq 0 ]; then
    FPS_INT=30
fi

KEYINT=$((FPS_INT * GOP_SIZE))  # Número de quadros entre keyframes
echo "Taxa de quadros detectada: $FPS_INT fps -> GOP de $KEYINT quadros (~${GOP_SIZE}s)"

# --- Monta filtros complexos para gerar múltiplos streams de vídeo ---
# Cada stream terá uma saída de filtro (s:0, s:1, ...)
# A primeira saída de filtro será a primeira resolução, etc.
# Também incluímos o stream de áudio original.

FILTER_COMPLEX=""
MAP_OPTIONS=""
STREAM_INDEX=0

for res in 1080p 720p 480p 360p; do
    scale="${VIDEO_OPTS[$res]}"
    # Adiciona ao filter_complex com label
    FILTER_COMPLEX+="[0:v]${scale}[v${STREAM_INDEX}];"
    # Mapa para cada stream de vídeo criado
    MAP_OPTIONS+=" -map \"[v${STREAM_INDEX}]\""
    STREAM_INDEX=$((STREAM_INDEX + 1))
done

# Remove último ponto e vírgula do filter_complex
FILTER_COMPLEX="${FILTER_COMPLEX%;}"

# Mapeia o áudio (faixa 0) e possíveis legendas (se desejar, ignoramos)
MAP_OPTIONS+=" -map 0:a:0"

# --- Parâmetros para codificação de áudio ---
# AAC a 128 kbps, estéreo
AUDIO_OPTS="-c:a aac -b:a 128k -ac 2"

# --- Opções gerais de codificação de vídeo (libx264) ---
# GOP fixo com keyint, sem scene change (sc_threshold 0), perfil alto, CRF não usado (usamos bitrate)
VIDEO_COMMON="-c:v libx264 -profile:v main -preset medium -g $KEYINT -keyint_min $KEYINT -sc_threshold 0 -pix_fmt yuv420p"

# --- Monta comando final do FFmpeg ---
# -f dash: formato DASH
# -seg_duration: duração do segmento (4s)
# -use_template 1: nome dos segmentos baseado em template
# -use_timeline 1: manifesto usa linha do tempo
# -adaptation_sets: agrupa streams em adaptação. "id=0,streams=v" para vídeos, "id=1,streams=a" para áudio.
CMD="ffmpeg -i \"$INPUT\" \
    -filter_complex \"$FILTER_COMPLEX\" \
    $MAP_OPTIONS \
    $VIDEO_COMMON \
    -b:v:0 ${BITRATE[1080p]} -maxrate:v:0 ${MAXRATE[1080p]} -bufsize:v:0 ${BUFSIZE[1080p]} \
    -b:v:1 ${BITRATE[720p]}  -maxrate:v:1 ${MAXRATE[720p]}  -bufsize:v:1 ${BUFSIZE[720p]} \
    -b:v:2 ${BITRATE[480p]}  -maxrate:v:2 ${MAXRATE[480p]}  -bufsize:v:2 ${BUFSIZE[480p]} \
    -b:v:3 ${BITRATE[360p]}  -maxrate:v:3 ${MAXRATE[360p]}  -bufsize:v:3 ${BUFSIZE[360p]} \
    $AUDIO_OPTS \
    -f dash \
    -seg_duration $SEGMENT_DURATION \
    -use_template 1 \
    -use_timeline 1 \
    -adaptation_sets \"id=0,streams=v id=1,streams=a\" \
    \"${PREFIX}.mpd\""

echo "Comando a executar:"
echo "$CMD"
echo ""
echo "Iniciando transcodificação..."
eval $CMD
echo "Concluído. Manifesto: ${PREFIX}.mpd"