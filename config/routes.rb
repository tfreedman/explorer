Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  get '/block/:block' => 'application#block', :constraints => { :block => /[A-Za-z0-9]+/ }
  get '/tx/:transaction' => 'application#transaction', :constraints => { :transaction => /[A-Za-z0-9]+/ }
  get '/address/:address' => 'application#address', :constraints => { :address => /[A-Za-z0-9]+/ }
  get '/name/:type/:name' => 'application#name', :constraints => { :name => /[A-Za-z0-9]+/, :type => /[id]+/ }
  post '/search' => 'application#search', :constraints => { :query => /[A-Za-z0-9]+/ }

  get '/contact' => 'application#contact'
  get '/' => 'application#home'
end
