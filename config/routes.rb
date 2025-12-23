Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      post 'log', to: 'ingest#create'
      post 'logs', to: 'ingest#batch'
      get 'logs', to: 'logs#index'
      get 'logs/export', to: 'logs#export'
      get 'logs/:id', to: 'logs#show'
      resources :sessions, only: [:index, :show, :create, :destroy] do
        member do
          get :logs
        end
      end

      # Project provisioning (internal API for SDK auto-setup)
      post 'projects/provision', to: 'projects#provision'
      get 'projects/lookup', to: 'projects#lookup'
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
      resources :logs, only: [:index] do
        collection do
          get 'trace/:request_id', action: :trace, as: :trace
          get 'session/:session_id', action: :session_trace, as: :session_trace
        end
      end
      # Show route with constraint to avoid matching 'trace' or 'session'
      get 'logs/:id', to: 'logs#show', as: :log, constraints: { id: /(?!trace|session)[^\/]+/ }
      resources :saved_searches, only: [:index, :create, :destroy]
      resources :exports, only: [:create]
      resource :archive, only: [:create, :show]
    end
    root to: 'projects#index'

    # Dev Tools (development only)
    resource :dev_tools, only: [:show], controller: 'dev_tools' do
      post 'clean_logs'
      post 'clean_all'
    end
  end

  # SSO from Platform
  get 'sso/callback', to: 'sso#callback'

  # Health check
  get 'up', to: ->(_) { [200, {}, ['ok']] }

  # WebSocket
  mount ActionCable.server => '/cable'

  root 'dashboard/projects#index'
end
