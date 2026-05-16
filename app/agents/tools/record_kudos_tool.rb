class RecordKudosTool
  def name
    "record_kudos"
  end

  def definition
    {
      name: name,
      description: "Record a kudos extracted from a Slack message. Call find_or_create_employee first to get giver_id and receiver_id, and find_or_create_category to get the category name.",
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
    kudos = Kudos.find_or_create_by(slack_message_id: input["slack_message_id"], receiver_id: input["receiver_id"]) do |k|
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
