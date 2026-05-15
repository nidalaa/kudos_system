FactoryBot.define do
  factory :employee do
    sequence(:username) { |n| "user.#{n}" }
    first_name { "User" }
    last_name  { "One" }
  end
end
