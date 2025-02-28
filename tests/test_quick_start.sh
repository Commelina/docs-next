#!/bin/bash
set -e

IMAGE=$(cat assets/quick-start.yaml | grep "image:.*hstreamdb/hstream" | head -n 1 | awk '{print $2}')
# XXX: Github action seems hang up when read string from /dev/urandom
#STREAM_NAME="demo_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)"
STREAM_NAME="demo_$RANDOM"

cleanup() {
    echo "-> clean..."
    docker rm -f some-hstream-cli
}

echo "Docker image: $IMAGE"

docker run -t --rm --name some-hstream-cli --network host \
    $IMAGE hstream --port 6570 sql -e "CREATE STREAM $STREAM_NAME;"

docker run -td --rm --name some-hstream-cli --network host \
  $IMAGE hstream --port 6570 sql -e \
    "SELECT * FROM $STREAM_NAME WHERE humidity > 70 EMIT CHANGES;"

# FIXME: a SELECT task is created asynchronously. We need a way to indicate the
# task is done instead of waiting fixed time.
sleep 15

docker exec -t some-hstream-cli hstream --port 6570 sql -e "INSERT INTO $STREAM_NAME (temperature, humidity) VALUES (22, 80);"
docker exec -t some-hstream-cli hstream --port 6570 sql -e "INSERT INTO $STREAM_NAME (temperature, humidity) VALUES (15, 20);"
docker exec -t some-hstream-cli hstream --port 6570 sql -e "INSERT INTO $STREAM_NAME (temperature, humidity) VALUES (31, 76);"
docker exec -t some-hstream-cli hstream --port 6570 sql -e "INSERT INTO $STREAM_NAME (temperature, humidity) VALUES ( 5, 45);"
docker exec -t some-hstream-cli hstream --port 6570 sql -e "INSERT INTO $STREAM_NAME (temperature, humidity) VALUES (27, 82);"
docker exec -t some-hstream-cli hstream --port 6570 sql -e "INSERT INTO $STREAM_NAME (temperature, humidity) VALUES (28, 86);"

sleep 5

OUTPUT=$(mktemp)

echo "-> write results to $OUTPUT..."
docker logs some-hstream-cli > $OUTPUT

echo "-> results: "
cat -e $OUTPUT

echo "-> compare results..."
cmp --silent $OUTPUT tests/quick_start_sql_001.txt || \
    (docker-compose -f assets/quick-start.yaml logs ; cleanup ; exit 1)

cleanup
