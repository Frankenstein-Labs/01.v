# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Services::UpdateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be_with_reload(:service) do
    create(:cd_service, application: application, name: 'old-name', description: 'old description')
  end

  let_it_be(:current_user) { create(:user) }

  let(:params) { { name: 'new-name', description: 'new description' } }

  subject(:result) do
    described_class.new(service, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the updated service' do
      expect(result).to be_success
      expect(result.payload[:service]).to eq(service)
      expect(service.reload).to have_attributes(
        name: 'new-name',
        description: 'new description'
      )
    end

    context 'when only some attributes are provided' do
      let(:params) { { description: 'only description' } }

      it 'updates only the provided attributes' do
        expect(result).to be_success
        expect(service.reload).to have_attributes(
          name: 'old-name',
          description: 'only description'
        )
      end
    end

    context 'when name is blank' do
      let(:params) { { name: '' } }

      it 'does not update the service and returns the error' do
        expect(result).to be_error
        expect(result.message).to include("Name can't be blank")
        expect(service.reload.name).to eq('old-name')
      end
    end

    context 'when name is already taken in the application' do
      before do
        create(:cd_service, application: application, name: 'new-name')
      end

      it 'does not update the service and returns the error' do
        expect(result).to be_error
        expect(result.message).to include('Name has already been taken')
        expect(service.reload.name).to eq('old-name')
      end
    end
  end
end
