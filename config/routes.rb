Rails.application.routes.draw do
  root "triage#index"

  resources :quotes, only: %i[show], param: :external_id
  resource  :cadence, only: %i[edit update]

  resources :messages, only: %i[index] do
    resource :approval, only: %i[create destroy] # POST approves and sends, DELETE denies
  end

  post "demo/reset", to: "demo#reset", as: :demo_reset
  post "demo/next-event", to: "demo#next_event", as: :demo_next_event
  post "demo/cycle", to: "demo#cycle", as: :demo_cycle
  post "demo/advance", to: "demo#advance", as: :demo_advance

  get "up" => "rails/health#show", as: :rails_health_check
end
