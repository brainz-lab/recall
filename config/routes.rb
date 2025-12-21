Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      post 'log', to: 'ingest#create'
      post 'logs', to: 'ingest#batch'
      get 'logs', to: 'logs#index'
      get 'logs/export', to: 'logs#export'
      get 'logs/:id', to: 'logs#show'
      resources :sessions, only: [:create, :destroy]
    end
  end

  # MCP Server
  namespace :mcp do
    get 'tools', to: 'tools#index'
    post 'tools/:name', to: 'tools#call'
    post 'rpc', to: 'tools#rpc'
  end

  # Dashboard
  namespace :dashboard do
    resources :projects do
      member do
        get :setup
        get :mcp_setup
        get :analytics
      end
      resources :logs, only: [:index, :show] do
        collection do
          get 'trace/:request_id', action: :trace, as: :trace
        end
      end
      resources :saved_searches, only: [:index, :create, :destroy]
      resources :exports, only: [:create]
      resource :archive, only: [:create, :show]
    end
    root to: 'projects#index'
  end

  # Health check
  get 'up', to: ->(_) { [200, {}, ['ok']] }

  # WebSocket
  mount ActionCable.server => '/cable'

  root 'dashboard/projects#index'
end
