# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::RecommendReviewers, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe '.resolve' do
    it 'returns the bare merge request iid as the goal' do
      result = described_class.resolve(event_type: :merge_request_ready, resource: merge_request)

      expect(result).to eq(merge_request.iid.to_s)
    end

    it 'returns the iid regardless of the event type' do
      results = [:merge_request_ready, :mention, :assign, :assign_reviewer].map do |event_type|
        described_class.resolve(event_type: event_type, resource: merge_request)
      end

      expect(results).to all(eq(merge_request.iid.to_s))
    end

    it 'ignores user_input' do
      result = described_class.resolve(
        event_type: :mention,
        resource: merge_request,
        user_input: '@duo please recommend reviewers'
      )

      expect(result).to eq(merge_request.iid.to_s)
    end

    it 'raises ArgumentError when resource is nil' do
      expect do
        described_class.resolve(event_type: :merge_request_ready, resource: nil)
      end.to raise_error(ArgumentError, /resource must not be nil/)
    end

    context 'when the resource is not a merge request' do
      let_it_be(:issue) { create(:issue, project: project) }

      # Deliberately nil rather than a raise: raising would abort the unrescued
      # mention loop in Notes::PostProcessService.
      it 'returns nil rather than the resource iid' do
        result = described_class.resolve(event_type: :mention, resource: issue)

        expect(result).to be_nil
      end
    end
  end
end
