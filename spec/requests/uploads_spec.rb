require "rails_helper"

RSpec.describe "POST /uploads/slack", type: :request do
  def json_file(messages)
    Rack::Test::UploadedFile.new(
      StringIO.new(messages.to_json),
      "application/json",
      original_filename: "export.json"
    )
  end

  let(:messages) do
    5.times.map do |i|
      { "id" => "msg_#{i}", "author" => "user.#{i}", "channel" => "#general",
        "text" => "message #{i}", "timestamp" => "2026-05-12T10:00:00Z", "reactions" => [] }
    end
  end

  context "with a small file (fewer than batch size messages)" do
    it "returns 200 and enqueues one job" do
      expect {
        post "/uploads/slack", params: { file: json_file(messages) }
      }.to have_enqueued_job(KudosExtractionJob).exactly(:once)

      expect(response).to have_http_status(:ok)
    end
  end

  context "with a file that exceeds batch size" do
    before { stub_const("ENV", ENV.to_h.merge("KUDOS_BATCH_SIZE" => "2")) }

    it "enqueues one job per batch" do
      expect {
        post "/uploads/slack", params: { file: json_file(messages) }
      }.to have_enqueued_job(KudosExtractionJob).exactly(3).times
    end
  end

  context "with no file param" do
    it "returns 400" do
      post "/uploads/slack"
      expect(response).to have_http_status(:bad_request)
    end
  end
end
