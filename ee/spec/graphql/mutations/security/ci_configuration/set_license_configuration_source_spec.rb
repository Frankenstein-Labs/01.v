# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::CiConfiguration::SetLicenseConfigurationSource, feature_category: :dependency_management do
  include GraphqlHelpers

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:current_user) { create(:user) }
    let(:security_setting) { create(:project_security_setting) }
    let(:project) { security_setting.project }

    let(:mutated_source) { subject[:license_configuration_source] }

    subject(:resolve) { mutation.resolve(project_path: project.full_path, source: 'pmdb') }

    context 'when the user can update license configuration source' do
      before do
        stub_licensed_features(license_information_source: true)
      end

      context 'when user does not have access to the project' do
        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when user has access to the project' do
        before do
          project.add_maintainer(current_user)
        end

        it 'returns license configuration source value' do
          expect(mutated_source).to eq('pmdb')
          expect(resolve[:errors]).to be_empty
        end
      end
    end
  end
end
