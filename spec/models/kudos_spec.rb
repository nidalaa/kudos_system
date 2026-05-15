require "rails_helper"

RSpec.describe Kudos, type: :model do
  subject(:kudos) { build(:kudos) }

  it { is_expected.to belong_to(:giver).class_name("Employee") }
  it { is_expected.to belong_to(:receiver).class_name("Employee") }
  it { is_expected.to validate_presence_of(:slack_message_id) }

  it "rejects duplicate slack_message_id" do
    create(:kudos, slack_message_id: "msg_001")
    dup = build(:kudos, slack_message_id: "msg_001")
    expect(dup).not_to be_valid
    expect(dup.errors[:slack_message_id]).to include("has already been taken")
  end

  it "rejects invalid status" do
    kudos.status = "nonsense"
    expect(kudos).not_to be_valid
  end

  it "defaults status to pending_review" do
    k = build(:kudos, status: nil)
    k.valid?
    expect(k.status).to eq("pending_review")
  end
end
