# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::SyncPolicyEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:compliance_framework) { create(:compliance_framework) }

  let(:policy_scope) { { compliance_frameworks: [{ id: compliance_framework.id }] } }
  let(:security_policy) do
    create(:security_policy, scope: policy_scope)
  end

  let(:service) do
    described_class.new(project: project, security_policy: security_policy, event: event)
  end

  before do
    create(:compliance_framework_project_setting,
      project: project,
      compliance_management_framework: compliance_framework
    )
  end

  subject(:execute) { service.execute }

  describe '#execute' do
    context 'when event is ComplianceFrameworkChangedEvent' do
      let(:event) do
        Projects::ComplianceFrameworkChangedEvent.new(data: {
          project_id: project.id,
          compliance_framework_id: compliance_framework.id,
          event_type: event_type
        })
      end

      shared_examples 'when policy scope does not match compliance_framework' do
        context 'when policy scope does not have compliance_framework' do
          let(:policy_scope) { {} }

          it 'links policy to project because empty scope applies to all' do
            expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)
          end
        end

        context 'when policy scope has a different compliance framework' do
          let_it_be(:other_compliance_framework) { create(:compliance_framework) }
          let(:policy_scope) { { compliance_frameworks: [{ id: other_compliance_framework.id }] } }

          it 'does not link because scope is inapplicable' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end
      end

      context 'when framework is added' do
        let(:event_type) { Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added] }

        it 'links policy to project' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

          expect(project.security_policies).to contain_exactly(security_policy)
        end

        it_behaves_like 'when policy scope does not match compliance_framework'

        it_behaves_like 'creates PEP project schedules' do
          before do
            security_policy.update!(scope: policy_scope)
          end
        end

        context 'when policy is an approval policy' do
          it_behaves_like 'syncs finding enrichments for approval policy with enrichment filters' do
            before do
              create(:approval_policy_rule, security_policy: security_policy)
              security_policy.update!(type: 'approval_policy')
            end
          end
        end
      end

      context 'when event compliance_framework_id does not match policy scope but policy is applicable' do
        let_it_be(:unrelated_framework) { create(:compliance_framework) }
        let(:event_type) { Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed] }
        let(:event) do
          Projects::ComplianceFrameworkChangedEvent.new(data: {
            project_id: project.id,
            compliance_framework_id: unrelated_framework.id,
            event_type: event_type
          })
        end

        it 'links policy based on state rather than event data' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

          expect(project.reload.security_policies).to contain_exactly(security_policy)
        end
      end

      context 'when framework is removed' do
        let(:event_type) { Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed] }

        before do
          project.compliance_framework_settings
            .where(framework_id: compliance_framework.id)
            .delete_all
        end

        context 'when policy is linked to the project' do
          before do
            create(:security_policy_project_link, project: project, security_policy: security_policy)
          end

          it 'unlinks policy from project' do
            expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)

            expect(project.reload.security_policies).to be_empty
          end

          context 'when policy is an approval policy' do
            let!(:approval_policy_rules) do
              create_list(:approval_policy_rule, 2, security_policy: security_policy)
            end

            before do
              security_policy.update!(type: 'approval_policy')
            end

            it 'schedules DeleteApprovalPolicyRulesWorker' do
              expect(Security::DeleteApprovalPolicyRulesWorker).to receive(:perform_in)
                .with(1.minute, approval_policy_rules.map(&:id))

              execute
            end

            context 'when rules are linked to other projects' do
              before do
                create(:approval_policy_rule_project_link,
                  approval_policy_rule: approval_policy_rules.first,
                  project: create(:project)
                )
              end

              it 'does not schedule DeleteApprovalPolicyRulesWorker' do
                expect(Security::DeleteApprovalPolicyRulesWorker).not_to receive(:perform_in)

                execute
              end
            end
          end
        end

        context 'when policy is not linked to the project' do
          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end

        it_behaves_like 'when policy scope does not match compliance_framework'
      end
    end

    context 'with protected branches event' do
      let(:protected_branch) { create(:protected_branch, project: project) }

      before do
        allow(service).to receive(:sync_approval_policy_rules)
      end

      context 'when event is ProtectedBranchCreatedEvent' do
        let(:event) do
          Repositories::ProtectedBranchCreatedEvent.new(data: {
            parent_id: project.id,
            parent_type: 'project',
            protected_branch_id: protected_branch.id
          })
        end

        let!(:rules) do
          create_list(:approval_policy_rule, 2, security_policy: security_policy)
        end

        it 'converges the policy by linking it and syncing all rules' do
          expect(service).to receive(:link_policy).ordered
          expect(service).to receive(:sync_approval_policy_rules).ordered

          execute
        end
      end

      context 'when event is ProtectedBranchDestroyedEvent' do
        let(:event) do
          Repositories::ProtectedBranchDestroyedEvent.new(data: { parent_id: project.id, parent_type: 'project' })
        end

        let!(:rules) do
          create_list(:approval_policy_rule, 2, security_policy: security_policy)
        end

        it 'converges the policy by linking it and syncing all rules' do
          expect(service).to receive(:link_policy).ordered
          expect(service).to receive(:sync_approval_policy_rules).ordered

          execute
        end
      end

      context 'when policy scope is inapplicable to the project' do
        let(:event) do
          Repositories::ProtectedBranchCreatedEvent.new(data: {
            parent_id: project.id,
            parent_type: 'project',
            protected_branch_id: protected_branch.id
          })
        end

        before do
          ComplianceManagement::ComplianceFramework::ProjectSettings.where(project: project).delete_all
          create(:security_policy_project_link, project: project, security_policy: security_policy)
        end

        it 'unlinks the policy instead of syncing rules' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)

          expect(project.reload.security_policies).to be_empty
        end
      end
    end

    context 'when event is DefaultBranchChangedEvent' do
      let(:event) do
        Repositories::DefaultBranchChangedEvent.new(data: { container_id: project.id, container_type: 'Project' })
      end

      let!(:undeleted_rules) do
        create_list(:approval_policy_rule, 2, security_policy: security_policy)
      end

      let!(:deleted_rule) { create(:approval_policy_rule, security_policy: security_policy, rule_index: -1) }

      before do
        allow(service).to receive(:sync_approval_policy_rules)
      end

      context 'when policy scope is applicable to the project' do
        before do
          allow(service).to receive(:link_policy).and_call_original
          allow(service).to receive(:sync_approval_policy_rules).and_call_original
        end

        it 'calls link_policy followed by sync_approval_policy_rules' do
          execute

          expect(service).to have_received(:link_policy).ordered
          expect(service).to have_received(:sync_approval_policy_rules).ordered
        end
      end

      context 'when policy scope is inapplicable to the project' do
        before do
          ComplianceManagement::ComplianceFramework::ProjectSettings.where(project: project).delete_all
          create(:security_policy_project_link, project: project, security_policy: security_policy)
        end

        it 'unlinks the policy instead of syncing rules' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)

          expect(project.reload.security_policies).to be_empty
        end
      end
    end

    shared_examples 'syncs policy for security attribute scope' do
      let(:security_category) do
        create(:security_category, namespace: group, template_type: template_type)
      end

      let(:security_attribute) do
        create(:security_attribute, namespace: group, security_category: security_category)
      end

      let(:event) do
        Projects::SecurityAttributeChangedEvent.new(data: {
          project_id: project.id,
          security_attribute_id: security_attribute.id,
          event_type: event_type
        })
      end

      let(:policy_scope) { { scope_key => { including: [{ id: security_attribute.id }] } } }

      shared_examples 'when policy scope does not match security attribute' do
        context 'when policy scope does not have security attributes' do
          let(:policy_scope) { {} }

          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end

        context 'when policy scope has a different security attribute' do
          let(:other_attribute) do
            create(:security_attribute,
              namespace: group,
              security_category: security_category,
              name: 'Different Attribute')
          end

          let(:policy_scope) { { scope_key => { including: [{ id: other_attribute.id }] } } }

          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end
      end

      context 'when attribute is added' do
        let(:event_type) { Projects::SecurityAttributeChangedEvent::EVENT_TYPES[:added] }

        before do
          create(:project_to_security_attribute,
            project: project,
            security_attribute: security_attribute,
            traversal_ids: project.namespace.traversal_ids)
        end

        it 'links policy to project', :aggregate_failures do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

          expect(project.reload.security_policies).to contain_exactly(security_policy)
        end

        context 'when policy scope excludes the security attribute' do
          let(:policy_scope) { { scope_key => { excluding: [{ id: security_attribute.id }] } } }

          before do
            create(:security_policy_project_link, project: project, security_policy: security_policy)
          end

          it 'unlinks policy from project' do
            expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)

            expect(project.reload.security_policies).to be_empty
          end
        end

        it_behaves_like 'when policy scope does not match security attribute'
      end

      context 'when attribute is removed' do
        let(:event_type) { Projects::SecurityAttributeChangedEvent::EVENT_TYPES[:removed] }

        context 'when policy is linked to the project' do
          before do
            create(:security_policy_project_link, project: project, security_policy: security_policy)
          end

          it 'unlinks policy from project' do
            expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)

            expect(project.reload.security_policies).to be_empty
          end
        end

        context 'when policy is not linked to the project' do
          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end

        context 'when policy scope excludes the security attribute' do
          let(:policy_scope) { { scope_key => { excluding: [{ id: security_attribute.id }] } } }

          it 'links policy to project' do
            expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

            expect(project.reload.security_policies).to contain_exactly(security_policy)
          end
        end

        it_behaves_like 'when policy scope does not match security attribute'
      end
    end

    context 'when event is SecurityAttributeChangedEvent' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration,
          project: project,
          security_policy_management_project: create(:project, namespace: group),
          experiments: { security_attributes_policy_scope: { enabled: true } })
      end

      let(:security_policy) do
        create(:security_policy,
          security_orchestration_policy_configuration: policy_configuration,
          scope: policy_scope)
      end

      context 'with business_impact scope' do
        let(:template_type) { 'business_impact' }
        let(:scope_key) { :business_impact }

        it_behaves_like 'syncs policy for security attribute scope'
      end

      context 'with application_security scope' do
        let(:template_type) { 'application' }
        let(:scope_key) { :application }

        it_behaves_like 'syncs policy for security attribute scope'
      end

      context 'with business_unit scope' do
        let(:template_type) { 'business_unit' }
        let(:scope_key) { :business_unit }

        it_behaves_like 'syncs policy for security attribute scope'
      end

      context 'with exposure scope' do
        let(:template_type) { 'exposure' }
        let(:scope_key) { :exposure }

        it_behaves_like 'syncs policy for security attribute scope'
      end
    end

    context 'when event is PolicyResyncEvent' do
      let(:event) { Security::PolicyResyncEvent.new(data: { security_policy_id: security_policy.id }) }

      let!(:policy_project_link) do
        create(:security_policy_project_link, project: project, security_policy: security_policy)
      end

      context 'when policy is linked to the project' do
        it 'unlinks and then links the policy to the project' do
          expect { execute }.not_to change { Security::PolicyProjectLink.count }
          expect { policy_project_link.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when policy is not linked to the project' do
        before do
          policy_project_link.destroy!
        end

        it 'links the policy to the project' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

          expect(project.security_policies).to contain_exactly(security_policy)
        end
      end

      context 'when policy is an approval policy' do
        let!(:approval_policy_rules) { create_list(:approval_policy_rule, 2, security_policy: security_policy) }

        before do
          security_policy.update!(type: 'approval_policy')
        end

        it 'does not schedule DeleteApprovalPolicyRulesWorker' do
          expect(Security::DeleteApprovalPolicyRulesWorker).not_to receive(:perform_in)

          execute
        end

        it_behaves_like 'syncs finding enrichments for approval policy with enrichment filters'
      end

      context 'when policy is not enabled' do
        before do
          security_policy.update!(enabled: false)
        end

        it 'deletes project link and does not create a new one' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)
        end
      end
    end
  end
end
