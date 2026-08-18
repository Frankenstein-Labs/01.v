# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::CreateFromTemplateService, feature_category: :compliance_management do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(custom_compliance_frameworks: true)
  end

  before_all do
    group.add_owner(user)
  end

  describe '#execute' do
    context 'when template does not exist' do
      subject(:service) { described_class.new(user: user, group: group, template_id: 'nonexistent') }

      it 'returns an error' do
        result = service.execute

        expect(result.error?).to be true
        expect(result.message).to eq('Template not found')
      end
    end

    context 'when template exists' do
      subject(:service) { described_class.new(user: user, group: group, template_id: 'soc2', overrides: overrides) }

      let(:overrides) { {} }

      it 'creates a new compliance framework' do
        expect { service.execute }.to change { ComplianceManagement::Framework.count }.by(1)
      end

      it 'returns a successful response' do
        result = service.execute

        expect(result.success?).to be true
      end

      it 'creates framework with template attributes' do
        framework = service.execute.payload[:framework]

        expect(framework.name).to eq('SOC 2')
        expect(framework.color).to eq('#D03E38')
        expect(framework.template_id).to eq('soc2')
        expect(framework.template_version).to eq(1)
      end

      it 'creates requirements from template' do
        expect { service.execute }.to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirement.count
        }.by(9)
      end

      it 'creates controls from template' do
        expect { service.execute }.to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count
        }.by(26)
      end

      context 'with overrides' do
        let(:overrides) { { name: 'Custom SOC 2', description: 'Custom description', color: '#ff0000' } }

        it 'uses overridden values' do
          framework = service.execute.payload[:framework]

          expect(framework.name).to eq('Custom SOC 2')
          expect(framework.description).to eq('Custom description')
          expect(framework.color).to eq('#ff0000')
        end

        it 'still sets template_id and template_version' do
          framework = service.execute.payload[:framework]

          expect(framework.template_id).to eq('soc2')
          expect(framework.template_version).to eq(1)
        end
      end

      context 'with default override' do
        let(:overrides) { { default: true } }

        it 'sets framework as default' do
          service.execute

          expect(group.reload.namespace_settings.default_compliance_framework_id).to be_present
        end
      end
    end

    context 'when user does not have permissions' do
      let(:stranger) { create(:user) }

      subject(:service) { described_class.new(user: stranger, group: group, template_id: 'soc2') }

      it 'returns an error' do
        result = service.execute

        expect(result.error?).to be true
        expect(result.message).to eq('Not permitted to create framework')
      end
    end

    context 'when framework creation fails' do
      subject(:service) { described_class.new(user: user, group: group, template_id: 'soc2') }

      before do
        create(:compliance_framework, namespace: group, name: 'SOC 2')
      end

      it 'does not create a framework' do
        expect { service.execute }.not_to change { ComplianceManagement::Framework.count }
      end

      it 'does not create requirements' do
        expect { service.execute }.not_to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirement.count
        }
      end
    end
  end
end
