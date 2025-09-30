Rails.application.routes.draw do
  mount PromptEngine::Engine => "/prompt_engine"  # admin UI
  resources :validities, only: %i[new create]
  get 'validity/:id', to: 'validities#show', as: 'validity'
  get 'evaluation', to: 'evaluation#index', as: 'evaluation'
  get 'eval_out/:filename', to: 'evaluation#download', as: 'eval_file'
  get '/up', to: proc { [200, {}, ['OK']] }  # health check
  root "validities#new"
end