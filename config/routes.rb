Rails.application.routes.draw do
  mount PromptEngine::Engine => "/prompt_engine"  # admin UI
  resources :validities, only: %i[new create]
  get 'validity/:id', to: 'validities#show', as: 'validity'
  get 'evaluation', to: 'evaluation#index', as: 'evaluation'
  get 'eval_out/:filename', to: 'evaluation#download', as: 'eval_file'
  # Simple health check that bypasses full Rails stack
  get '/up', to: proc { [200, {'Content-Type' => 'text/plain'}, ['OK']] }

  # Alternative health check route in case /up doesn't work
  get '/health', to: proc { [200, {'Content-Type' => 'text/plain'}, ['HEALTHY']] }
  root to: redirect('/prompt_engine')
end