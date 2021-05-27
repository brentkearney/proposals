Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: 'users/sessions',
                                    registrations: 'users/registrations' }
  devise_scope :user do
    root to: 'users/sessions#new'
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get :guidelines, to: 'pages#guidelines'

  resources :dashboards
  resources :proposals do
    collection do
      get :text
    end
    resources :invites do
      member do
        post :inviter_response
      end
    end
  end
  
  resources :proposal_forms do
    member do
      post :clone
      delete :proposal_field
      get :proposal_field_edit
    end
    resources :proposal_fields do
      collection do
        post :latex_text
      end
    end
  end
  resources :submit_proposals
  resources :proposal_types do
    member do
      get :location_based_fields
      get :proposal_type_locations
    end
  end
  resources :locations do
    member do
      get :proposal_types
    end
  end
end
