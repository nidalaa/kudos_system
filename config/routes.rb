Rails.application.routes.draw do
  post "/webhooks/slack", to: "webhooks#slack"
  post "/uploads/slack",  to: "uploads#slack"
end
