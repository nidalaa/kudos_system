require "rails_helper"

RSpec.describe "POST /webhooks/slack", type: :request do
  let(:secret) { "test_webhook_secret" }
  let(:message) do
    {
      id: "msg_001",
      author: "alice.smith",
      channel: "#general",
      text: "Great work Bob!",
      timestamp: "2026-05-12T10:00:00Z",
      reactions: [{ emoji: "taco", user: "carol.jones" }]
    }
  end

  before { ENV["WEBHOOK_SECRET"] = secret }

  context "with a valid X-Webhook-Secret header" do
    it "returns 200 and enqueues KudosExtractionJob" do
      expect {
        post "/webhooks/slack",
          params: message,
          headers: { "X-Webhook-Secret" => secret },
          as: :json
      }.to have_enqueued_job(KudosExtractionJob)

      expect(response).to have_http_status(:ok)
    end

    it "enqueues the job with the parsed message wrapped in an array" do
      post "/webhooks/slack",
        params: message,
        headers: { "X-Webhook-Secret" => secret },
        as: :json

      expect(KudosExtractionJob).to have_been_enqueued
        .with(a_collection_containing_exactly(hash_including("id" => "msg_001", "author" => "alice.smith")))
    end
  end

  context "with an incorrect X-Webhook-Secret header" do
    it "returns 401 and does not enqueue a job" do
      expect {
        post "/webhooks/slack",
          params: message,
          headers: { "X-Webhook-Secret" => "wrong_secret" },
          as: :json
      }.not_to have_enqueued_job(KudosExtractionJob)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with no X-Webhook-Secret header" do
    it "returns 401" do
      post "/webhooks/slack", params: message, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
