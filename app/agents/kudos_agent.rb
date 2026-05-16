class KudosAgent
  MODEL = "claude-sonnet-4-6"
  MAX_TOKENS = 4096

  def initialize
    @client = Anthropic::Client.new
    @tools  = [
      FindOrCreateEmployeeTool.new,
      FindOrCreateCategoryTool.new,
      RecordKudosTool.new
    ]
  end

  def process(messages)
    # FUTURE: pre-filter to taco-reacted messages only to reduce token costs.
    # Uncomment once token usage has been measured in production:
    # messages = messages.select { |m| m["reactions"]&.any? { |r| r["emoji"] == "taco" } }

    api_messages = [{ role: "user", content: format_batch(messages) }]

    loop do
      response = @client.messages.create(
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system_: system_prompt,
        tools: tool_definitions,
        messages: api_messages
      )

      break if response.stop_reason != :tool_use

      tool_results = response.content
        .select { |block| block.type == :tool_use }
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
    raise "Unknown tool requested by agent: #{block.name}" unless tool

    # block.input returns a hash with symbol keys; tools expect string keys
    result = tool.call(block.input.to_h.transform_keys(&:to_s))
    {
      type: "tool_result",
      tool_use_id: block.id,
      content: result.to_json
    }
  end

  def serialize_content(content_blocks)
    content_blocks.map do |block|
      case block.type
      when :tool_use
        { type: "tool_use", id: block.id, name: block.name, input: block.input }
      when :text
        { type: "text", text: block.text }
      else
        raise "Unexpected content block type from API: #{block.type}"
      end
    end
  end
end
