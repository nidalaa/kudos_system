require "rails_helper"

RSpec.describe KudosExtractionJob, type: :job do
  describe "#perform" do
    let(:messages) { [{ "id" => "msg_001", "author" => "alice.smith", "text" => "good work" }] }

    it "calls KudosAgent#process with the messages" do
      agent_double = instance_double(KudosAgent, process: nil)
      allow(KudosAgent).to receive(:new).and_return(agent_double)

      described_class.new.perform(messages)

      expect(agent_double).to have_received(:process).with(messages)
    end
  end
end
