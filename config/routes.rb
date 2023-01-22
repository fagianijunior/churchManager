Rails.application.routes.draw do
  resources :administrations
  resources :occupations, except: :show
  resources :events
  devise_for :users
  get 'dashboard/index'
  get 'home/index'
  resources :movements
  resources :wallets
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
