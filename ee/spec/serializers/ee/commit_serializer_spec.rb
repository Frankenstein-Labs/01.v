# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::CommitSerializer, feature_category: :ai_abstraction_layer do
  let_it_be(:user, freeze: false) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
  let_it_be(:project, freeze: false) { create(:project, :public, :repository) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
  let_it_be(:commit, freeze: false) { project.commit }
  let(:serializer) { 'ai' }

  let(:json_entity) do
    described_class
      .new(current_user: user, project: project)
      .represent(
        commit,
        serializer: serializer,
        notes_limit: 2,
        resource: Ai::AiResource::Commit.new(user, commit
        )
      )
      .with_indifferent_access
  end

  context 'when serializing merge request for ai' do
    it 'returns ai related data' do
      expect(json_entity.keys).to include("commit_comments", "diffs")
    end
  end

  context 'when serializing commit without ai serializer' do
    let(:serializer) { nil }

    it 'does not include ai-specific fields' do
      expect(json_entity.keys).not_to include("commit_comments", "diffs")
    end
  end
end
