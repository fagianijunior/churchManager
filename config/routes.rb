Rails.application.routes.draw do
  get 'dashboard/index'
  get 'home/index'
  resources :transactions
  resources :wallets
  devise_for :users
  resources :users
  resources :churches

  authenticated :user do
    root 'dashboard#index', as: :authenticated_root
  end

  root "home#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
