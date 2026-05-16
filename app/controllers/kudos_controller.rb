class KudosController < ApplicationController
  def index
    @categories = Category.all
    @kudos = Kudos.includes(:giver, :receiver).order(created_at: :desc).map do |k|
      {
        id:              k.id,
        giver:           "#{k.giver.first_name} #{k.giver.last_name}",
        receiver:        "#{k.receiver.first_name} #{k.receiver.last_name}",
        category:        k.category,
        reason:          k.reason,
        reactions_count: Array(k.reactions_from).size,
        slack_message_id: k.slack_message_id,
        channel:         k.slack_channel,
        date:            k.created_at.strftime("%b %d, %Y"),
        status:          k.status == "pending_review" ? "pending" : k.status
      }
    end
  end

  def destroy_all
    Kudos.delete_all
    redirect_to kudos_path
  end
end
