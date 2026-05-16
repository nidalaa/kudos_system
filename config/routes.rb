Rails.application.routes.draw do
  root "kudos#index"
  get    "/kudos",     to: "kudos#index"
  delete "/kudos/all", to: "kudos#destroy_all"

  post "/webhooks/slack", to: "webhooks#slack"
  post "/uploads/slack",  to: "uploads#slack"
end
