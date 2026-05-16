class Kudos < ApplicationRecord
  belongs_to :giver,    class_name: "Employee"
  belongs_to :receiver, class_name: "Employee"

  STATUSES = %w[pending_review approved rejected].freeze

  validates :slack_message_id, presence: true, uniqueness: { scope: :receiver_id }
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_default_status, if: -> { status.nil? }

  private

  def set_default_status
    self.status = "pending_review"
  end
end
