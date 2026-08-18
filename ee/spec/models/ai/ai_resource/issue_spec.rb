# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::Issue, feature_category: :duo_chat do
  let(:issue) { build(:issue) }
  let(:user) { build(:user) }

  subject(:wrapped_issue) { described_class.new(user, issue) }

  describe '#serialize_for_ai' do
    it 'calls the serializations class' do
      expect(::IssueSerializer).to receive_message_chain(:new, :represent)
                                     .with(current_user: user, project: issue.project)
                                     .with(issue, {
                                       user: user,
                                       notes_limit: 100,
                                       serializer: 'ai',
                                       resource: wrapped_issue
                                     })
      wrapped_issue.serialize_for_ai(content_limit: 100)
    end
  end

  describe '#current_page_type' do
    it 'returns type' do
      expect(wrapped_issue.current_page_type).to eq('issue')
    end
  end
end
