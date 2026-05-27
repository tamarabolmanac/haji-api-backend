class ClaudeService
  MODEL = "claude-sonnet-4-5"
  MAX_TOKENS = 1000

  def initialize
    @client = Anthropic::Client.new
    @messages = []
  end

  def add_user_message(text)
    @messages << { role: "user", content: text }
  end

  def add_assistant_message(text)
    @messages << { role: "assistant", content: text }
  end

  def chat(text)
    add_user_message(text)

    response = @client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: @messages
    )

    reply = response.content.first.text
    add_assistant_message(reply)
    reply
  end
end
