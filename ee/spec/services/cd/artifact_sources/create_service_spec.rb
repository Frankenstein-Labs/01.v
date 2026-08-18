# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ArtifactSources::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { name: 'api', source_ref: 'registry.example.com/web' } }

  subject(:result) do
    described_class.new(parent: service, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the persisted artifact source', :aggregate_failures do
      expect { result }.to change { ::Cd::ArtifactSource.count }.by(1)

      artifact_source = result.payload[:artifact_source]
      expect(result).to be_success
      expect(artifact_source).to be_persisted
      expect(artifact_source).to have_attributes(
        service: service,
        organization: organization,
        name: 'api',
        source_ref: 'registry.example.com/web'
      )
    end

    context 'when source_ref exceeds the maximum length' do
      let(:params) { { name: 'api', source_ref: 'a' * 256 } }

      it 'does not create an artifact source and returns the error' do
        expect { result }.not_to change { ::Cd::ArtifactSource.count }
        expect(result).to be_error
        expect(result.message).to include('Source ref is too long (maximum is 255 characters)')
      end
    end

    context 'when name is blank' do
      let(:params) { { name: '', source_ref: 'registry.example.com/web' } }

      it 'does not create an artifact source and returns the error' do
        expect { result }.not_to change { ::Cd::ArtifactSource.count }
        expect(result).to be_error
        expect(result.message).to include("Name can't be blank")
      end
    end
  end
end
