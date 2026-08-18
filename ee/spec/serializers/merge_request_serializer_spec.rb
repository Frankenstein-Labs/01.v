# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestSerializer, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need create it
  let_it_be(:merge_request) { create(:merge_request, description: "Description") } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need create it
  let(:serializer) { 'ai' }

  let(:json_entity) do
    described_class.new(current_user: user)
      .represent(merge_request,
        serializer: serializer,
        notes_limit: 2,
        resource: Ai::AiResource::MergeRequest.new(user, merge_request))
      .with_indifferent_access
  end

  context 'when serializing merge request for ai' do
    it 'returns ai related data' do
      expect(json_entity.keys).to include("mr_comments", "diff")
    end
  end
end
