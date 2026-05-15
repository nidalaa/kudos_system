require "rails_helper"

RSpec.describe FindOrCreateEmployeeTool do
  subject(:tool) { described_class.new }

  describe "#name" do
    it { expect(tool.name).to eq("find_or_create_employee") }
  end

  describe "#definition" do
    it "has the correct structure" do
      defn = tool.definition
      expect(defn[:name]).to eq("find_or_create_employee")
      expect(defn[:input_schema][:required]).to include("username")
    end
  end

  describe "#call" do
    context "when employee does not exist" do
      it "creates a new employee and returns their id" do
        result = tool.call("username" => "sarah.park")

        expect(result[:id]).to be_present
        employee = Employee.find(result[:id])
        expect(employee.first_name).to eq("Sarah")
        expect(employee.last_name).to eq("Park")
        expect(employee.username).to eq("sarah.park")
      end
    end

    context "when employee already exists" do
      let!(:existing) { create(:employee, username: "alice.smith", first_name: "Alice", last_name: "Smith") }

      it "returns the existing employee id without creating a duplicate" do
        result = tool.call("username" => "alice.smith")
        expect(result[:id]).to eq(existing.id)
        expect(Employee.where(username: "alice.smith").count).to eq(1)
      end
    end

    context "with a single-part username" do
      it "sets last_name to empty string" do
        result = tool.call("username" => "mononym")
        employee = Employee.find(result[:id])
        expect(employee.first_name).to eq("Mononym")
        expect(employee.last_name).to eq("")
      end
    end
  end
end
