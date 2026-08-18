# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::Epic, feature_category: :duo_chat do
  let(:epic) { build(:epic) }
  let(:user) { build(:user) }

  subject(:wrapped_epic) { described_class.new(user, epic) }

  describe '#serialize_for_ai' do
    it 'calls the serializations class' do
      expect(EpicSerializer).to receive_message_chain(:new, :represent)
                                  .with(current_user: user)
                                  .with(epic, {
                                    user: user,
                                    notes_limit: 100,
                                    serializer: 'ai',
                                    resource: wrapped_epic
                                  })

      wrapped_epic.serialize_for_ai(content_limit: 100)
    end
  end

  describe '#current_page_type' do
    it 'returns type' do
      expect(wrapped_epic.current_page_type).to eq('epic')
    end
  end
end
