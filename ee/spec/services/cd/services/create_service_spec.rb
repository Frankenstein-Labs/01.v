# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Services::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { name: 'my-service', description: 'a description' } }

  subject(:result) do
    described_class.new(parent: application, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the persisted service', :aggregate_failures do
      expect { result }.to change { ::Cd::Service.count }.by(1)

      service = result.payload[:service]
      expect(result).to be_success
      expect(service).to be_persisted
      expect(service).to have_attributes(
        application: application,
        organization: organization,
        name: 'my-service',
        description: 'a description'
      )
    end

    context 'when name is blank' do
      let(:params) { super().merge(name: '') }

      it 'does not create a service and returns the error' do
        expect { result }.not_to change { ::Cd::Service.count }
        expect(result).to be_error
        expect(result.message).to include("Name can't be blank")
      end
    end

    context 'when name is already taken in the application' do
      before do
        create(:cd_service, application: application, name: 'my-service')
      end

      it 'does not create a service and returns the error' do
        expect { result }.not_to change { ::Cd::Service.count }
        expect(result).to be_error
        expect(result.message).to include('Name has already been taken')
      end
    end
  end
end
