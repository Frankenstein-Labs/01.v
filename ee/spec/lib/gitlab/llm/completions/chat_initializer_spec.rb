# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Completions::Chat, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  it "tests intialization without the optional options parameter" do
    question = "a dummy question"
    message = ::Gitlab::Llm::ChatMessage.new(
      'user' => user,
      'content' => question,
      'role' => 'user',
      'context' => build(:ai_chat_message, user: user, content: question, resource: {})
    )
    expect { described_class.new(message, ::Gitlab::Llm::Completions::Chat) }.not_to raise_error
  end
end
