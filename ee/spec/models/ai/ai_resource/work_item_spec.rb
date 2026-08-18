# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::WorkItem, feature_category: :duo_chat do
  let(:work_item) { build(:work_item) }
  let(:user) { build(:user) }

  subject(:wrapped_work_item) { described_class.new(user, work_item) }

  describe '#serialize_for_ai' do
    context 'when issue is synced with epic' do
      let(:epic) { build(:epic) }

      before do
        work_item.synced_epic = epic
      end

      it 'calls the epics serializations class' do
        expect(::EpicSerializer).to receive_message_chain(:new, :represent)
                                       .with(current_user: user)
                                       .with(epic, {
                                         user: user,
                                         notes_limit: 100,
                                         serializer: 'ai',
                                         resource: wrapped_work_item
                                       })
        wrapped_work_item.serialize_for_ai(content_limit: 100)
      end
    end

    it 'calls the serializations class' do
      expect(::IssueSerializer).to receive_message_chain(:new, :represent)
                                     .with(current_user: user, project: work_item.project)
                                     .with(work_item, {
                                       user: user,
                                       notes_limit: 100,
                                       serializer: 'ai',
                                       resource: wrapped_work_item
                                     })
      wrapped_work_item.serialize_for_ai(content_limit: 100)
    end

    context 'when content_limit is omitted' do
      let(:work_item) { create(:work_item) }

      it 'does not raise error' do
        expect { wrapped_work_item.serialize_for_ai }.not_to raise_error
      end
    end
  end

  describe '#current_page_type' do
    it 'returns type' do
      expect(wrapped_work_item.current_page_type).to eq('work_item')
    end
  end
end
