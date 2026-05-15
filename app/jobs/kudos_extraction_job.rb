class KudosExtractionJob < ApplicationJob
  queue_as :default

  def perform(messages)
    KudosAgent.new.process(messages)
  end
end
