# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::SlackInteractions::DuoFeedbackModal, feature_category: :duo_agent_platform do
  describe '#build' do
    subject(:payload) { described_class.new(123).build }

    it 'builds a modal with the feedback callback_id and workflow in private_metadata' do
      expect(payload).to include(
        type: 'modal',
        callback_id: described_class::CALLBACK_ID,
        private_metadata: '123'
      )
    end

    it 'includes a required reason input with the expected options' do
      reason_block = payload[:blocks].find { |block| block[:block_id] == described_class::REASON_BLOCK_ID }

      expect(reason_block[:type]).to eq('input')
      expect(reason_block[:element][:type]).to eq('radio_buttons')
      expect(reason_block[:element][:action_id]).to eq(described_class::REASON_ACTION_ID)
      expect(reason_block[:element][:options].pluck(:value)).to eq(
        %w[incorrect did_not_follow_instructions incomplete other]
      )
    end

    it 'includes an optional multiline comment input' do
      comment_block = payload[:blocks].find { |block| block[:block_id] == described_class::COMMENT_BLOCK_ID }

      expect(comment_block[:optional]).to be(true)
      expect(comment_block[:element]).to include(
        type: 'plain_text_input',
        action_id: described_class::COMMENT_ACTION_ID,
        multiline: true,
        max_length: described_class::COMMENT_MAX_LENGTH
      )
      expect(comment_block[:element][:placeholder][:text]).to be_present
    end

    it 'includes a data-sharing disclaimer' do
      disclaimer = payload[:blocks].find { |block| block[:type] == 'context' }

      expect(disclaimer[:elements].first[:text]).to include('helps us improve Duo')
    end
  end
end
