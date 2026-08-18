# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Variables::Builder::Pipeline, feature_category: :pipeline_composition do
  let_it_be(:project) { create_default(:project, :repository, create_tag: 'test').freeze }
  let_it_be_with_reload(:user) { create(:user) }

  before_all do
    project.add_maintainer(user)
  end

  describe '#predefined_variables' do
    subject(:predefined_variables) { described_class.new(pipeline).predefined_variables }

    context 'when merge request is present' do
      let_it_be(:policy) { create(:scan_result_policy_read, project: project) }

      let_it_be_with_refind(:merge_request) do
        create(:merge_request, :simple, source_project: project, target_project: project)
      end

      let(:pipeline) do
        create(:ci_pipeline, :detached_merge_request_pipeline,
          ci_ref_presence: false,
          user: user,
          merge_request: merge_request)
      end

      context 'when there are some approval checks' do
        before do
          create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: 2)
          create(:code_owner_rule, name: '*', merge_request: merge_request, users: [user])
          create(:report_approver_rule, merge_request: merge_request, users: [user], approvals_required: 1)
          create(:report_approver_rule, :scan_finding, merge_request: merge_request,
            scan_result_policy_read: policy, name: 'Policy 1')
          create(:any_approver_rule, merge_request: merge_request)
        end

        context 'when approved' do
          before do
            create(:approval, merge_request: merge_request, user: user)
          end

          it 'exposes merge request pipeline variables' do
            expect(predefined_variables.to_hash).to include(
              { 'CI_MERGE_REQUEST_APPROVED' => 'true' }
            )
          end
        end

        context 'when not approved' do
          it 'exposes merge request pipeline variables' do
            expect(predefined_variables.to_hash).not_to include(
              { 'CI_MERGE_REQUEST_APPROVED' => 'true' }
            )
          end
        end

        context 'on checking N+1 queries', :request_store, :use_sql_query_cache do
          it 'avoids N+1 database queries' do
            # warm up the cache
            described_class.new(pipeline).predefined_variables

            control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
              described_class.new(pipeline.reload).predefined_variables
            end

            create(:code_owner_rule, name: '*/*', merge_request: merge_request)
            create(:report_approver_rule, :scan_finding, merge_request: merge_request,
              scan_result_policy_read: policy, name: 'Policy 2')

            expect do
              described_class.new(pipeline.reload).predefined_variables
            end.to issue_same_number_of_queries_as(control)
          end
        end
      end
    end
  end
end
