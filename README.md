### Setup, Deployment
#### Local Machine
  * Node - version 12.7 or higher preferred
  * Ruby - 3.0.0
  * DB - sqlite3
  * Gemfile - has puma server (single mode - https://github.com/puma/puma/blob/master/docs/deployment.md)
  * Do a bundle install for gems and appropriate rails to be setup
    - might have to delete Gemfile.lock
  * If public/packs/manifest.json isn't present, just run yarn (hopefully won't throw an error with node 1[2-4].[7-12]).
  * Run with "rails s" (check logs for what server it's using)
  * Go to browser and visit localhost:3000
  * Sign up - a confirmation link should appear on the console (where "rails s" was done)
    - if doesn't show up, send confirmation link again a few times
  * Login and start using the Postman collection provided in lib/scripts/benchmarkit\_collection - after entering the Cookies fetched from Headers of inspecting any
    API call from the browser.

#### Dockerize and Run Locally
  * Tutorial - https://semaphoreci.com/community/tutorials/dockerizing-a-ruby-on-rails-application
    - It uses Unicorn server (with/without nginx), cache and sidekiq configured to use Redis, PostgresSQL, assumes no existing application
    - It configures sidekiq to use specific redis url via an initializer file, but we can do that even via an ENV variable (REDIS\_PROVIDER)
    - Ignore 70% of the post for an existing application with different setup than above.
  * For this application -
    - Rails, Puma and Sidekiq - they're installed via the bundle install.
    - Ruby, Redis, Node need to be installed via dockerfile. Somehow sqlite3 is also installed (accessible via rails console inside "docker exec -it ....").
    - Redis and Sidekiq need to be started too
  * For any new application with different setup, Dockerfile needs to have all the installation instructions.
  * Image created is around 80GB on my local (adding redis added 40 extra GB's) - probably due to the required dependencies.
    - Copying files from `/etc/skel' .. - Till this step (5), 850 MB
    - Setting up redis-tools (5:5.0.3-4+deb10u3) ... - Till this step (8), 39.9 GB
  * Couldn't get the redis and sidekiq running inside the container without manually logging in
    - using docker-compose.yml for now
  * Once image is created, can run it via \<docker run -p 3000:3000 \<image\_name\>:\<tag\>\>
    - adjust the ports according to your wishes
    - if need to install/edit something inside the container, go to the container as root \<bundle exec -u 0 -it <container_name> /bin/bash"\>
  * With the above manually building of docker image, we need to login and start redis and sidekiq for things to work correctly. Also, image size is around 80GB.
  * Go to the browser and visit localhost:3000 (based on the port mappings done above).
  * Get the cookies as described for local setup, run the APIs, etc.
    - Can check - GET "localhost:3000/v1/api/myobject/methods" fails without Redis
    - Can check - POST "localhost:3000/v1/api/script" fails without sidekiq running (if Redis isn't running, throws that error first)
    - After doing the above POST call, ensure that the job doesn't go to Retry - "localhost:3000/sidekiq" - since redis, sidekiq are started on the container, it
      shouldn't happen - should work like normal local setup. Everytime container is restarted, redis/sidekiq need to be restarted too.

#### Docker-Compose and Run Locally
  * Can use docker-compose to simplify things a bit -
    - since we've 3 services, the application itself, redis and sidekiq, list them in the YAML file
    - Careful to use the "version" key at the top of YAML file (docker-compose.yml)
    - use .env file to setup redis URL's at runtime
  * For some reason, the image size is down to 1.4 GB for the application (and another 1.4 GB for sidekiq version created by compose, 30 MB for Redis) 
  * It's much easier to manage everything - 
    - Need to change the code and rebuild the image (note: existing image must be rebuilt after code change, or try out something new by getting into the image as
      mentioned above using docker exec) - "docker-compose build" (it caches everything so changing paths in the YAML/code is risky => use --no-cache).
    - Need to stop and delete all associated containers - "docker-compose down"
    - Need to create/start associated containers - "docker-compose up"
  * Once the containers are built and running, follow the same way of getting/adding cookies and making API calls accordingly. Verify redis/sidekiq.
  * With sqlite3, which is built-in in that application, can't find a way to access same DB in sidekiq that's being used in benchmarkit.
    - so no sidekiq processing works.

### Description
  * Summary - 
    1. Submit a script for execution and benchmarking
    2. If the script fails some checks, it can be resubmitted multiple number of times
    3. If the script throws an error at runtime, it can be resubmitted multiple number of times
    4. If the script succeeds in checks and execution even once, then the script can't be changed.
    5. Successfully executed script can be rerun any number of times though, with different number of iteration parameters
    6. There's a provision to run a successfully executed script out of the context of script, just as an independent piece of code without affecting script's state.

  * Models - 
    1. Script - stores the status and description, the script file, the latest execution details (if it executed ever), and the latest code details.
    2. Code - status, size, LOC of all the uploaded scripts, even if they fail checks, are stored. A code has a script\_id.
    3. Metric - details of all the executions performed on a script, or a code - metric can be run via a file (when it must have script\_id) and via the stored code as well (when it has a static script\_id) - it always has some code\_id which tells the exact code which it ran upon. Stores iterations, user/system/real/total time of execution of the given code.

  * Workflow - 
    1. Submit a script for execution - POST /scripts
    2. The script will be stored, and its code will be independently stored. Checks run on the code via background job, and if successful, metric is created which will be updated based on the execution results.
    3. If the checks fail on the code, the status of script is updated to error. Similarly, if checks pass, but execution fails, status of the script will be updated to error.
    4. Status of a script can be checked - GET /scripts
    5. If status is error, then we can reupload the modified script with changed details - PUT /scripts
    6. If status is executed, then we can only rerun the locked script, with different iterations though - GET /scripts/rerun
    7. It is possible to execute a specific version of code which passed the checks but failed execution due to non-code errors (how? is it even possible?) - in that case, we can directly submit such codes for execution, and will be provided the corresponding metric ID created for the execution - GET /scripts/reruncode
    8. A metric can be directly queried as well, so it can handle the calls in (4) and (7) - GET /metric

  * Check lib/scripts/benchmarkit\_collection for the POSTMAN collection. Use the file lib/scripts/moreclasses.rb as the :textfile parameter.
  * Check lib/scripts for some default scripts
  * app/controller/execute\_scripts - executes some default scripts/snippets

  * Sources - 
    1. https://stackoverflow.com/questions/29327522/a-ruby-script-to-run-other-ruby-scripts?noredirect=1&lq=1 - run a script using load
    2. https://stackoverflow.com/questions/6012930/how-to-read-lines-of-a-file-in-ruby - read from file
    3. https://blog.appsignal.com/2018/02/27/benchmarking-ruby-code.html - benchmark.measure and others
    4. https://github.com/JuanitoFatas/fast-ruby
    5. https://stackoverflow.com/questions/24685037/convert-string-to-a-function-in-ruby-on-rails - instance\_eval for evaluating functions stored as string
    6. https://stackoverflow.com/questions/8590098/how-to-check-for-file-existence - check for file existence
    7. https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html - sanitizer library for common work
    8. https://stackoverflow.com/questions/37807137/rails-what-is-sanitize-in-rails - sanitization in genral
    9. https://medium.com/@matt.readout/rails-generators-model-vs-resource-vs-scaffold-19d6e24168ee - rails generate capabilities
    10. https://www.pluralsight.com/guides/handling-file-upload-using-ruby-on-rails-5-api - POST files using paperclip/carrierwave (paperclip deprecated)
    11. https://www.airpair.com/ruby-on-rails/posts/building-a-restful-api-in-a-rails-application - add APIs to rails application without external libs
    12. https://github.com/Apipie/apipie-rails - documentation generator for rails APIs
    13. https://guides.rubyonrails.org/api_app.html - create/change existing to API only rails application
    14. https://www.sitepoint.com/devise-authentication-in-depth/ - using devise for auth
    15. https://guides.railsgirls.com/devise - devise basics
    16. https://edgeguides.rubyonrails.org/debugging_rails_applications.html - various debuggin options, including a small byebug tutorial
