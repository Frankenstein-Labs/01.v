# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::HookData::MergeRequestBuilder, feature_category: :webhooks do
  let_it_be(:merge_request) { create(:merge_request) }

  let(:builder) { described_class.new(merge_request) }

  describe '.safe_hook_attributes' do
    let(:safe_attribute_keys) { described_class.safe_hook_attributes }

    it 'includes safe attribute' do
      expected_safe_attribute_keys = %i[
        approval_rules
        assignee_id
        author_id
        blocking_discussions_resolved
        created_at
        description
        head_pipeline_id
        id
        iid
        last_edited_at
        last_edited_by_id
        merge_commit_sha
        merge_error
        merge_params
        merge_status
        merge_user_id
        merge_when_pipeline_succeeds
        milestone_id
        reviewer_ids
        source_branch
        source_project_id
        state_id
        target_branch
        target_project_id
        time_estimate
        title
        updated_at
        updated_by_id
        draft
        prepared_at
      ].freeze

      expect(safe_attribute_keys).to include(*expected_safe_attribute_keys)
    end
  end

  describe '#build' do
    let(:data) { builder.build }

    %i[source target].each do |key|
      describe "#{key} key" do
        include_examples 'project hook data', project_key: key do
          let(:project) { merge_request.public_send("#{key}_project") }
        end
      end
    end

    it 'includes safe attributes' do
      expect(data).to include(*described_class.safe_hook_attributes)
    end

    it 'includes additional attrs' do
      expected_additional_attributes = %w[
        approval_rules
      ].freeze

      expect(data).to include(*expected_additional_attributes)
    end
  end
end
