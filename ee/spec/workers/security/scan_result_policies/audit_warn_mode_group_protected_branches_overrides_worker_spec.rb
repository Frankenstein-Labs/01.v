# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::AuditWarnModeGroupProtectedBranchesOverridesWorker, feature_category: :security_policy_management do
  let_it_be(:default_organization) { create(:organization) }
  let_it_be(:project) { create(:project) }
  let_it_be(:top_level_group) { create(:group, organization: default_organization) }
  let_it_be(:other_top_level_group) { create(:group, organization: default_organization) }
  let_it_be(:contained_group) { create(:group, parent: top_level_group) }

  let_it_be(:project_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:top_level_group_policy_configuration) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: top_level_group)
  end

  let_it_be(:contained_group_policy_configuration) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: contained_group)
  end

  let_it_be(:project_policy) do
    create(:security_policy, :enforcement_type_warn,
      security_orchestration_policy_configuration: project_policy_configuration)
  end

  let_it_be(:top_level_group_policy) do
    create(:security_policy, :enforcement_type_warn,
      security_orchestration_policy_configuration: top_level_group_policy_configuration)
  end

  let_it_be(:contained_group_policy) do
    create(:security_policy, :enforcement_type_warn,
      security_orchestration_policy_configuration: contained_group_policy_configuration)
  end

  subject(:handle_event) { described_class.new.handle_event(event) }

  shared_examples 'enqueues workers' do
    specify do
      expect(Security::ScanResultPolicies::AuditWarnModeGroupProtectedBranchesOverridesGroupWorker).to \
        receive(:bulk_perform_async_with_contexts)
        .with(
          expected_group_ids,
          hash_including(
            arguments_proc: an_instance_of(Proc),
            context_proc: an_instance_of(Proc)
          )
        ).and_return(nil)

      handle_event
    end
  end

  context 'on create' do
    let(:event) { Security::PolicyCreatedEvent.new(data: { security_policy_id: policy.id }) }

    context 'with top-level group policy' do
      let(:policy) { top_level_group_policy }

      it_behaves_like 'enqueues workers' do
        let(:expected_group_ids) { contain_exactly(top_level_group.id) }
      end
    end

    context 'with CSP group' do
      include Security::PolicyCspHelpers

      before do
        stub_csp_group(top_level_group)
      end

      let(:policy) { top_level_group_policy }

      it_behaves_like 'enqueues workers' do
        let(:expected_group_ids) { contain_exactly(top_level_group.id, other_top_level_group.id) }
      end
    end
  end

  context 'on update' do
    let(:event) do
      Security::PolicyUpdatedEvent.new(
        data: { security_policy_id: policy.id,
                diff: ActiveSupport::HashWithIndifferentAccess.new(diff),
                rules_diff: { created: [], updated: [], deleted: [] } })
    end

    it_behaves_like 'subscribes to event' do
      let(:diff) { {} }
      let(:policy) { top_level_group_policy }
    end

    context 'with updated approval settings' do
      context 'with `block_group_branch_modification` change' do
        let(:diff) do
          { "approval_settings" => {
            "from" => { "block_group_branch_modification" => false },
            "to" => { "block_group_branch_modification" => true }
          } }
        end

        context 'with top-level group policy' do
          let(:policy) { top_level_group_policy }

          it_behaves_like 'enqueues workers' do
            let(:expected_group_ids) { contain_exactly(top_level_group.id) }
          end
        end
      end

      context 'with `block_group_branch_modification` addition' do
        let(:diff) do
          { "approval_settings" => {
            "from" => {},
            "to" => { "block_group_branch_modification" => false }
          } }
        end

        context 'with top-level group policy' do
          let(:policy) { top_level_group_policy }

          it_behaves_like 'enqueues workers' do
            let(:expected_group_ids) { contain_exactly(top_level_group.id) }
          end
        end
      end

      context 'with `block_branch_modification` addition' do
        let(:diff) do
          { "approval_settings" => {
            "from" => {},
            "to" => { "block_branch_modification" => true }
          } }
        end

        context 'with top-level group policy' do
          let(:policy) { top_level_group_policy }

          it_behaves_like 'enqueues workers' do
            let(:expected_group_ids) { contain_exactly(top_level_group.id) }
          end
        end
      end
    end
  end

  context 'with unrecognized event' do
    let(:event) { Struct.new(:data).new(data: { security_policy_id: top_level_group_policy }) }

    specify do
      expect { handle_event }.to raise_error(RuntimeError)
    end
  end
end
