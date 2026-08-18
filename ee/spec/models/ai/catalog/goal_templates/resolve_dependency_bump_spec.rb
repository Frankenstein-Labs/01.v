# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::ResolveDependencyBump, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe '.resolve' do
    it 'returns the merge request URL as the goal' do
      result = described_class.resolve(event_type: :mention, resource: merge_request)

      expect(result).to eq(Gitlab::UrlBuilder.build(merge_request))
    end

    it 'raises ArgumentError when resource is nil' do
      expect do
        described_class.resolve(event_type: :mention, resource: nil)
      end.to raise_error(ArgumentError, /resource must not be nil/)
    end
  end
end
