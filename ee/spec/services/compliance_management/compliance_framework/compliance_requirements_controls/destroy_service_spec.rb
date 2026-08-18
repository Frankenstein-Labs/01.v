# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::DestroyService,
  feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be_with_reload(:requirement) do
    create(:compliance_requirement, framework: framework)
  end

  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:owner) { create(:user, owner_of: namespace) }
  let_it_be(:non_owner) { create(:user) }

  shared_examples 'unsuccessful destruction' do |error_message|
    it 'does not destroy the compliance requirement control' do
      expect { service.execute }
        .not_to change { ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count }
    end

    it 'is unsuccessful' do
      result = service.execute

      expect(result.success?).to be false
      expect(result.message).to eq _(error_message)
    end

    it 'does not audit the destruction' do
      service.execute

      expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
    end
  end

  context 'when feature is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      subject(:service) { described_class.new(control: control, current_user: owner) }

      it_behaves_like 'unsuccessful destruction', 'Not permitted to destroy requirement control'
    end

    context 'when current user is not the namespace owner' do
      subject(:service) { described_class.new(control: control, current_user: non_owner) }

      it_behaves_like 'unsuccessful destruction', 'Not permitted to destroy requirement control'
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      subject(:service) { described_class.new(control: control, current_user: owner) }

      it 'destroys the compliance requirement control' do
        expect { service.execute }.to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.exists?(id: control.id)
        }.from(true).to(false)
      end

      it 'is successful' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.message).to eq _('Compliance requirement control successfully deleted')
      end

      it 'audits the destruction' do
        service.execute

        expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'destroyed_compliance_requirement_control',
          author: owner,
          scope: control.namespace,
          target: control,
          message: "Destroyed compliance requirement control #{control.name}"
        )
      end

      context 'when the compliance requirement has compliance statuses' do
        let_it_be(:project1) { create(:project, namespace: namespace) }
        let_it_be(:project2) { create(:project, namespace: namespace) }

        let!(:requirement_status1) do
          create(:project_requirement_compliance_status, compliance_requirement: requirement, project: project1)
        end

        let!(:requirement_status2) do
          create(:project_requirement_compliance_status, compliance_requirement: requirement, project: project2)
        end

        it 'calls to refresh the compliance requirement statuses of the control' do
          expect(ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService)
            .to receive(:new).with(requirement_status1).and_call_original
          expect(ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService)
            .to receive(:new).with(requirement_status2).and_call_original

          result = service.execute

          expect(result.success?).to be true
        end
      end

      context 'when destruction fails' do
        before do
          allow(control).to receive(:destroy).and_return(false)
        end

        it 'is unsuccessful' do
          result = service.execute

          expect(result.success?).to be false
          expect(result.message).to eq _('Failed to destroy compliance requirement control')
        end

        it 'does not refresh the compliance requirement statuses' do
          expect(ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService)
            .not_to receive(:new)

          service.execute
        end
      end
    end

    context 'when current user is not the namespace owner' do
      subject(:service) { described_class.new(control: control, current_user: non_owner) }

      it 'does not destroy the compliance requirement control' do
        expect { service.execute }
          .not_to change { ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count }
      end

      it_behaves_like 'unsuccessful destruction', 'Not permitted to destroy requirement control'
    end
  end
end
