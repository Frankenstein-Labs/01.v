# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreateService, feature_category: :code_review_workflow do
  include ProjectForksHelper

  let(:project) { create(:project, :repository) }
  let(:service) { described_class.new(project: project, current_user: user, params: opts) }
  let(:opts) do
    {
      title: 'Awesome merge_request',
      description: 'please fix',
      source_branch: 'feature',
      target_branch: 'master',
      force_remove_source_branch: '1'
    }
  end

  before do
    allow(service).to receive(:execute_hooks)
  end

  describe '#execute' do
    let(:user) { create(:user) }

    before do
      project.add_maintainer(user)
    end

    it 'temporarily unapproves the MR' do
      mr = service.execute

      expect(mr.temporarily_unapproved?).to be_truthy
    end

    context 'pending initial auto reviewer assignment' do
      before do
        stub_licensed_features(code_owners: true)
        project.project_setting.update!(reviewer_assignment_strategy: 'code_owners')
      end

      it 'marks the MR as pending initial auto-assign and enqueues SyncCodeOwner' do
        expect(::MergeRequests::ReviewerAssignment::PendingInitialAssignment)
          .to receive(:mark).with(kind_of(MergeRequest))
        expect(::MergeRequests::SyncCodeOwnerApprovalRulesWorker).to receive(:perform_async)
          .with(kind_of(Integer), 'expire_unapproved_key' => true)

        service.execute
      end

      context 'when the project setting is disabled' do
        before do
          project.project_setting.update!(reviewer_assignment_strategy: 'disabled')
        end

        it 'does not mark the MR as pending initial auto-assign' do
          expect(::MergeRequests::ReviewerAssignment::PendingInitialAssignment).not_to receive(:mark)

          service.execute
        end
      end
    end

    it 'schedules refresh of code owners for the merge request' do
      Sidekiq::Testing.fake! do
        expect { service.execute }.to change { ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.jobs.size }.by(1)
        ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.clear
      end
    end

    context 'report approvers' do
      it 'refreshes report approvers for the merge request' do
        expect_next_instance_of(::MergeRequests::SyncReportApproverApprovalRules) do |service|
          expect(service).to receive(:execute)
        end

        service.execute
      end
    end

    it_behaves_like 'new issuable with scoped labels' do
      let(:parent) { project }
      let(:service_result) { described_class.new(**args).execute }
      let(:issuable) { service_result }
    end

    it_behaves_like 'service with multiple reviewers' do
      let(:execute) { service.execute }
    end

    it_behaves_like 'service with approval rules' do
      let(:execute) { service.execute }
    end

    context 'when v2_approval_rules flag is enabled' do
      let(:accessible_group) { create(:group, :private) }
      let(:opts) do
        {
          title: 'Awesome merge_request',
          description: 'please fix',
          source_branch: 'feature',
          target_branch: 'master',
          force_remove_source_branch: '1',
          approval_rules_attributes: [
            {
              name: 'Filtered Rule',
              approvals_required: 1,
              group_ids: [accessible_group.id, inaccessible_group.id],
              user_ids: [project_member.id, outsider.id]
            }
          ]
        }
      end

      let(:inaccessible_group) { create(:group, :private) }
      let(:project_member) { create(:user) }
      let(:outsider) { create(:user) }

      before do
        stub_feature_flags(v2_approval_rules: true)
        accessible_group.add_developer(user)
        project.add_reporter(project_member)
      end

      it 'creates a v2 approval rule with only accessible groups and project members', :aggregate_failures do
        mr = service.execute
        rule = mr.v2_approval_rules.find_by(name: 'Filtered Rule')

        expect(rule).to be_present
        expect(rule.approver_groups).to contain_exactly(accessible_group)
        expect(rule.approver_users).to contain_exactly(project_member)
      end
    end

    it 'sends the audit streaming event' do
      audit_context = {
        name: 'merge_request_create',
        stream_only: true,
        author: user,
        scope: project,
        message: 'Added merge request'
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(audit_context))

      service.execute
    end

    describe 'Automatic Duo Code Review' do
      let(:ai_review_allowed) { true }
      let(:auto_duo_code_review) { true }
      let(:duo_enabled_project_setting) { true }
      let(:duo) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }
      let(:created_merge_request) { service.execute }

      before do
        allow(project).to receive_messages(
          auto_duo_code_review_enabled: auto_duo_code_review,
          auto_duo_code_review_settings_available?: true
        )
        allow(project.project_setting).to receive(:duo_features_enabled?).and_return(duo_enabled_project_setting)
        allow_next_instance_of(MergeRequest) do |merge_request|
          allow(merge_request).to receive(:ai_review_merge_request_allowed?)
            .with(user)
            .and_return(ai_review_allowed)
        end
      end

      it 'adds Duo as a reviewer' do
        expect(created_merge_request.reviewers).to eq [duo]
      end

      context 'when another reviewer exists' do
        let(:opts) do
          super().merge(reviewer_ids: [user.id])
        end

        it 'adds Duo as a reviewer' do
          expect(created_merge_request.reviewers).to match_array [user, duo]
        end
      end

      context 'when Duo Code Review feature is not allowed' do
        let(:ai_review_allowed) { false }

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end

      context 'when the MR is draft' do
        let(:opts) do
          super().merge(title: 'Draft: Awesome merge_request')
        end

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end

      context 'when Auto Duo Code Review project setting is disabled' do
        let(:auto_duo_code_review) { false }

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end

      context 'when an automated rule excludes the merge request' do
        before do
          allow(project.repository).to receive(:code_review_automated_rules_for).and_return(
            <<~YAML
              exclude:
                target_branches:
                  - "master"
            YAML
          )
        end

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end

        context 'when the rule does not match the merge request' do
          before do
            allow(project.repository).to receive(:code_review_automated_rules_for).and_return(
              <<~YAML
                exclude:
                  target_branches:
                    - "some-other-branch"
              YAML
            )
          end

          it 'adds Duo as a reviewer' do
            expect(created_merge_request.reviewers).to match_array [duo]
          end
        end
      end

      context 'when project setting disables duo' do
        let(:duo_enabled_project_setting) { false }

        before do
          allow(project).to receive(:auto_duo_code_review_settings_available?).and_return(false)
        end

        it 'does not add Duo as a reviewer' do
          expect(created_merge_request.reviewers).to be_empty
        end
      end
    end

    context 'when created during a Duo workflow request' do
      let(:created_merge_request) { service.execute }
      let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

      around do |example|
        ::Gitlab::ApplicationContext.with_context(duo_workflow_id: workflow.id.to_s) { example.run }
      end

      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        stub_ee_application_setting(duo_features_enabled: true)
        allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)
      end

      it 'records a created link from the workflow to the new merge request' do
        expect { created_merge_request }.to change { Ai::DuoWorkflows::WorkflowMergeRequest.count }.by(1)

        link = Ai::DuoWorkflows::WorkflowMergeRequest.order(:id).last
        expect(link).to have_attributes(
          workflow: workflow,
          merge_request_id: created_merge_request.id,
          link_type: 'created'
        )
      end

      context 'when no Duo workflow id is in the request context' do
        around do |example|
          ::Gitlab::ApplicationContext.with_context(duo_workflow_id: nil) { example.run }
        end

        it 'does not record a link' do
          expect { created_merge_request }.not_to change { Ai::DuoWorkflows::WorkflowMergeRequest.count }
        end
      end

      context 'when the current user is not authorized to update the workflow' do
        let(:workflow) { create(:duo_workflows_workflow, project: project, user: create(:user)) }

        it 'does not record a link' do
          expect { created_merge_request }.not_to change { Ai::DuoWorkflows::WorkflowMergeRequest.count }
        end
      end

      it 'does not fail merge request creation when linking raises' do
        allow(::Ai::DuoWorkflows::LinkArtifactService).to receive(:new).and_raise(StandardError)
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)

        expect(created_merge_request).to be_persisted
      end
    end
  end

  describe '#execute with blocking merge requests', :clean_gitlab_redis_shared_state do
    let(:opts) { { title: 'Blocked MR', source_branch: 'feature', target_branch: 'master' } }
    let(:user) { project.first_owner }

    it 'delegates to MergeRequests::UpdateBlocksService' do
      expect(MergeRequests::UpdateBlocksService)
        .to receive(:extract_params!)
        .and_return(:extracted_params)

      expect_next_instance_of(MergeRequests::UpdateBlocksService) do |block_service|
        expect(block_service.merge_request.title).to eq('Blocked MR')
        expect(block_service.current_user).to eq(user)
        expect(block_service.params).to eq(:extracted_params)

        expect(block_service).to receive(:execute)
      end

      service.execute
    end
  end
end
