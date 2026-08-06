Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :moves, only: %i[index show create update] do
        resources :notes, only: %i[index create]
        resources :checklist_items, only: %i[index create update destroy]

        member do
          post :delegate,  to: "move_delegations#delegate_action"
          post :claim,     to: "move_delegations#claim"
          post "delegation/callback", to: "move_delegations#callback", as: :delegation_callback
        end
      end
      get  "notes/search", to: "notes#search", as: :notes_search
      get  "today",        to: "today#index"
      get  "delegations",  to: "delegations#index"
    end
  end

  resource :session, only: %i[new create destroy]
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
    resources :notes, only: %i[create destroy]
    resources :checklist_items, only: %i[create update destroy]
  end
end
