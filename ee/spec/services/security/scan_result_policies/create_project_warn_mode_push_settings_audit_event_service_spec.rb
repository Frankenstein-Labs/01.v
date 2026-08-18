# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CreateProjectWarnModePushSettingsAuditEventService, feature_category: :security_policy_management do
  let_it_be(:policy_management_project) { create(:project) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project_id: policy_management_project.id
    )
  end

  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: 'main') }

  let_it_be(:warn_mode_policy) do
    create_policy(1, warn_mode: true, approval_settings: { block_branch_modification: true })
  end

  let_it_be(:enforced_policy) { create_policy(2, warn_mode: false) }
  let_it_be(:policy_bot) { create(:user, :security_policy_bot) { |bot| project.add_guest(bot) } }

  let(:overrides) { [] }
  let(:recorded_audit_events) { [] }

  subject(:service) { described_class.new(project, current_policy) }

  before do
    attributes = { project: project, warn_mode_policies: [current_policy] }

    allow_next_instance_of(Security::ScanResultPolicies::PushSettingsOverrides, **attributes) do |instance|
      allow(instance).to receive(:all).and_return(overrides)
    end

    allow_next_instances_of(Gitlab::Audit::Auditor, 3) do |auditor|
      allow(auditor).to receive(:record) do |audit_events|
        recorded_audit_events.concat(audit_events)
      end
    end
  end

  describe '#execute' do
    subject(:execute) { Gitlab::SafeRequestStore.ensure_request_store { service.execute } }

    let(:expected_common_attributes) do
      {
        author_id: project.security_policy_bot.id,
        entity_id: policy_management_project.id
      }
    end

    shared_examples 'does not create audit event' do
      specify do
        expect(Gitlab::Audit::Auditor).not_to receive(:new)

        execute
      end
    end

    context 'when policy is not in warn mode' do
      let(:current_policy) { enforced_policy }

      include_examples 'does not create audit event'
    end

    context 'when policy is in warn mode' do
      context 'when there are no overrides' do
        let(:current_policy) { warn_mode_policy }
        let(:overrides) { [] }

        include_examples 'does not create audit event'
      end

      context 'when there are overrides' do
        let(:current_policy) { warn_mode_policy }
        let(:override_object) do
          Data.define(:security_policy, :attribute, :protected_branches)
              .new(warn_mode_policy, :block_branch_modification, [protected_branch])
        end

        let(:overrides) { [override_object] }

        let(:message_initial) do
          "In project (#{project.full_path}), the approval settings in a security policy in warn mode will " \
            "override the branch protections in"
        end

        it 'records a single audit event with correct attributes and message' do
          execute

          expect(recorded_audit_events.size).to eq(1)

          expect(recorded_audit_events.first).to have_attributes(
            **expected_common_attributes,
            details: hash_including(
              event_name: described_class::AUDIT_EVENT,
              target_id: warn_mode_policy.id,
              target_type: 'Security::Policy',
              custom_message: "#{message_initial} \"main\": Prevent branch modification"
            )
          )
        end

        context 'with multiple overrides' do
          let(:protected_branch_2) { create(:protected_branch, project: project, name: 'develop') }

          let(:override_object_2) do
            Data.define(:security_policy, :attribute, :protected_branches)
              .new(warn_mode_policy,
                :prevent_pushing_and_force_pushing,
                [protected_branch, protected_branch_2]
              )
          end

          let(:overrides) { [override_object, override_object_2] }

          it 'records an event per override with correct attributes and messages' do
            execute

            expect(recorded_audit_events.size).to eq(2)

            expect(recorded_audit_events).to match_array([
              an_object_having_attributes(
                **expected_common_attributes,
                details: hash_including(
                  event_name: described_class::AUDIT_EVENT,
                  target_id: warn_mode_policy.id,
                  custom_message: "#{message_initial} \"main\": Prevent branch modification"
                )
              ),
              an_object_having_attributes(
                **expected_common_attributes,
                details: hash_including(
                  event_name: described_class::AUDIT_EVENT,
                  target_id: warn_mode_policy.id,
                  custom_message: "#{message_initial} \"main\", \"develop\": Prevent pushing and force pushing"
                )
              )
            ])
          end
        end

        context 'when security policy bot does not exist' do
          it 'creates a new security policy bot user' do
            policy_bot.destroy!

            expect { execute }.to change { User.security_policy_bot.count }.by(1)
            expect(project.reload.security_policy_bot).to be_present
          end
        end

        context 'when security policy bot already exists' do
          it 'does not create a new bot' do
            expect { execute }.not_to change { User.count }
          end
        end
      end
    end

    context 'when there is no policy management project' do
      let(:current_policy) { warn_mode_policy }

      before do
        policy_configuration.delete
      end

      include_examples 'does not create audit event'
    end
  end

  private

  def create_policy(policy_index, warn_mode: false, approval_settings: {})
    enforcement_type = warn_mode ? Security::Policy::ENFORCEMENT_TYPE_WARN : Security::Policy::DEFAULT_ENFORCEMENT_TYPE

    create(:security_policy, policy_index: policy_index,
      security_orchestration_policy_configuration: policy_configuration,
      content: { enforcement_type: enforcement_type, approval_settings: approval_settings }
    )
  end
end
