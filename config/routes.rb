Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "execute_scripts#index"
  get 'resultti', to: 'execute_scripts#result_time'
  get 'resultsc', to: 'execute_scripts#result_script'
end
