FactoryBot.define do
  factory :kudos do
    association :giver,    factory: :employee
    association :receiver, factory: :employee
    sequence(:slack_message_id) { |n| "msg_#{n.to_s.rjust(4, "0")}" }
    reason           { "Great work on the project" }
    category         { "Teamwork" }
    original_message { "Thanks for everything!" }
    reactions_from   { ["some.user"] }
    slack_channel    { "#general" }
    slack_timestamp  { 1.day.ago }
    status           { "pending_review" }
  end
end
