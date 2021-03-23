Rails.application.routes.draw do
  require 'sidekiq/web'

  devise_for :users
  resources :scripts

  namespace :v1 do
    namespace :api do
      post '/scripts' => 'api_scripts#create_script'
      get "/scripts" => 'api_scripts#check_script'
      put "/scripts" => 'api_scripts#resubmit_script'
      get "/scripts/rerun" => 'api_scripts#rerun_script'
      get "/scripts/reruncode" => 'api_scripts#rerun_code'
      get "/metric" => 'api_scripts#get_metric'
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "execute_scripts#index"
  get 'resultti', to: 'execute_scripts#result_time'
  get 'resultsc', to: 'execute_scripts#result_script'
  get 'resultred', to: 'execute_scripts#result_redis'

  mount Sidekiq::Web => '/sidekiq'
end
