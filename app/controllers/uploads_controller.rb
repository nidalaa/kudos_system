class UploadsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def slack
    return head :bad_request unless params[:file].present?

    messages   = JSON.parse(params[:file].read)
    batch_size = ENV.fetch("KUDOS_BATCH_SIZE", "50").to_i

    messages.each_slice(batch_size) do |batch|
      KudosExtractionJob.perform_later(batch)
    end

    head :ok
  end
end
