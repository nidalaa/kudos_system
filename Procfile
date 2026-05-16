release: bundle exec rails db:migrate && bundle exec rails db:migrate:queue
web: bundle exec rails server -p $PORT -e $RAILS_ENV
worker: bin/jobs
