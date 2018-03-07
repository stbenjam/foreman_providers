Rails.application.routes.draw do
  get 'new_action', to: 'foreman_providers/hosts#new_action'
end
