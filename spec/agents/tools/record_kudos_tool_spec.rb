require "rails_helper"

RSpec.describe RecordKudosTool do
  subject(:tool) { described_class.new }

  let(:giver)    { create(:employee, username: "sarah.park") }
  let(:receiver) { create(:employee, username: "tom.chen") }

  let(:valid_input) do
    {
      "giver_id"         => giver.id,
      "receiver_id"      => receiver.id,
      "reason"           => "Fixed the race condition in auth",
      "category"         => "Technical Excellence",
      "original_message" => "The flaky test in the auth suite was a race condition.",
      "reactions_from"   => ["tom.chen"],
      "slack_message_id" => "msg_029",
      "slack_channel"    => "#engineering",
      "slack_timestamp"  => "2026-05-12T16:00:00Z"
    }
  end

  describe "#name" do
    it { expect(tool.name).to eq("record_kudos") }
  end

  describe "#definition" do
    it "requires giver_id, receiver_id, reason, slack_message_id, slack_channel, slack_timestamp" do
      required = tool.definition[:input_schema][:required]
      expect(required).to include("giver_id", "receiver_id", "reason", "slack_message_id", "slack_channel", "slack_timestamp")
    end
  end

  describe "#call" do
    context "with a new slack_message_id" do
      it "creates a kudos record and returns created: true" do
        result = tool.call(valid_input)
        expect(result[:created]).to be true
        expect(Kudos.count).to eq(1)

        kudos = Kudos.last
        expect(kudos.giver).to eq(giver)
        expect(kudos.receiver).to eq(receiver)
        expect(kudos.reason).to eq("Fixed the race condition in auth")
        expect(kudos.category).to eq("Technical Excellence")
        expect(kudos.reactions_from).to eq(["tom.chen"])
        expect(kudos.slack_message_id).to eq("msg_029")
        expect(kudos.slack_channel).to eq("#engineering")
        expect(kudos.status).to eq("pending_review")
      end
    end

    context "with the same slack_message_id and same receiver" do
      before { tool.call(valid_input) }

      it "does not create a duplicate and returns created: false" do
        result = tool.call(valid_input)
        expect(result[:created]).to be false
        expect(Kudos.count).to eq(1)
      end
    end

    context "with the same slack_message_id but a different receiver" do
      let(:other_receiver) { create(:employee, username: "bob.jones") }

      it "creates a second kudos and returns created: true" do
        tool.call(valid_input)
        result = tool.call(valid_input.merge("receiver_id" => other_receiver.id))
        expect(result[:created]).to be true
        expect(Kudos.count).to eq(2)
      end
    end
  end
end
