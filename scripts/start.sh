#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

#set -o nounset \
#    -o errexit \
#    -o verbose

verify_installed()
{
  local cmd="$1"
  if [[ $(type $cmd 2>&1) =~ "not found" ]]; then
    echo -e "\nERROR: This script requires '$cmd'. Please install '$cmd' and run again.\n"
    exit 1
  fi
}
verify_installed "jq"
verify_installed "docker-compose"
verify_installed "keytool"

# Verify Docker memory is increased to at least 8GB
DOCKER_MEMORY=$(docker system info | grep Memory | grep -o "[0-9\.]\+")
if (( $(echo "$DOCKER_MEMORY 7.0" | awk '{print ($1 < $2)}') )); then
  echo -e "\nWARNING: Did you remember to increase the memory available to Docker to at least 8GB (default is 2GB)? Demo may otherwise not work properly.\n"
  sleep 3
fi

# Stop existing demo Docker containers
${DIR}/stop.sh

# Generate keys and certificates used for SSL
echo -e "Generate keys and certificates used for SSL"
(cd ${DIR}/security && ./certs-create.sh)

# Bring up Docker Compose
echo -e "Bringing up Docker Compose"
docker-compose up -d

# Verify Docker containers started
if [[ $(docker-compose ps) =~ "Exit 137" ]]; then
  echo -e "\nERROR: At least one Docker container did not start properly, see 'docker-compose ps'. Did you remember to increase the memory available to Docker to at least 8GB (default is 2GB)?\n"
  exit 1
fi

# Verify Kafka Connect Worker has started within 120 seconds
MAX_WAIT=300
CUR_WAIT=0
echo "Waiting up to $MAX_WAIT seconds for Kafka Connect Worker to start"
while [[ ! $(docker-compose logs connect) =~ "Herder started" ]]; do
  sleep 3
  CUR_WAIT=$(( CUR_WAIT+3 ))
  if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
    echo -e "\nERROR: The logs in Kafka Connect container do not show 'Herder started'. Please troubleshoot with 'docker-compose ps' and 'docker-compose logs'.\n"
    exit 1
  fi
done

if [[ ! $(docker-compose exec connect timeout 3 nc -zv irc.wikimedia.org 6667) =~ "open" ]]; then
  echo -e "\nERROR: irc.wikimedia.org 6667 is unreachable. Please ensure connectivity before proceeding or try setting 'irc.server.port' to 8001 in scripts/connectors/submit_wikipedia_irc_config.sh\n"
  exit 1
fi

echo -e "\nStart streaming from the IRC source connector:"
${DIR}/connectors/submit_wikipedia_irc_config.sh

echo -e "\nStart Confluent Replicator:"
${DIR}/connectors/submit_replicator_config.sh

# Verify wikipedia.parsed topic is populated and schema is registered
MAX_WAIT=50
CUR_WAIT=0
echo -e "\nWaiting up to $MAX_WAIT seconds for wikipedia.parsed topic to be populated"
while [[ ! $(docker-compose exec schemaregistry curl -X GET --cert /etc/kafka/secrets/schemaregistry.certificate.pem --key /etc/kafka/secrets/schemaregistry.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt https://schemaregistry:8085/subjects) =~ "wikipedia.parsed-value" ]]; do
  sleep 3
  CUR_WAIT=$(( CUR_WAIT+3 ))
  if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
    echo -e "\nERROR: IRC connector is not populating the Kafka topic wikipedia.parsed. Please troubleshoot with 'docker-compose ps' and 'docker-compose logs'.\n"
    exit 1
  fi
done

# Register the same schema for the replicated topic wikipedia.parsed.replica as was created for the original topic wikipedia.parsed
# In this case the replicated topic will register with the same schema ID as the original topic
SCHEMA=$(docker-compose exec schemaregistry curl -X GET --cert /etc/kafka/secrets/schemaregistry.certificate.pem --key /etc/kafka/secrets/schemaregistry.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt https://schemaregistry:8085/subjects/wikipedia.parsed-value/versions/latest | jq .schema)
docker-compose exec schemaregistry curl -X POST --cert /etc/kafka/secrets/schemaregistry.certificate.pem --key /etc/kafka/secrets/schemaregistry.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt -H "Content-Type: application/vnd.schemaregistry.v1+json" --data "{\"schema\": $SCHEMA}" https://schemaregistry:8085/subjects/wikipedia.parsed.replica-value/versions

echo -e "\n\n\n******************************************************************"
echo -e "DONE! Connect to Connect at http://localhost:8083"
echo -e "DONE! Connect to Connect-2 at http://localhost:8084"
echo -e "DONE! Connect to Connect JMX at localhost:9995"
echo -e "DONE! Connect to Connect-2 JMX at localhost:9996"
echo -e "******************************************************************\n"

