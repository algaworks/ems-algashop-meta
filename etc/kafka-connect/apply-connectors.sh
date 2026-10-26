#!/bin/sh
# Aplica no Kafka Connect todos os conectores desta pasta (um JSON por conector).
# PUT /connectors/{nome}/config cria o conector ou atualiza a configuração: pode rodar quantas vezes quiser.
#
# Uso (host):      CONNECT_URL=http://localhost:8085 ./apply-connectors.sh
# Uso (contêiner): ver o serviço algashop-kafka-connect-init no docker-compose.tools.yml

CONNECT_URL=${CONNECT_URL:-http://localhost:8085}
DIR=$(cd "$(dirname "$0")" && pwd)

echo "Aguardando o Kafka Connect em $CONNECT_URL ..."
until curl -sf "$CONNECT_URL/connectors" > /dev/null; do
  sleep 3
done

# Primeiro os source (criam os tópicos), depois os sink
for file in "$DIR"/cdc.source.*.json "$DIR"/cdc.sink.*.json; do
  name=$(basename "$file" .json)
  code=$(curl -s -o /dev/null -w '%{http_code}' -X PUT -H 'Content-Type: application/json' \
    --data @"$file" "$CONNECT_URL/connectors/$name/config")
  echo "$name -> HTTP $code"
done

# Se as tabelas ainda não existiam quando o conector foi criado, a tarefa fica FAILED.
# Rode o script de novo depois que os serviços subirem: ele reinicia só as tarefas com falha.
for file in "$DIR"/cdc.source.*.json "$DIR"/cdc.sink.*.json; do
  name=$(basename "$file" .json)
  curl -s -o /dev/null -X POST "$CONNECT_URL/connectors/$name/restart?includeTasks=true&onlyFailed=true"
done