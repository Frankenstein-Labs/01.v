# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetLicenseScanningForCyclonedxService,
  feature_category: :software_composition_analysis do
  describe '#execute' do
    let_it_be_with_reload(:security_setting) { create(:project_security_setting) }
    let(:namespace) { security_setting.project }

    subject(:response) { described_class.execute(namespace: namespace, enable: enable) }

    context 'when enabling' do
      let(:enable) { true }

      before do
        security_setting.update!(license_scanning_for_cyclonedx_enabled: false)
      end

      it 'returns a successful response with the new value' do
        expect(response).to have_attributes(errors: be_blank, payload: include(enabled: true))
      end

      it 'persists the change' do
        expect { response }
          .to change { security_setting.reload.license_scanning_for_cyclonedx_enabled }
          .from(false).to(true)
      end
    end

    context 'when disabling' do
      let(:enable) { false }

      before do
        security_setting.update!(license_scanning_for_cyclonedx_enabled: true)
      end

      it 'returns a successful response with the new value' do
        expect(response).to have_attributes(errors: be_blank, payload: include(enabled: false))
      end

      it 'persists the change' do
        expect { response }
          .to change { security_setting.reload.license_scanning_for_cyclonedx_enabled }
          .from(true).to(false)
      end
    end

    context 'when enable is nil' do
      let(:enable) { nil }

      before do
        security_setting.update!(license_scanning_for_cyclonedx_enabled: true)
      end

      it 'returns an error response' do
        expect(response).to have_attributes(errors: be_present, payload: include(enabled: nil))
      end

      it 'does not change the attribute' do
        expect { response }
          .not_to change { security_setting.reload.license_scanning_for_cyclonedx_enabled }
      end
    end
  end
end
