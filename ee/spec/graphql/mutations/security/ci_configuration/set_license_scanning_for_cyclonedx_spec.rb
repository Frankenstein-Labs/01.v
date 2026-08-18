# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::CiConfiguration::SetLicenseScanningForCyclonedx,
  feature_category: :software_composition_analysis do
  include GraphqlHelpers

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:current_user) { create(:user) }
    let(:security_setting) { create(:project_security_setting, license_scanning_for_cyclonedx_enabled: true) }
    let(:project) { security_setting.project }

    subject(:resolve) { mutation.resolve(project_path: project.full_path, enable: false) }

    context 'when the license_scanning feature is available' do
      before do
        stub_licensed_features(license_scanning: true)
      end

      context 'when the user does not have access to the project' do
        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the user has maintainer access' do
        before do
          project.add_maintainer(current_user)
        end

        it 'returns the new setting value' do
          expect(resolve[:license_scanning_for_cyclonedx_enabled]).to be(false)
          expect(resolve[:errors]).to be_empty
        end

        it 'persists the change' do
          expect { resolve }
            .to change { security_setting.reload.license_scanning_for_cyclonedx_enabled }
            .from(true).to(false)
        end
      end
    end

    context 'when the license_scanning feature is not available' do
      before do
        stub_licensed_features(license_scanning: false)
        project.add_maintainer(current_user)
      end

      it 'raises an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
