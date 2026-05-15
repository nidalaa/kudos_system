class ScheduledScanJob < ApplicationJob
  queue_as :default

  def perform
    # future: scan Slack history day-by-day via Zapier or Slack API
    # and enqueue KudosExtractionJob for each message in the scan window
  end
end
