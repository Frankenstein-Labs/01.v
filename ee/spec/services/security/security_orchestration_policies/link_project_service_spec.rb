# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::LinkProjectService, '#execute', feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be_with_reload(:security_policy) do
    create(:security_policy, :require_approval, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

  let(:service) { described_class.new(project: project, security_policy: security_policy, action: action) }

  describe 'linking' do
    let(:action) { :link }

    context 'when policy is enabled and scope applicable' do
      it 'links policy to project' do
        expect { service.execute }
          .to change { Security::PolicyProjectLink.count }.by(1)
      end

      context 'with approval policy' do
        it 'creates approval policy rule links' do
          expect { service.execute }
            .to change { Security::ApprovalPolicyRuleProjectLink.count }.by(1)
        end

        it 'creates project approval rules' do
          expect { service.execute }
            .to change { project.approval_rules.count }.by(1)
        end

        it_behaves_like 'syncs finding enrichments for approval policy with enrichment filters'
      end

      context 'with pipeline execution schedule policy' do
        let_it_be(:security_policy) do
          create(:security_policy, :pipeline_execution_schedule_policy,
            security_orchestration_policy_configuration: policy_configuration)
        end

        before do
          allow(policy_configuration).to receive(:experiment_enabled?).and_return(true)
        end

        it 'creates pipeline execution project schedules' do
          expect { service.execute }
            .to change { Security::PipelineExecutionProjectSchedule.count }.by(1)
        end
      end

      context 'with scan execution policy' do
        let_it_be(:security_policy) do
          create(:security_policy, :scan_execution_policy,
            security_orchestration_policy_configuration: policy_configuration,
            policy_index: 0)
        end

        let_it_be(:rule_schedule) do
          create(:security_orchestration_policy_rule_schedule,
            security_orchestration_policy_configuration: policy_configuration,
            policy_index: 0,
            rule_index: 0)
        end

        it 'creates scan execution project schedules' do
          expect { service.execute }
            .to change { Security::ScanExecutionProjectSchedule.count }.by(1)
        end

        context 'when scan_execution_policy_project_schedule_creation feature flag is disabled' do
          before do
            stub_feature_flags(scan_execution_policy_project_schedule_creation: false)
          end

          it 'does not create scan execution project schedules' do
            expect { service.execute }
              .not_to change { Security::ScanExecutionProjectSchedule.count }
          end
        end
      end
    end

    context 'when policy is disabled' do
      before do
        security_policy.update!(enabled: false)
      end

      it 'does not link policy to project' do
        expect { service.execute }
          .not_to change { Security::PolicyProjectLink.count }
      end
    end

    context 'when scope is not applicable' do
      before do
        allow(service).to receive(:scope_applicable?).and_return(false)
      end

      it 'does not link policy to project' do
        expect { service.execute }
          .not_to change { Security::PolicyProjectLink.count }
      end
    end
  end

  describe 'unlinking' do
    let(:action) { :unlink }

    context 'when policy is linked to project' do
      before do
        create(:security_policy_project_link, project: project, security_policy: security_policy)
        create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
      end

      it 'unlinks policy from project' do
        expect { service.execute }
          .to change { Security::PolicyProjectLink.count }.by(-1)
      end

      context 'with approval policy' do
        let_it_be(:project_approval_rule) do
          create(:approval_project_rule, :scan_finding,
            project: project,
            approval_policy_rule: approval_policy_rule,
            security_orchestration_policy_configuration: security_policy.security_orchestration_policy_configuration
          )
        end

        it 'unlinks approval policy rules' do
          expect { service.execute }
            .to change { Security::ApprovalPolicyRuleProjectLink.count }.by(-1)
        end

        it 'deletes project approval rules' do
          expect { service.execute }
            .to change { project.approval_rules.count }.by(-1)
        end
      end

      context 'with pipeline execution schedule policy' do
        let_it_be(:security_policy) do
          create(:security_policy, :pipeline_execution_schedule_policy,
            security_orchestration_policy_configuration: policy_configuration)
        end

        before do
          create(:security_pipeline_execution_project_schedule, project: project, security_policy: security_policy)
        end

        it 'deletes pipeline execution project schedules' do
          expect { service.execute }
            .to change { Security::PipelineExecutionProjectSchedule.count }.by(-1)
        end
      end

      context 'with scan execution policy' do
        let_it_be(:security_policy) do
          create(:security_policy, :scan_execution_policy,
            security_orchestration_policy_configuration: policy_configuration,
            policy_index: 0)
        end

        before do
          create(:security_scan_execution_project_schedule, project: project, security_policy: security_policy)
        end

        it 'deletes scan execution project schedules' do
          expect { service.execute }
            .to change { Security::ScanExecutionProjectSchedule.count }.by(-1)
        end

        context 'when scan_execution_policy_project_schedule_creation feature flag is disabled' do
          before do
            stub_feature_flags(scan_execution_policy_project_schedule_creation: false)
          end

          it 'does not delete scan execution project schedules' do
            expect { service.execute }
              .not_to change { Security::ScanExecutionProjectSchedule.count }
          end
        end
      end
    end

    context 'when policy is not linked to project' do
      it 'does not change policy links' do
        expect { service.execute }
          .not_to change { Security::PolicyProjectLink.count }
      end
    end
  end

  describe 'invalid action' do
    let(:action) { :invalid }

    it 'raises an error' do
      expect { service.execute }
        .to raise_error('unsupported action: invalid')
    end
  end
end
