class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_webhook

  def slack
    message = JSON.parse(request.raw_post)
    KudosExtractionJob.perform_later([message])
    head :ok
  end

  private

  def authenticate_webhook
    expected = ENV.fetch("WEBHOOK_SECRET")
    provided = request.headers["X-Webhook-Secret"].to_s
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, provided)
  end
end
