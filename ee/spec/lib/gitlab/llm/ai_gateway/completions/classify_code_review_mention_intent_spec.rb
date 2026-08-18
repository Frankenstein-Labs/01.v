# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::ClassifyCodeReviewMentionIntent,
  feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  let(:prompt_message) do
    build(:ai_message, user: user, resource: merge_request, request_id: 'uuid',
      ai_action: 'classify_code_review_mention_intent')
  end

  subject(:completion) { described_class.new(prompt_message, nil, { message: 'can you review this?' }) }

  describe '#inputs' do
    it 'returns the message as inputs for the AI Gateway prompt' do
      expect(completion.inputs).to eq({ message: 'can you review this?' })
    end
  end

  describe '#unit_primitive_name' do
    it 'uses duo_agent_platform as the unit primitive' do
      expect(completion.send(:unit_primitive_name)).to eq(:duo_agent_platform)
    end
  end
end
