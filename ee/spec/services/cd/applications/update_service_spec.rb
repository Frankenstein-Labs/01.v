# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Applications::UpdateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be_with_reload(:application) do
    create(:cd_application, organization: organization, name: 'old-name', description: 'old description')
  end

  let_it_be(:current_user) { create(:user) }

  let(:params) { { name: 'new-name', description: 'new description' } }

  subject(:result) do
    described_class.new(application, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the updated application' do
      expect(result).to be_success
      expect(result.payload[:application]).to eq(application)
      expect(application.reload).to have_attributes(
        name: 'new-name',
        description: 'new description'
      )
    end

    context 'when name is blank' do
      let(:params) { { name: '' } }

      it 'does not update the application and returns the error' do
        expect(result).to be_error
        expect(result.message).to include("Name can't be blank")
        expect(application.reload.name).to eq('old-name')
      end
    end

    context 'when name is already taken in the organization' do
      before do
        create(:cd_application, organization: organization, name: 'new-name')
      end

      it 'does not update the application and returns the error' do
        expect(result).to be_error
        expect(result.message).to include('Name has already been taken')
        expect(application.reload.name).to eq('old-name')
      end
    end
  end
end
