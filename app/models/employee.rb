class Employee < ApplicationRecord
  validates :first_name, presence: true
  validates :username,   presence: true, uniqueness: true
end
