#!/bin/bash

AWS_ACCESS_KEY_ID=LS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=LS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION=LS_REGION

# Arquivo que sinaliza ao health check do container que segredos e parâmetros já foram cadastrados.
# Fica num tmpfs (docker-compose.tools.yml), então já nasce vazio a cada start do container.
READY_FILE=/run/algashop/ready
rm -f "$READY_FILE"

# Cada falha de cadastro vira uma linha neste arquivo. Os cadastros rodam em segundo plano (subshells),
# que não conseguem alterar uma variável do script; por isso a contagem é feita pelo arquivo.
FAIL_FILE=/tmp/algashop-failures
: > "$FAIL_FILE"

# Quantos cadastros rodam ao mesmo tempo. Cada awslocal é um processo Python novo, então é o paralelismo que reduz o tempo.
MAX_JOBS=10

# Executa o comando em segundo plano, respeitando o limite de MAX_JOBS, e registra a falha se ele terminar com erro.
run() {
  while [ "$(jobs -rp | wc -l)" -ge "$MAX_JOBS" ]; do sleep 0.1; done
  ( "$@" || echo falha >> "$FAIL_FILE" ) &
}


openssl genpkey -algorithm RSA -out /tmp/algashop-private-key.pem -pkeyopt rsa_keygen_bits:2048

PRIVATE_KEY_B64=$(base64 -w 0 /tmp/algashop-private-key.pem)

PRIVATE_KEY_ID=$(openssl rand -hex 16)

printf '{"privateKeyId":"%s","privateKey":"%s"}' \
  "$PRIVATE_KEY_ID" "$PRIVATE_KEY_B64" > /tmp/secret.json

awslocal configure set cli_follow_urlparam false

run awslocal secretsmanager create-secret \
  --name /config/algashop/authorization-server/rsa-key \
  --secret-string file:///tmp/secret.json

# CSV


# Parâmetros do SSM
{
  read -r _header                       # descarta o cabeçalho
  while IFS=',' read -r name type value || [ -n "$name" ]; do  # robusto a arquivo sem \n final
    [ -z "$name" ] && continue          # pula linha em branco
    case "$name" in \#*) continue ;; esac   # pula comentário
    value=${value%$'\r'}                # remove \r se foi salvo no Windows
    run awslocal ssm put-parameter --name "$name" --type "$type" --value "$value" --overwrite
  done
} < /etc/aws/parameters.csv



# Segredos do Secrets Manager
{
  read -r _header
  while IFS=',' read -r name value || [ -n "$name" ]; do
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    value=${value%$'\r'}
    run awslocal secretsmanager create-secret --name "$name" --secret-string "$value"
  done
} < /etc/aws/secrets.csv

# Espera todos os cadastros terminarem antes de contar as falhas.
wait
FAILURES=$(wc -l < "$FAIL_FILE")


# Segredos e parâmetros cadastrados: já dá para os microsserviços iniciarem (os arquivos do S3 não travam o startup).
# O health check do container só passa quando este arquivo existir.
if [ "$FAILURES" -eq 0 ]; then
  touch "$READY_FILE"
  echo "LocalStack READY: segredos e parâmetros cadastrados"
else
  echo "LocalStack NOT READY: $FAILURES falha(s) ao cadastrar segredos/parâmetros" >&2
fi



# Buckets e arquivos do S3

awslocal s3 mb s3://algashop-product-image

awslocal s3api put-bucket-cors --bucket algashop-product-image --cors-configuration file:///etc/aws/cors.json

BUCKET=algashop-product-image

# S3
{
  read -r _header                                # descarta o cabeçalho
  while IFS=',' read -r key ct || [ -n "$key" ]; do  # robusto a arquivo sem \n final
    [ -z "$key" ] && continue                    # pula linha em branco
    case "$key" in \#*) continue ;; esac         # pula comentário
    ct=${ct%$'\r'}                               # remove \r se salvo no Windows
    awslocal s3api put-object \
      --bucket "$BUCKET" --key "$key" --content-type "$ct" --body "/etc/images/$key"
  done
} < /etc/aws/s3.csv
