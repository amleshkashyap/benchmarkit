Rails.application.routes.draw do
  require 'sidekiq/web'

  devise_for :users
  resources :scripts

  namespace :v1 do
    namespace :api do
      # APIs for script creation/status
      post "/script" => 'api_scripts#create_script'
      get "/script" => 'api_scripts#check_script'
      put "/script" => 'api_scripts#resubmit_script'
      get "/scripts" => 'api_scripts#list_scripts'

      # APIs for rerun/validate script
      get "/script/rerun" => 'api_scripts#rerun_script'
      get "/script/revalidate" => 'api_scripts#revalidate_script'

      # APIs for codes/metrics of a script
      get "/script/metric" => 'api_scripts#get_metric'
      get "/script/metrics" => 'api_scripts#list_metrics_for_script'
      get "/script/code" => 'api_scripts#get_code'
      get "/script/code/metrics" => 'api_scripts#list_metrics_for_private_code'
      get "/script/code/rerun" => 'api_scripts#rerun_script_code_and_share'
      get "/script/codes" => 'api_scripts#list_codes_for_script'
      

      # APis for public codes
      get "/code" => 'api_scripts#get_public_code'
      get "/code/metrics" => 'api_scripts#list_metrics_for_public_code'
      get "/code/rerun" => 'api_scripts#rerun_public_code'
      get "/codes" => 'api_scripts#list_public_codes'

      # APIs for user object methods/operations
      get "/myobject" => 'api_user_objects#create_user_object'
      post "/myobject/method" => 'api_user_objects#add_user_method'
      get "/myobject/run" => 'api_user_objects#execute_user_method'
      get "/myobject/methods" => 'api_user_objects#list_user_methods'

      # APIs to query sidekiq state - only for selected users
      get "/sidekiqjobs" => 'api_scripts#get_sidekiq_jobs'
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "execute_scripts#index"
  get 'resultti', to: 'execute_scripts#result_time'
  get 'resultsc', to: 'execute_scripts#result_script'
  get 'resultred', to: 'execute_scripts#result_redis'

  mount Sidekiq::Web => '/sidekiq'
end
