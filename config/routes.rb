Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"
  resource :dashboard, only: :show, controller: "dashboard"

  resources :students, only: :show do
    resource :ai_summary, only: [ :create, :show ], module: "students" do
      post :follow_up
    end
  end

  resources :courses, only: [ :index, :show ]
end
