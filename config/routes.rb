Rails.application.routes.draw do
  apipie
  require 'sidekiq/web'

  devise_for :users
  resources :scripts

  namespace :v1 do
    namespace :api do
      # APIs for script creation/status
      post "/script" => 'script#create_script'
      get "/script" => 'script#check_script'
      put "/script" => 'script#resubmit_script'
      get "/scripts" => 'script#list_scripts'

      # APIs for rerun/validate script
      get "/script/rerun" => 'script#rerun_script'
      get "/script/revalidate" => 'script#revalidate_script'

      # APIs for codes/metrics of a script
      get "/script/metric" => 'script#get_metric'
      get "/script/metrics" => 'script#list_metrics_for_script'
      get "/script/code" => 'script#get_code'
      get "/script/code/metrics" => 'script#list_metrics_for_private_code'
      get "/script/code/rerun" => 'script#rerun_script_code_and_share'
      get "/script/codes" => 'script#list_codes_for_script'

      # APis for public codes
      get "/code" => 'script#get_public_code'
      get "/code/metrics" => 'script#list_metrics_for_public_code'
      get "/code/rerun" => 'script#rerun_public_code'
      get "/codes" => 'script#list_public_codes'

      # APIs for user object methods/operations
      get "/myobject" => 'user_objects#create_user_object'
      post "/myobject/method" => 'user_objects#add_user_method'
      get "/myobject/run" => 'user_objects#execute_user_method'
      get "/myobject/methods" => 'user_objects#list_user_methods'

      # APIs to query sidekiq state - only for selected users
      get "/sidekiqjobs" => 'script#get_sidekiq_jobs'
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "execute_scripts#index"
  get 'resultti', to: 'execute_scripts#result_time'
  get 'resultsc', to: 'execute_scripts#result_script'
  get 'resultred', to: 'execute_scripts#result_redis'

  mount Sidekiq::Web => '/sidekiq'
end
