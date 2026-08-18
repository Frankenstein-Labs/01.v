# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::CustomSoftwareLicenses::FindOrCreateService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let(:license_name) { 'MIT' }
  let(:base_params) { { name: license_name, approval_status: 'denied' } }
  let(:params) { base_params }

  subject(:service) { described_class.new(project: project, params: params) }

  describe '#execute' do
    context 'when custom_software_license does not exist' do
      it 'creates a custom_software_license' do
        expect { service.execute }.to change { Security::CustomSoftwareLicense.count }.by(1)
      end

      context 'when license name contains whitespaces' do
        let(:license_name) { '  MIT   ' }

        it 'creates one software license policy with stripped name' do
          response = service.execute
          custom_software_license = response.payload[:custom_software_license]

          expect(response.success?).to be_truthy
          expect(custom_software_license).to be_persisted
          expect(custom_software_license.name).to eq('MIT')
        end
      end
    end

    context 'when custom_software_license already exists' do
      before do
        create(:custom_software_license, project: project, name: license_name)
      end

      it 'does not create a custom_software_license' do
        expect { service.execute }.not_to change { Security::CustomSoftwareLicense.count }
      end
    end
  end
end
