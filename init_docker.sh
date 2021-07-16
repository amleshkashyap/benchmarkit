#!/bin/bash

echo 'Starting Redis Server'
redis-server &
echo 'Started Redis Server, Starting Sidekiq'
bundle exec sidekiq -C config/sidekiq.yml &
echo 'Started Sidekiq, Starting Rails'
bundle exec puma
