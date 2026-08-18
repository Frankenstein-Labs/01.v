# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncPolicyEventWorker, feature_category: :security_policy_management do
  let(:worker) { described_class.new }
  let(:event) { {} }

  describe '#handle_event' do
    subject(:handle_event) { worker.handle_event(event) }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'when event is a protected branch event' do
      let_it_be(:project) { create(:project) }
      let_it_be(:protected_branch) { create(:protected_branch) }
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

      let(:event) do
        Repositories::ProtectedBranchCreatedEvent.new(data: {
          protected_branch_id: protected_branch.id,
          parent_id: project.id,
          parent_type: 'project'
        })
      end

      let(:security_policy) do
        create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
      end

      before do
        create(:security_policy_project_link, project: project, security_policy: security_policy)
      end

      context 'when security orchestration policies feature is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'does not sync rules' do
          expect(Security::SyncProjectPolicyWorker).not_to receive(:perform_async)

          handle_event
        end
      end

      it 'executes the sync service for each security policy' do
        expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
          project.id, security_policy.id, {},
          { event: { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys
        )

        handle_event
      end
    end

    context 'when event is for a group' do
      let_it_be_with_refind(:group) { create(:group) }
      let_it_be(:policy_project) { create(:project) }
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace, namespace: group,
          security_policy_management_project: policy_project)
      end

      let(:event) do
        Repositories::ProtectedBranchCreatedEvent.new(data: {
          protected_branch_id: protected_branch.id,
          parent_id: group.id,
          parent_type: 'group'
        })
      end

      let_it_be(:project_1) { create(:project, group: group) }
      let_it_be(:project_2) { create(:project, group: group) }
      let_it_be(:project_3) { create(:project, group: group) }

      let_it_be(:protected_branch) { create(:protected_branch) }

      let(:security_policy) do
        create(:security_policy,
          security_orchestration_policy_configuration: policy_configuration,
          linked_projects: [project_1, project_2, project_3]
        )
      end

      it 'executes the sync service for each security policy' do
        expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
          project_1.id, security_policy.id, {}, { event:
            { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys
        )
        expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
          project_2.id, security_policy.id, {}, { event:
            { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys
        )
        expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
          project_3.id, security_policy.id, {}, { event:
            { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys
        )

        handle_event
      end

      context 'when group is designated as a CSP group' do
        include Security::PolicyCspHelpers

        let_it_be(:other_project) { create(:project) }
        let(:other_security_policy) { create(:security_policy, linked_projects: [other_project]) }

        before do
          stub_csp_group(group)
        end

        it 'calls sync_rules_for_group for all security policies on the instance' do
          expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
            project_1.id, security_policy.id, {}, { event:
              { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys)
          expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
            project_2.id, security_policy.id, {}, { event:
              { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys)
          expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
            project_3.id, security_policy.id, {}, { event:
              { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys)
          expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
            other_project.id, other_security_policy.id, {}, { event:
              { event_type: 'Repositories::ProtectedBranchCreatedEvent', data: event.data } }.deep_stringify_keys)

          handle_event
        end
      end
    end

    context 'when event is not a protected branch event' do
      let(:event) { {} }

      it 'raises ArgumentError' do
        expect { handle_event }.to raise_error(ArgumentError, "Unknown event: Hash")
      end
    end

    context 'when event is a default branch changed event' do
      let_it_be(:project) { create(:project) }
      let(:project_id) { project.id }
      let_it_be(:security_policy) { create(:security_policy) }

      let(:event) do
        Repositories::DefaultBranchChangedEvent.new(data: {
          container_id: project_id,
          container_type: 'Project'
        })
      end

      before do
        create(:security_policy_project_link, project: project, security_policy: security_policy)
      end

      shared_examples_for 'does not sync rules' do
        it 'does not sync rules' do
          expect(Security::SyncProjectPolicyWorker).not_to receive(:perform_async)

          handle_event
        end
      end

      context 'when project is not found' do
        let(:project_id) { non_existing_record_id }

        it_behaves_like 'does not sync rules'
      end

      context 'when security_orchestration_policies is not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'does not sync rules'
      end

      context 'when container type is not Project' do
        let(:event) do
          Repositories::DefaultBranchChangedEvent.new(data: {
            container_id: project.id,
            container_type: 'Group'
          })
        end

        it_behaves_like 'does not sync rules'
      end

      context 'when all conditions are met' do
        it 'executes the sync service for each security policy' do
          expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(project.id, security_policy.id, {},
            { event: { event_type: 'Repositories::DefaultBranchChangedEvent', data: event.data } }.deep_stringify_keys)

          handle_event
        end
      end
    end

    context 'when event is a compliance framework changed event' do
      let_it_be(:root_namespace) { create(:group) }
      let_it_be(:namespace) { create(:group, parent: root_namespace) }
      let_it_be(:other_namespace) { create(:group, parent: root_namespace) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:project_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration, project: nil, namespace: namespace)
      end

      let_it_be(:other_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: nil, namespace: other_namespace)
      end

      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: root_namespace) }
      let_it_be(:compliance_framework_security_policy) do
        create(:compliance_framework_security_policy,
          policy_configuration: policy_configuration,
          framework: compliance_framework
        )
      end

      let_it_be(:project_compliance_framework_security_policy) do
        create(:compliance_framework_security_policy,
          policy_configuration: project_policy_configuration,
          framework: compliance_framework
        )
      end

      let(:compliance_framework_changed_event) do
        ::Projects::ComplianceFrameworkChangedEvent.new(data: {
          project_id: project.id,
          compliance_framework_id: compliance_framework.id,
          event_type: ::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added]
        })
      end

      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      context 'with security_policies' do
        let_it_be(:security_policy) do
          create(:security_policy,
            security_orchestration_policy_configuration: policy_configuration,
            scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
          )
        end

        let_it_be(:deleted_security_policy) do
          create(:security_policy, :deleted,
            security_orchestration_policy_configuration: policy_configuration,
            scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
          )
        end

        let_it_be(:project_security_policy) do
          create(:security_policy,
            security_orchestration_policy_configuration: project_policy_configuration,
            scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
          )
        end

        let_it_be(:other_security_policy) do
          create(:security_policy,
            security_orchestration_policy_configuration: other_policy_configuration,
            scope: { compliance_frameworks: [{ id: compliance_framework.id }] }
          )
        end

        before do
          create(:compliance_framework_project_setting,
            project: project,
            compliance_management_framework: compliance_framework
          )
        end

        it 'invokes Security::SyncProjectPolicyWorker for undeleted policies' do
          expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
            project.id, security_policy.id, {}, { event: {
              event_type: 'Projects::ComplianceFrameworkChangedEvent', data: compliance_framework_changed_event.data
            } }.deep_stringify_keys
          )
          expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
            project.id, project_security_policy.id, {}, { event: {
              event_type: 'Projects::ComplianceFrameworkChangedEvent', data: compliance_framework_changed_event.data
            } }.deep_stringify_keys
          )

          consume_event(subscriber: described_class, event: compliance_framework_changed_event)
        end
      end
    end

    context 'when event is a security attribute changed event' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }
      let_it_be(:security_policy_management_project) { create(:project, namespace: group) }
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration,
          project: project,
          security_policy_management_project: security_policy_management_project)
      end

      let(:policy_scope) { { scope_key => { including: [{ id: security_attribute.id }] } } }

      let(:security_policy) do
        create(:security_policy,
          security_orchestration_policy_configuration: policy_configuration,
          scope: policy_scope)
      end

      let(:event) do
        ::Projects::SecurityAttributeChangedEvent.new(data: {
          project_id: project.id,
          security_attribute_id: security_attribute.id,
          event_type: ::Projects::SecurityAttributeChangedEvent::EVENT_TYPES[:added]
        })
      end

      before do
        create(:project_to_security_attribute,
          project: project,
          security_attribute: security_attribute,
          traversal_ids: project.namespace.traversal_ids)

        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      shared_examples 'syncs rules for security attribute scope' do
        let(:security_category) do
          create(:security_category, namespace: group, template_type: template_type)
        end

        let(:security_attribute) do
          create(:security_attribute, namespace: group, security_category: security_category)
        end

        shared_examples 'does not sync security attribute rules' do
          it 'does not sync rules' do
            expect(Security::SyncProjectPolicyWorker).not_to receive(:perform_async).with(
              project.id, security_policy.id, {}, { event: {
                event_type: 'Projects::SecurityAttributeChangedEvent', data: event.data
              } }.deep_stringify_keys
            )

            handle_event
          end
        end

        context 'when project is not found' do
          let(:event) do
            ::Projects::SecurityAttributeChangedEvent.new(data: {
              project_id: non_existing_record_id,
              security_attribute_id: security_attribute.id,
              event_type: ::Projects::SecurityAttributeChangedEvent::EVENT_TYPES[:added]
            })
          end

          it_behaves_like 'does not sync security attribute rules'
        end

        context 'when security orchestration policies are not licensed' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it_behaves_like 'does not sync security attribute rules'
        end

        context 'when project has no policy configurations' do
          before do
            policy_configuration.destroy!
          end

          it 'does not sync rules' do
            expect(Security::SyncProjectPolicyWorker).not_to receive(:perform_async)

            handle_event
          end
        end

        context 'when policy scope does not match security attribute' do
          let(:policy_scope) { { scope_key => { including: [{ id: non_existing_record_id }] } } }

          it_behaves_like 'does not sync security attribute rules'
        end

        context 'when policy scope does not have security attribute' do
          let(:policy_scope) { {} }

          it_behaves_like 'does not sync security attribute rules'
        end

        context 'when policy scope matches security attribute' do
          it 'syncs policies for the matching attribute scope' do
            expect(Security::SyncProjectPolicyWorker).to receive(:perform_async).with(
              project.id, security_policy.id, {}, { event: {
                event_type: 'Projects::SecurityAttributeChangedEvent', data: event.data
              } }.deep_stringify_keys
            )

            handle_event
          end
        end
      end

      context 'with business_impact scope' do
        let(:template_type) { 'business_impact' }
        let(:scope_key) { :business_impact }

        it_behaves_like 'syncs rules for security attribute scope'
      end

      context 'with application_security scope' do
        let(:template_type) { 'application' }
        let(:scope_key) { :application }

        it_behaves_like 'syncs rules for security attribute scope'
      end

      context 'with business_unit scope' do
        let(:template_type) { 'business_unit' }
        let(:scope_key) { :business_unit }

        it_behaves_like 'syncs rules for security attribute scope'
      end

      context 'with exposure scope' do
        let(:template_type) { 'exposure' }
        let(:scope_key) { :exposure }

        it_behaves_like 'syncs rules for security attribute scope'
      end
    end
  end
end
