# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ProjectRuleDestroyService, feature_category: :code_review_workflow do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, group: group) }
  let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe '#execute' do
    let!(:project_rule) { create(:approval_project_rule, project: project) }
    let(:current_user) { create(:user, name: 'Bruce Wayne') }

    subject { described_class.new(project_rule, current_user).execute }

    shared_context 'an audit event is added' do
      it 'adds an audit event' do
        expect { subject }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details).to include({
          author_name: current_user.name,
          custom_message: 'Deleted approval rule',
          target_type: 'ApprovalProjectRule',
          target_id: project_rule.id
        })
      end

      before_all do
        create(:audit_events_group_external_streaming_destination, group: group)
      end

      before do
        stub_licensed_features(external_audit_events: true)
      end

      it_behaves_like 'sends correct event type in audit event stream' do
        let_it_be(:event_type) { 'approval_rule_deleted' }
      end
    end

    context 'when user does not have permission' do
      let_it_be(:current_user) { create(:user, name: 'Bruce Wayne', developer_of: project) }

      it 'returns an error response' do
        expect(subject).to be_error
        expect(subject.message).to eq('Prohibited')
      end

      it 'does not destroy the project rule' do
        expect { subject }.not_to change { ApprovalProjectRule.count }
      end

      it 'checks the delete_approval_rule ability against the rule' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?)
          .with(current_user, :delete_approval_rule, project_rule)
          .and_call_original

        subject
      end
    end

    context 'when user has permission' do
      let_it_be(:current_user) { create(:user, name: 'Bruce Wayne', maintainer_of: project) }

      context 'when there is no merge request rules' do
        it 'destroys project rule' do
          expect { subject }.to change { ApprovalProjectRule.count }.by(-1)
        end

        include_context 'an audit event is added'
      end

      context 'when there is a merge request rule' do
        let!(:merge_request_rule) do
          create(:approval_merge_request_rule, merge_request: merge_request).tap do |rule|
            rule.approval_project_rule = project_rule
          end
        end

        context 'when open' do
          let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

          it 'destroys merge request rules' do
            expect { subject }.to change { ApprovalMergeRequestRule.count }.by(-1)
          end

          include_context 'an audit event is added'
        end

        context 'when merged' do
          before do
            merge_request.mark_as_merged!
          end

          it 'does nothing' do
            expect { subject }.not_to change { ApprovalMergeRequestRule.count }
          end

          include_context 'an audit event is added'
        end

        context 'when originating from a security policy' do
          let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

          before do
            project_rule.update!(security_orchestration_policy_configuration: policy_configuration)
          end

          it 'raises an AccessDeniedError' do
            expect { subject }.to raise_error(Gitlab::Access::AccessDeniedError)
          end
        end
      end
    end
  end
end
