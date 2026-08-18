# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationLinks::DeleteService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:current_user) { create(:user) }

  let!(:application_link) { create(:cd_application_link, application: application) }

  subject(:result) do
    described_class.new(application_link, current_user: current_user).execute
  end

  describe '#execute' do
    it 'destroys the link and returns a success response', :aggregate_failures do
      expect { result }.to change { ::Cd::ApplicationLink.count }.by(-1)
      expect(result).to be_success
      expect(result.payload[:application_link]).to eq(application_link)
    end

    context 'when the link cannot be destroyed' do
      before do
        allow(application_link).to receive_messages(
          destroy: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Cannot delete the link'])
        )
      end

      it 'does not destroy the link and returns the error', :aggregate_failures do
        expect { result }.not_to change { ::Cd::ApplicationLink.count }
        expect(result).to be_error
        expect(result.message).to eq(['Cannot delete the link'])
        expect(result.payload[:application_link]).to eq(application_link)
      end
    end
  end
end
