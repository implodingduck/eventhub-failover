source .env
docker-compose down
docker-compose build
docker-compose up -d
docker logs -f eventhub-failover_consumer_1
