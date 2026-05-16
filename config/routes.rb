Rails.application.routes.draw do
  root "kudos#index"
  get  "/kudos", to: "kudos#index"

  post "/webhooks/slack", to: "webhooks#slack"
  post "/uploads/slack",  to: "uploads#slack"
end
