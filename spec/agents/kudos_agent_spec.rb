require "rails_helper"

RSpec.describe KudosAgent do
  let(:agent) { described_class.new }

  # Helpers to build Anthropic-format API response bodies
  def end_turn_response
    {
      "id" => "msg_end",
      "type" => "message",
      "role" => "assistant",
      "model" => "claude-sonnet-4-6",
      "stop_reason" => "end_turn",
      "content" => [{ "type" => "text", "text" => "No kudos found." }],
      "usage" => { "input_tokens" => 100, "output_tokens" => 10 }
    }
  end

  def tool_use_response(tool_calls)
    {
      "id" => "msg_tools",
      "type" => "message",
      "role" => "assistant",
      "model" => "claude-sonnet-4-6",
      "stop_reason" => "tool_use",
      "content" => tool_calls,
      "usage" => { "input_tokens" => 200, "output_tokens" => 50 }
    }
  end

  let(:sample_messages) do
    [
      {
        "id" => "msg_029",
        "author" => "sarah.park",
        "channel" => "#engineering",
        "text" => "The flaky test was a race condition. Fixed in PR #418.",
        "timestamp" => "2026-05-12T16:00:00Z",
        "reactions" => [{ "emoji" => "taco", "user" => "tom.chen" }]
      }
    ]
  end

  describe "#process" do
    context "when the agent finds no kudos" do
      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 200,
            body: end_turn_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "makes one API call and creates no records" do
        agent.process(sample_messages)
        expect(Kudos.count).to eq(0)
        expect(a_request(:post, "https://api.anthropic.com/v1/messages")).to have_been_made.once
      end
    end

    context "when the agent finds a kudos" do
      let!(:giver)    { create(:employee, username: "sarah.park", first_name: "Sarah", last_name: "Park") }
      let!(:receiver) { create(:employee, username: "tom.chen",   first_name: "Tom",   last_name: "Chen") }

      before do
        # Call 1: agent finds employees to look up
        call_1 = tool_use_response([
          { "type" => "tool_use", "id" => "toolu_001", "name" => "find_or_create_employee", "input" => { "username" => "sarah.park" } },
          { "type" => "tool_use", "id" => "toolu_002", "name" => "find_or_create_employee", "input" => { "username" => "tom.chen" } }
        ])

        # Call 2: agent records the kudos using the IDs we just returned
        call_2 = tool_use_response([
          {
            "type" => "tool_use",
            "id" => "toolu_003",
            "name" => "record_kudos",
            "input" => {
              "giver_id"         => giver.id,
              "receiver_id"      => receiver.id,
              "reason"           => "Fixed race condition",
              "category"         => "Technical Excellence",
              "original_message" => "The flaky test was a race condition.",
              "reactions_from"   => ["tom.chen"],
              "slack_message_id" => "msg_029",
              "slack_channel"    => "#engineering",
              "slack_timestamp"  => "2026-05-12T16:00:00Z"
            }
          }
        ])

        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            { status: 200, body: call_1.to_json, headers: { "Content-Type" => "application/json" } },
            { status: 200, body: call_2.to_json, headers: { "Content-Type" => "application/json" } },
            { status: 200, body: end_turn_response.to_json, headers: { "Content-Type" => "application/json" } }
          )
      end

      it "creates the kudos record" do
        agent.process(sample_messages)
        expect(Kudos.count).to eq(1)
        kudos = Kudos.last
        expect(kudos.reason).to eq("Fixed race condition")
        expect(kudos.giver).to eq(giver)
        expect(kudos.receiver).to eq(receiver)
      end

      it "makes three API calls (two tool-use rounds + end_turn)" do
        agent.process(sample_messages)
        expect(a_request(:post, "https://api.anthropic.com/v1/messages")).to have_been_made.times(3)
      end
    end
  end
end
