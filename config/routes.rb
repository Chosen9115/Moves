Rails.application.routes.draw do
  root "focus#index"

  get "up" => "rails/health#show", as: :rails_health_check

  get "inbox",  to: "inbox#index"
  get "focus",  to: "focus#index"
  get "archive", to: "archives#index"
  get "search", to: "searches#index"
  post "focus/dismiss_brief", to: "focus#dismiss_brief", as: :dismiss_brief

  resource :settings, only: %i[show update]
  resource :backups, only: [] do
    get :export
    post :import
  end

  resources :projects, only: %i[create update destroy]
  resources :campaigns
  resources :moves do
    collection do
      get :parse
      post :parse, action: :parse_submit
    end

    member do
      patch :activate
      patch :pause
      patch :archive
      patch :complete
      patch :reassess
      post :suggest_ai
      post :signal_summary
      post :probability_hint
    end

    resources :signals, only: :create
  end
end
