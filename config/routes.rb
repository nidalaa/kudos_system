Rails.application.routes.draw do
  root "kudos#index"
  get    "/kudos-review",     to: "kudos#index",       as: :kudos_review
  delete "/kudos-review/all", to: "kudos#destroy_all", as: :kudos_review_all

  mount MissionControl::Jobs::Engine, at: "/jobs"

  post "/webhooks/slack", to: "webhooks#slack"
  post "/uploads/slack",  to: "uploads#slack"
end
