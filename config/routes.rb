Rails.application.routes.draw do
  get 'home/index'
  resources :transactions
  resources :wallets
  devise_for :users
  resources :users
  resources :churches
  root to: "home#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
