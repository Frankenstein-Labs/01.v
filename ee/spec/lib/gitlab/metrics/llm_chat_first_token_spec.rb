# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::LlmChatFirstToken, feature_category: :duo_chat do
  describe '#initialize_slis!' do
    it 'initializes SLIs for Llm Duo Chat' do
      expect(Gitlab::Metrics::Sli::Apdex).to receive(:initialize_sli).with(
        :llm_chat_first_token,
        [{ feature_category: :duo_chat, service_class: "Gitlab::Llm::Completions::Chat" }]
      )

      described_class.initialize_slis!
    end
  end
end
