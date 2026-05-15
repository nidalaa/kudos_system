require "rails_helper"

RSpec.describe Employee, type: :model do
  subject(:employee) { build(:employee) }

  it { is_expected.to validate_presence_of(:first_name) }
  it { is_expected.to validate_presence_of(:username) }

  it "rejects duplicate usernames" do
    create(:employee, username: "alice.smith")
    dup = build(:employee, username: "alice.smith")
    expect(dup).not_to be_valid
    expect(dup.errors[:username]).to include("has already been taken")
  end
end
