Rails.application.routes.draw do
  # Email preview in development
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  
  # ✨ NEW: JWT Token endpoint for ActionCable authentication
  get 'auth/axiam-token', to: 'auth#axiam_token'
  
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'devise/sessions'
  }

  devise_scope :user do
    get 'users/enable_facial_sign_on', to: 'users/registrations#enable_facial_sign_on', as: :enable_facial_sign_on
  end

  # Facial Sign-Up routes (API endpoints only, new signup page is at /users/sign_up)
  namespace :facial_signup do
    post 'create', to: 'facial_signup#create', as: :create
    get 'pending', to: 'facial_signup#pending', as: :pending
    get 'verify', to: 'facial_signup#verify', as: :verify
    get 'qr/:client_id', to: 'facial_signup#show_qr', as: :show_qr
    post 'complete', to: 'facial_signup#complete', as: :complete
  end

  resources :facial_sign_on, only: [] do
    collection do
      get :widget_login      # New: Axiam Widget login page
      get :login             # Legacy: Manual form login
      post :push_notification
      post :verified_login   # Đăng nhập khi nhận verified từ Axiam
      get :get_verification_token  # 🔒 NEW: Secure API to get token from session
    end
  end

  get '/facial_sign_on/widget', to: 'facial_sign_on#widget_login', as: :facial_sign_on_widget
  get '/facial_sign_on/login', to: 'facial_sign_on#login', as: :facial_sign_on_login

  # API routes for Axiam Facial Sign-On integration
  namespace :api do
    # Facial Sign-On API endpoints
    post 'facial_sign_on/lookup', to: 'facial_sign_on#lookup'
    post 'facial_sign_on/push_notification', to: 'facial_sign_on#push_notification'
    
    # Session management API
    resources :sessions, only: [:create, :destroy] do
      collection do
        get :current  # GET /api/sessions/current - Check current session
      end
    end
  end

  root 'home#index'
  get 'dashboard', to: 'home#dashboard'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
