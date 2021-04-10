# Benchmark Scripts/Snippets
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
