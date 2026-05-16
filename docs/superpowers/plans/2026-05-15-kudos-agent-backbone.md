# Kudos Agent — Backbone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Rails 8 app that ingests Slack messages via Zapier webhook or manual file upload, uses a Claude-powered agent to extract kudos, and stores them in PostgreSQL for operator review.

**Architecture:** `KudosAgent` sends message batches to Claude's tool_use API in a loop — executing `find_or_create_employee` and `record_kudos` tool calls until `stop_reason == "end_turn"`. `WebhooksController` (single message from Zapier) and `UploadsController` (JSON file from operator) both enqueue `KudosExtractionJob` immediately and return 200. Deduplication is enforced by a unique index on `kudos.slack_message_id`.

**Tech Stack:** Ruby on Rails 8, PostgreSQL, solid_queue, `anthropic` gem (Ruby SDK), RSpec, FactoryBot, WebMock, shoulda-matchers

---

## File Map

**Created:**
- `app/agents/kudos_agent.rb` — Claude API agentic loop + tool dispatch
- `app/agents/tools/find_or_create_employee_tool.rb` — upsert employee by username
- `app/agents/tools/record_kudos_tool.rb` — upsert kudos by slack_message_id
- `app/jobs/kudos_extraction_job.rb` — enqueues agent for a message batch
- `app/jobs/scheduled_scan_job.rb` — empty boilerplate
- `app/controllers/webhooks_controller.rb` — POST /webhooks/slack
- `app/controllers/uploads_controller.rb` — POST /uploads/slack
- `app/models/employee.rb` — validations
- `app/models/kudos.rb` — associations, validations, default status
- `db/migrate/*_create_employees.rb`
- `db/migrate/*_create_kudos.rb`
- `spec/agents/kudos_agent_spec.rb`
- `spec/agents/tools/find_or_create_employee_tool_spec.rb`
- `spec/agents/tools/record_kudos_tool_spec.rb`
- `spec/jobs/kudos_extraction_job_spec.rb`
- `spec/requests/webhooks_spec.rb`
- `spec/requests/uploads_spec.rb`
- `spec/models/employee_spec.rb`
- `spec/models/kudos_spec.rb`
- `spec/factories/employees.rb`
- `spec/factories/kudos.rb`

**Modified:**
- `Gemfile` — add anthropic, rspec-rails, factory_bot_rails, webmock, shoulda-matchers
- `config/routes.rb` — add webhook + upload routes
- `config/environments/test.rb` — set queue adapter to :test

---

## Task 1: Bootstrap Rails App

**Files:**
- Modify: `Gemfile`
- Create: `spec/rails_helper.rb`, `spec/spec_helper.rb`, `.env.example`
- Modify: `config/database.yml`, `config/environments/test.rb`

- [ ] **Step 1: Scaffold Rails app in the current directory**

```bash
rails new . --database=postgresql --skip-git
```

Accept all overwrite prompts with `Y`. Rails 8 will scaffold the app, add solid_queue, and run `bundle install`.

Expected: ends with `Bundle complete!`

- [ ] **Step 2: Add gems to Gemfile**

Open `Gemfile`. After the line `gem "rails"`, add:

```ruby
gem "anthropic"
```

Inside the `group :development, :test do` block (create it if it doesn't exist), add:

```ruby
group :development, :test do
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "webmock"
  gem "shoulda-matchers"
end
```

- [ ] **Step 3: Install gems**

```bash
bundle install
```

Expected: `Bundle complete!`

- [ ] **Step 4: Install RSpec**

```bash
bundle exec rails generate rspec:install
```

Expected: Creates `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`

- [ ] **Step 5: Configure spec/rails_helper.rb**

Open `spec/rails_helper.rb`. Add the following near the top after `require "rspec/rails"`:

```ruby
require "webmock/rspec"
require "factory_bot_rails"
```

Add inside the `RSpec.configure do |config|` block:

```ruby
  config.include FactoryBot::Syntax::Methods

  WebMock.disable_net_connect!(allow_localhost: true)

  # Stub Anthropic API key so Anthropic::Client initializes without a real key
  config.before(:suite) do
    ENV["ANTHROPIC_API_KEY"] ||= "test_api_key"
    ENV["WEBHOOK_SECRET"] ||= "test_webhook_secret"
  end
```

Add after the `RSpec.configure` block (at the bottom of the file):

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

- [ ] **Step 6: Set test queue adapter**

Open `config/environments/test.rb`. Inside the `Rails.application.configure do` block, add:

```ruby
  config.active_job.queue_adapter = :test
```

- [ ] **Step 7: Configure database.yml**

Replace `config/database.yml` with:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: kudos_plane_development
  url: <%= ENV["DATABASE_URL"] %>

test:
  <<: *default
  database: kudos_plane_test

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

- [ ] **Step 8: Create database**

```bash
bundle exec rails db:create
```

Expected: `Created database 'kudos_plane_development'` and `Created database 'kudos_plane_test'`

- [ ] **Step 9: Install solid_queue migrations**

```bash
bundle exec rails solid_queue:install
bundle exec rails db:migrate db:test:prepare
```

Expected: Solid Queue migration runs successfully.

- [ ] **Step 10: Create .env.example**

Create `.env.example` in the project root:

```bash
# Copy to .env and fill in values. Never commit .env.
ANTHROPIC_API_KEY=sk-ant-...
WEBHOOK_SECRET=replace_with_random_secret
KUDOS_BATCH_SIZE=50
DATABASE_URL=postgresql://localhost/kudos_plane_development
```

- [ ] **Step 11: Verify RSpec boots**

```bash
bundle exec rspec
```

Expected: `0 examples, 0 failures`

- [ ] **Step 12: Commit**

```bash
git add .
git commit -m "chore: bootstrap Rails 8 app with PostgreSQL, solid_queue, and RSpec"
```

---

## Task 2: Employee Migration and Model

**Files:**
- Create: `db/migrate/*_create_employees.rb`
- Create: `app/models/employee.rb`
- Create: `spec/models/employee_spec.rb`
- Create: `spec/factories/employees.rb`

- [ ] **Step 1: Generate migration**

```bash
bundle exec rails generate migration CreateEmployees
```

- [ ] **Step 2: Write the migration**

Open the generated file at `db/migrate/YYYYMMDDHHMMSS_create_employees.rb` and replace its contents:

```ruby
class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :username,   null: false

      t.timestamps
    end

    add_index :employees, :username, unique: true
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/employee_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Employee, type: :model do
  subject(:employee) { build(:employee) }

  it { is_expected.to validate_presence_of(:first_name) }
  it { is_expected.to validate_presence_of(:last_name) }
  it { is_expected.to validate_presence_of(:username) }

  it "rejects duplicate usernames" do
    create(:employee, username: "alice.smith")
    dup = build(:employee, username: "alice.smith")
    expect(dup).not_to be_valid
    expect(dup.errors[:username]).to include("has already been taken")
  end
end
```

- [ ] **Step 4: Run spec to verify it fails**

```bash
bundle exec rspec spec/models/employee_spec.rb
```

Expected: `4 examples, 4 failures` (Employee class not found)

- [ ] **Step 5: Create the factory**

Create `spec/factories/employees.rb`:

```ruby
FactoryBot.define do
  factory :employee do
    sequence(:username) { |n| "user.#{n}" }
    first_name { "User" }
    last_name  { "One" }
  end
end
```

- [ ] **Step 6: Run migration**

```bash
bundle exec rails db:migrate db:test:prepare
```

Expected: `CreateEmployees: migrated`

- [ ] **Step 7: Write the Employee model**

Create `app/models/employee.rb`:

```ruby
class Employee < ApplicationRecord
  validates :first_name, presence: true
  validates :last_name,  presence: true
  validates :username,   presence: true, uniqueness: true
end
```

- [ ] **Step 8: Run spec to verify it passes**

```bash
bundle exec rspec spec/models/employee_spec.rb
```

Expected: `4 examples, 0 failures`

- [ ] **Step 9: Commit**

```bash
git add db/migrate app/models/employee.rb spec/models/employee_spec.rb spec/factories/employees.rb
git commit -m "feat: add Employee model and migration"
```

---

## Task 3: Kudos Migration and Model

**Files:**
- Create: `db/migrate/*_create_kudos.rb`
- Create: `app/models/kudos.rb`
- Create: `spec/models/kudos_spec.rb`
- Create: `spec/factories/kudos.rb`

- [ ] **Step 1: Generate migration**

```bash
bundle exec rails generate migration CreateKudos
```

- [ ] **Step 2: Write the migration**

Open the generated file and replace its contents:

```ruby
class CreateKudos < ActiveRecord::Migration[8.0]
  def change
    create_table :kudos do |t|
      t.references :giver,    null: false, foreign_key: { to_table: :employees }
      t.references :receiver, null: false, foreign_key: { to_table: :employees }
      t.string  :reactions_from, array: true, default: []
      t.text    :reason
      t.string  :category
      t.text    :original_message
      t.string  :slack_message_id, null: false
      t.string  :slack_channel
      t.datetime :slack_timestamp
      t.string  :status, null: false, default: "pending_review"

      t.timestamps
    end

    add_index :kudos, :slack_message_id, unique: true
    add_index :kudos, :status
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/kudos_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Kudos, type: :model do
  subject(:kudos) { build(:kudos) }

  it { is_expected.to belong_to(:giver).class_name("Employee") }
  it { is_expected.to belong_to(:receiver).class_name("Employee") }
  it { is_expected.to validate_presence_of(:slack_message_id) }

  it "rejects duplicate slack_message_id" do
    create(:kudos, slack_message_id: "msg_001")
    dup = build(:kudos, slack_message_id: "msg_001")
    expect(dup).not_to be_valid
    expect(dup.errors[:slack_message_id]).to include("has already been taken")
  end

  it "rejects invalid status" do
    kudos.status = "nonsense"
    expect(kudos).not_to be_valid
  end

  it "defaults status to pending_review" do
    k = build(:kudos, status: nil)
    k.valid?
    expect(k.status).to eq("pending_review")
  end
end
```

- [ ] **Step 4: Run spec to verify it fails**

```bash
bundle exec rspec spec/models/kudos_spec.rb
```

Expected: `6 examples, 6 failures`

- [ ] **Step 5: Create the factory**

Create `spec/factories/kudos.rb`:

```ruby
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
```

- [ ] **Step 6: Run migration**

```bash
bundle exec rails db:migrate db:test:prepare
```

Expected: `CreateKudos: migrated`

- [ ] **Step 7: Write the Kudos model**

Create `app/models/kudos.rb`:

```ruby
class Kudos < ApplicationRecord
  belongs_to :giver,    class_name: "Employee"
  belongs_to :receiver, class_name: "Employee"

  STATUSES = %w[pending_review approved rejected].freeze

  validates :slack_message_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_default_status, if: -> { status.nil? }

  private

  def set_default_status
    self.status = "pending_review"
  end
end
```

- [ ] **Step 8: Run spec to verify it passes**

```bash
bundle exec rspec spec/models/kudos_spec.rb
```

Expected: `6 examples, 0 failures`

- [ ] **Step 9: Commit**

```bash
git add db/migrate app/models/kudos.rb spec/models/kudos_spec.rb spec/factories/kudos.rb
git commit -m "feat: add Kudos model and migration"
```

---

## Task 4: FindOrCreateEmployeeTool

**Files:**
- Create: `app/agents/tools/find_or_create_employee_tool.rb`
- Create: `spec/agents/tools/find_or_create_employee_tool_spec.rb`

- [ ] **Step 1: Create the directories**

```bash
mkdir -p app/agents/tools spec/agents/tools
```

- [ ] **Step 2: Write the failing spec**

Create `spec/agents/tools/find_or_create_employee_tool_spec.rb`:

```ruby
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
```

- [ ] **Step 3: Run spec to verify it fails**

```bash
bundle exec rspec spec/agents/tools/find_or_create_employee_tool_spec.rb
```

Expected: `5 examples, 5 failures` (class not found)

- [ ] **Step 4: Write the tool**

Create `app/agents/tools/find_or_create_employee_tool.rb`:

```ruby
class FindOrCreateEmployeeTool
  def name
    "find_or_create_employee"
  end

  def definition
    {
      name: name,
      description: "Find or create an employee record by their Slack username.",
      input_schema: {
        type: "object",
        properties: {
          username: {
            type: "string",
            description: "The Slack username, e.g. 'sarah.park'"
          }
        },
        required: ["username"]
      }
    }
  end

  def call(input)
    username = input["username"]
    parts = username.split(".")
    first_name = parts[0]&.capitalize || username
    last_name  = parts[1..]&.map(&:capitalize)&.join(" ") || ""

    employee = Employee.find_or_create_by(username: username) do |e|
      e.first_name = first_name
      e.last_name  = last_name
    end

    { id: employee.id }
  end
end
```

- [ ] **Step 5: Run spec to verify it passes**

```bash
bundle exec rspec spec/agents/tools/find_or_create_employee_tool_spec.rb
```

Expected: `5 examples, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add app/agents/tools/find_or_create_employee_tool.rb spec/agents/tools/find_or_create_employee_tool_spec.rb
git commit -m "feat: add FindOrCreateEmployeeTool"
```

---

## Task 5: RecordKudosTool

**Files:**
- Create: `app/agents/tools/record_kudos_tool.rb`
- Create: `spec/agents/tools/record_kudos_tool_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/agents/tools/record_kudos_tool_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe RecordKudosTool do
  subject(:tool) { described_class.new }

  let(:giver)    { create(:employee, username: "sarah.park") }
  let(:receiver) { create(:employee, username: "tom.chen") }

  let(:valid_input) do
    {
      "giver_id"         => giver.id,
      "receiver_id"      => receiver.id,
      "reason"           => "Fixed the race condition in auth",
      "category"         => "Technical Excellence",
      "original_message" => "The flaky test in the auth suite was a race condition.",
      "reactions_from"   => ["tom.chen"],
      "slack_message_id" => "msg_029",
      "slack_channel"    => "#engineering",
      "slack_timestamp"  => "2026-05-12T16:00:00Z"
    }
  end

  describe "#name" do
    it { expect(tool.name).to eq("record_kudos") }
  end

  describe "#definition" do
    it "requires giver_id, receiver_id, reason, slack_message_id, slack_channel, slack_timestamp" do
      required = tool.definition[:input_schema][:required]
      expect(required).to include("giver_id", "receiver_id", "reason", "slack_message_id", "slack_channel", "slack_timestamp")
    end
  end

  describe "#call" do
    context "with a new slack_message_id" do
      it "creates a kudos record and returns created: true" do
        result = tool.call(valid_input)
        expect(result[:created]).to be true
        expect(Kudos.count).to eq(1)

        kudos = Kudos.last
        expect(kudos.giver).to eq(giver)
        expect(kudos.receiver).to eq(receiver)
        expect(kudos.reason).to eq("Fixed the race condition in auth")
        expect(kudos.category).to eq("Technical Excellence")
        expect(kudos.reactions_from).to eq(["tom.chen"])
        expect(kudos.slack_message_id).to eq("msg_029")
        expect(kudos.slack_channel).to eq("#engineering")
        expect(kudos.status).to eq("pending_review")
      end
    end

    context "with a duplicate slack_message_id" do
      before { tool.call(valid_input) }

      it "does not create a duplicate and returns created: false" do
        result = tool.call(valid_input)
        expect(result[:created]).to be false
        expect(Kudos.count).to eq(1)
      end
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/agents/tools/record_kudos_tool_spec.rb
```

Expected: `4 examples, 4 failures`

- [ ] **Step 3: Write the tool**

Create `app/agents/tools/record_kudos_tool.rb`:

```ruby
class RecordKudosTool
  def name
    "record_kudos"
  end

  def definition
    {
      name: name,
      description: "Record a kudos extracted from a Slack message. Call find_or_create_employee first to get giver_id and receiver_id.",
      input_schema: {
        type: "object",
        properties: {
          giver_id:         { type: "integer", description: "Employee ID of the kudos giver" },
          receiver_id:      { type: "integer", description: "Employee ID of the kudos receiver" },
          reason:           { type: "string",  description: "Why the kudos is being given" },
          category:         { type: "string",  description: "Category label, e.g. 'Teamwork', 'Technical Excellence'" },
          original_message: { type: "string",  description: "The raw Slack message text" },
          reactions_from:   { type: "array", items: { type: "string" }, description: "Usernames of taco reactors" },
          slack_message_id: { type: "string",  description: "Unique Slack message ID for deduplication" },
          slack_channel:    { type: "string",  description: "Slack channel name, e.g. '#engineering'" },
          slack_timestamp:  { type: "string",  description: "ISO8601 timestamp of the original message" }
        },
        required: %w[giver_id receiver_id reason slack_message_id slack_channel slack_timestamp]
      }
    }
  end

  def call(input)
    kudos = Kudos.find_or_create_by(slack_message_id: input["slack_message_id"]) do |k|
      k.giver_id         = input["giver_id"]
      k.receiver_id      = input["receiver_id"]
      k.reason           = input["reason"]
      k.category         = input["category"]
      k.original_message = input["original_message"]
      k.reactions_from   = Array(input["reactions_from"])
      k.slack_channel    = input["slack_channel"]
      k.slack_timestamp  = input["slack_timestamp"]
    end

    { created: kudos.previously_new_record? }
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/agents/tools/record_kudos_tool_spec.rb
```

Expected: `4 examples, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add app/agents/tools/record_kudos_tool.rb spec/agents/tools/record_kudos_tool_spec.rb
git commit -m "feat: add RecordKudosTool"
```

---

## Task 6: KudosAgent

**Files:**
- Create: `app/agents/kudos_agent.rb`
- Create: `spec/agents/kudos_agent_spec.rb`

**How the agent loop works:**
1. Build a `user` message containing all formatted messages in the batch.
2. POST to Claude API with `tools:` definitions and the messages array.
3. If `stop_reason == "tool_use"`: execute each tool call, append the assistant's content + tool results to messages, repeat.
4. If `stop_reason == "end_turn"`: return. The agent found everything it could in this batch.

- [ ] **Step 1: Write the failing spec**

Create `spec/agents/kudos_agent_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe KudosAgent do
  let(:agent) { described_class.new }

  # Helpers to build Anthropic-format API response bodies
  def end_turn_response
    {
      "id" => "msg_end",
      "type" => "message",
      "role" => "assistant",
      "model" => "claude-sonnet-4-6",
      "stop_reason" => "end_turn",
      "content" => [{ "type" => "text", "text" => "No kudos found." }],
      "usage" => { "input_tokens" => 100, "output_tokens" => 10 }
    }
  end

  def tool_use_response(tool_calls)
    {
      "id" => "msg_tools",
      "type" => "message",
      "role" => "assistant",
      "model" => "claude-sonnet-4-6",
      "stop_reason" => "tool_use",
      "content" => tool_calls,
      "usage" => { "input_tokens" => 200, "output_tokens" => 50 }
    }
  end

  let(:sample_messages) do
    [
      {
        "id" => "msg_029",
        "author" => "sarah.park",
        "channel" => "#engineering",
        "text" => "The flaky test was a race condition. Fixed in PR #418.",
        "timestamp" => "2026-05-12T16:00:00Z",
        "reactions" => [{ "emoji" => "taco", "user" => "tom.chen" }]
      }
    ]
  end

  describe "#process" do
    context "when the agent finds no kudos" do
      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 200,
            body: end_turn_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "makes one API call and creates no records" do
        agent.process(sample_messages)
        expect(Kudos.count).to eq(0)
        expect(a_request(:post, "https://api.anthropic.com/v1/messages")).to have_been_made.once
      end
    end

    context "when the agent finds a kudos" do
      let!(:giver)    { create(:employee, username: "sarah.park", first_name: "Sarah", last_name: "Park") }
      let!(:receiver) { create(:employee, username: "tom.chen",   first_name: "Tom",   last_name: "Chen") }

      before do
        # Call 1: agent finds employees to look up
        call_1 = tool_use_response([
          { "type" => "tool_use", "id" => "toolu_001", "name" => "find_or_create_employee", "input" => { "username" => "sarah.park" } },
          { "type" => "tool_use", "id" => "toolu_002", "name" => "find_or_create_employee", "input" => { "username" => "tom.chen" } }
        ])

        # Call 2: agent records the kudos using the IDs we just returned
        call_2 = tool_use_response([
          {
            "type" => "tool_use",
            "id" => "toolu_003",
            "name" => "record_kudos",
            "input" => {
              "giver_id"         => giver.id,
              "receiver_id"      => receiver.id,
              "reason"           => "Fixed race condition",
              "category"         => "Technical Excellence",
              "original_message" => "The flaky test was a race condition.",
              "reactions_from"   => ["tom.chen"],
              "slack_message_id" => "msg_029",
              "slack_channel"    => "#engineering",
              "slack_timestamp"  => "2026-05-12T16:00:00Z"
            }
          }
        ])

        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            { status: 200, body: call_1.to_json, headers: { "Content-Type" => "application/json" } },
            { status: 200, body: call_2.to_json, headers: { "Content-Type" => "application/json" } },
            { status: 200, body: end_turn_response.to_json, headers: { "Content-Type" => "application/json" } }
          )
      end

      it "creates the kudos record" do
        agent.process(sample_messages)
        expect(Kudos.count).to eq(1)
        kudos = Kudos.last
        expect(kudos.reason).to eq("Fixed race condition")
        expect(kudos.giver).to eq(giver)
        expect(kudos.receiver).to eq(receiver)
      end

      it "makes three API calls (two tool-use rounds + end_turn)" do
        agent.process(sample_messages)
        expect(a_request(:post, "https://api.anthropic.com/v1/messages")).to have_been_made.times(3)
      end
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/agents/kudos_agent_spec.rb
```

Expected: `3 examples, 3 failures` (KudosAgent class not found)

- [ ] **Step 3: Write KudosAgent**

Create `app/agents/kudos_agent.rb`:

```ruby
class KudosAgent
  MODEL = "claude-sonnet-4-6"
  MAX_TOKENS = 4096

  def initialize
    @client = Anthropic::Client.new
    @tools  = [
      FindOrCreateEmployeeTool.new,
      RecordKudosTool.new
    ]
  end

  def process(messages)
    api_messages = [{ role: "user", content: format_batch(messages) }]

    loop do
      response = @client.messages(
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: system_prompt,
        tools: tool_definitions,
        messages: api_messages
      )

      break if response.stop_reason != "tool_use"

      tool_results = response.content
        .select { |block| block.type == "tool_use" }
        .map { |block| execute_tool(block) }

      api_messages << { role: "assistant", content: serialize_content(response.content) }
      api_messages << { role: "user", content: tool_results }
    end
  end

  private

  def system_prompt
    ENV.fetch("KUDOS_SYSTEM_PROMPT",
      "You are a kudos extraction agent. Given a batch of Slack messages, " \
      "identify messages where one person praises or thanks another person. " \
      "For each kudos found: first call find_or_create_employee for the giver and receiver, " \
      "then call record_kudos with their IDs. " \
      "If a message contains no kudos, skip it. Do not invent kudos."
    )
  end

  def tool_definitions
    @tools.map(&:definition)
  end

  def format_batch(messages)
    messages.map { |m| format_message(m) }.join("\n\n---\n\n")
  end

  def format_message(msg)
    reactions = msg["reactions"]
      &.map { |r| "#{r["emoji"]} from #{r["user"]}" }
      &.join(", ") || "none"

    "ID: #{msg["id"]}\n" \
    "Author: #{msg["author"]}\n" \
    "Channel: #{msg["channel"]}\n" \
    "Timestamp: #{msg["timestamp"]}\n" \
    "Reactions: #{reactions}\n" \
    "Text: #{msg["text"]}"
  end

  def execute_tool(block)
    tool = @tools.find { |t| t.name == block.name }
    result = tool.call(block.input.to_h)
    {
      type: "tool_result",
      tool_use_id: block.id,
      content: result.to_json
    }
  end

  def serialize_content(content_blocks)
    content_blocks.map do |block|
      case block.type
      when "tool_use"
        { type: "tool_use", id: block.id, name: block.name, input: block.input }
      when "text"
        { type: "text", text: block.text }
      end
    end.compact
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/agents/kudos_agent_spec.rb
```

Expected: `3 examples, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add app/agents/kudos_agent.rb spec/agents/kudos_agent_spec.rb
git commit -m "feat: add KudosAgent with Claude tool_use loop"
```

---

## Task 7: KudosExtractionJob

**Files:**
- Create: `app/jobs/kudos_extraction_job.rb`
- Create: `spec/jobs/kudos_extraction_job_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/jobs/kudos_extraction_job_spec.rb`:

```ruby
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
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/jobs/kudos_extraction_job_spec.rb
```

Expected: `1 example, 1 failure`

- [ ] **Step 3: Write the job**

Create `app/jobs/kudos_extraction_job.rb`:

```ruby
class KudosExtractionJob < ApplicationJob
  queue_as :default

  def perform(messages)
    KudosAgent.new.process(messages)
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/jobs/kudos_extraction_job_spec.rb
```

Expected: `1 example, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add app/jobs/kudos_extraction_job.rb spec/jobs/kudos_extraction_job_spec.rb
git commit -m "feat: add KudosExtractionJob"
```

---

## Task 8: WebhooksController

**Files:**
- Create: `app/controllers/webhooks_controller.rb`
- Create: `spec/requests/webhooks_spec.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/webhooks_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "POST /webhooks/slack", type: :request do
  let(:secret) { "test_webhook_secret" }
  let(:message) do
    {
      id: "msg_001",
      author: "alice.smith",
      channel: "#general",
      text: "Great work Bob!",
      timestamp: "2026-05-12T10:00:00Z",
      reactions: [{ emoji: "taco", user: "carol.jones" }]
    }
  end

  before { ENV["WEBHOOK_SECRET"] = secret }

  context "with a valid X-Webhook-Secret header" do
    it "returns 200 and enqueues KudosExtractionJob" do
      expect {
        post "/webhooks/slack",
          params: message,
          headers: { "X-Webhook-Secret" => secret },
          as: :json
      }.to have_enqueued_job(KudosExtractionJob)

      expect(response).to have_http_status(:ok)
    end

    it "enqueues the job with the parsed message wrapped in an array" do
      post "/webhooks/slack",
        params: message,
        headers: { "X-Webhook-Secret" => secret },
        as: :json

      expect(KudosExtractionJob).to have_been_enqueued
        .with(a_collection_containing_exactly(hash_including("id" => "msg_001", "author" => "alice.smith")))
    end
  end

  context "with an incorrect X-Webhook-Secret header" do
    it "returns 401 and does not enqueue a job" do
      expect {
        post "/webhooks/slack",
          params: message,
          headers: { "X-Webhook-Secret" => "wrong_secret" },
          as: :json
      }.not_to have_enqueued_job(KudosExtractionJob)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with no X-Webhook-Secret header" do
    it "returns 401" do
      post "/webhooks/slack", params: message, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/webhooks_spec.rb
```

Expected: `4 examples, 4 failures` (routing error)

- [ ] **Step 3: Add routes**

Open `config/routes.rb` and replace with:

```ruby
Rails.application.routes.draw do
  post "/webhooks/slack", to: "webhooks#slack"
  post "/uploads/slack",  to: "uploads#slack"
end
```

- [ ] **Step 4: Write WebhooksController**

Create `app/controllers/webhooks_controller.rb`:

```ruby
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_webhook

  def slack
    message = JSON.parse(request.raw_post)
    KudosExtractionJob.perform_later([message])
    head :ok
  end

  private

  def authenticate_webhook
    expected = ENV.fetch("WEBHOOK_SECRET")
    provided = request.headers["X-Webhook-Secret"].to_s
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, provided)
  end
end
```

- [ ] **Step 5: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/webhooks_spec.rb
```

Expected: `4 examples, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add app/controllers/webhooks_controller.rb config/routes.rb spec/requests/webhooks_spec.rb
git commit -m "feat: add WebhooksController with HMAC auth"
```

---

## Task 9: UploadsController

**Files:**
- Create: `app/controllers/uploads_controller.rb`
- Create: `spec/requests/uploads_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/uploads_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "POST /uploads/slack", type: :request do
  def json_file(messages)
    Rack::Test::UploadedFile.new(
      StringIO.new(messages.to_json),
      "application/json",
      original_filename: "export.json"
    )
  end

  let(:messages) do
    5.times.map do |i|
      { "id" => "msg_#{i}", "author" => "user.#{i}", "channel" => "#general",
        "text" => "message #{i}", "timestamp" => "2026-05-12T10:00:00Z", "reactions" => [] }
    end
  end

  context "with a small file (fewer than batch size messages)" do
    it "returns 200 and enqueues one job" do
      expect {
        post "/uploads/slack", params: { file: json_file(messages) }
      }.to have_enqueued_job(KudosExtractionJob).exactly(:once)

      expect(response).to have_http_status(:ok)
    end
  end

  context "with a file that exceeds batch size" do
    before { stub_const("ENV", ENV.to_h.merge("KUDOS_BATCH_SIZE" => "2")) }

    it "enqueues one job per batch" do
      expect {
        post "/uploads/slack", params: { file: json_file(messages) }
      }.to have_enqueued_job(KudosExtractionJob).exactly(3).times
    end
  end

  context "with no file param" do
    it "returns 400" do
      post "/uploads/slack"
      expect(response).to have_http_status(:bad_request)
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/uploads_spec.rb
```

Expected: `3 examples, 3 failures`

- [ ] **Step 3: Write UploadsController**

Create `app/controllers/uploads_controller.rb`:

```ruby
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
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/uploads_spec.rb
```

Expected: `3 examples, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add app/controllers/uploads_controller.rb spec/requests/uploads_spec.rb
git commit -m "feat: add UploadsController for manual JSON file ingestion"
```

---

## Task 10: ScheduledScanJob Boilerplate

**Files:**
- Create: `app/jobs/scheduled_scan_job.rb`

- [ ] **Step 1: Write the boilerplate job**

Create `app/jobs/scheduled_scan_job.rb`:

```ruby
class ScheduledScanJob < ApplicationJob
  queue_as :default

  def perform
    # future: scan Slack history day-by-day via Zapier or Slack API
    # and enqueue KudosExtractionJob for each message in the scan window
  end
end
```

- [ ] **Step 2: Run the full test suite**

```bash
bundle exec rspec
```

Expected: All examples pass, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add app/jobs/scheduled_scan_job.rb
git commit -m "chore: add ScheduledScanJob boilerplate"
```

---

## Self-Review Against Spec

### Spec coverage check

| Spec requirement | Implemented in |
|---|---|
| PostgreSQL schema: employees (id, first_name, last_name, username, timestamps) | Task 2 |
| PostgreSQL schema: kudos (all columns, string[] reactions_from) | Task 3 |
| Unique index on kudos.slack_message_id | Task 3 migration |
| Index on kudos.status | Task 3 migration |
| KudosAgent — stateless, batch input, single API call per loop | Task 6 |
| Tool: find_or_create_employee — splits username, upserts employee | Task 4 |
| Tool: record_kudos — upserts kudos by slack_message_id | Task 5 |
| System prompt injectable via env var | Task 6 (KUDOS_SYSTEM_PROMPT) |
| Pre-filter comment for future taco-only mode | Not in plan (spec says leave commented in code — add inline after scaffolding) |
| Webhook trigger — POST /webhooks/slack, single message, X-Webhook-Secret auth | Task 8 |
| File upload trigger — POST /uploads/slack, batches by KUDOS_BATCH_SIZE | Task 9 |
| Scheduled scan — boilerplate only | Task 10 |
| Deduplication via unique index | Task 3 migration + RecordKudosTool find_or_create_by |
| Default kudos status: pending_review | Task 3 model |
| solid_queue (no Redis) | Task 1 |

**One gap found:** The taco pre-filter comment from the spec belongs in `app/agents/kudos_agent.rb`. Add it to the `process` method in Task 6 after the agent loop but before the batch send:

```ruby
# FUTURE: pre-filter to taco-reacted messages only to reduce token costs.
# Uncomment once token usage has been measured in production:
# messages = messages.select { |m| m["reactions"]&.any? { |r| r["emoji"] == "taco" } }
```

Add this comment inside `process`, just before `api_messages = [...]`.

### Placeholder scan

None found — all code steps contain complete, runnable code.

### Type consistency check

- `FindOrCreateEmployeeTool#call(input)` — `input` is a hash with string keys ✓
- `RecordKudosTool#call(input)` — same ✓
- `KudosAgent` calls `block.input.to_h` before passing to `tool.call` — ensures string-keyed hash ✓
- `KudosExtractionJob#perform(messages)` passes `messages` array to `KudosAgent#process(messages)` ✓
- `WebhooksController` wraps single message in `[message]` array for `perform_later` ✓
- `UploadsController` slices messages into batches and passes each to `perform_later` ✓
