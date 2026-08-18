# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirements::DestroyService,
  feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be_with_refind(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be_with_refind(:requirement) { create(:compliance_requirement, framework: framework) }
  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:owner) { create(:user, owner_of: namespace) }
  let_it_be(:non_owner) { create(:user) }

  shared_examples 'unsuccessful destruction' do |error_message|
    it 'does not destroy the compliance requirement' do
      expect { service.execute }
        .not_to change { ComplianceManagement::ComplianceFramework::ComplianceRequirement.count }
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
      subject(:service) { described_class.new(requirement: requirement, current_user: owner) }

      it_behaves_like 'unsuccessful destruction', 'Not permitted to destroy requirement'
    end

    context 'when current user is not the namespace owner' do
      subject(:service) { described_class.new(requirement: requirement, current_user: non_owner) }

      it_behaves_like 'unsuccessful destruction', 'Not permitted to destroy requirement'
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      subject(:service) { described_class.new(requirement: requirement, current_user: owner) }

      it 'destroys the compliance requirement' do
        requirement_id = requirement.id
        expect(
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl
          .where(compliance_requirement_id: requirement_id).count
        ).to eq(1)
        expect { service.execute }.to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirement.exists?(id: requirement_id)
        }.from(true).to(false)
        expect(
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl
          .where(compliance_requirement_id: requirement_id).count
        ).to eq(0)
      end

      it 'is successful' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.message).to eq _('Compliance requirement successfully deleted')
      end

      it 'audits the destruction' do
        service.execute

        expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'destroyed_compliance_requirement',
          author: owner,
          scope: requirement.framework.namespace,
          target: requirement,
          message: "Destroyed compliance requirement #{requirement.name}"
        )
      end

      context 'when destruction fails' do
        before do
          allow_next_found_instance_of(ComplianceManagement::ComplianceFramework::ComplianceRequirement) do |instance|
            allow(instance).to receive(:destroy).and_return(false)
          end
        end

        it 'is unsuccessful' do
          result = service.execute

          expect(result.success?).to be false
          expect(result.message).to eq _('Failed to destroy compliance requirement')
        end
      end
    end

    context 'when current user is not the namespace owner' do
      subject(:service) { described_class.new(requirement: requirement, current_user: non_owner) }

      it 'does not destroy the compliance requirement' do
        expect { service.execute }
          .not_to change { ComplianceManagement::ComplianceFramework::ComplianceRequirement.count }
      end

      it_behaves_like 'unsuccessful destruction', 'Not permitted to destroy requirement'
    end
  end
end
