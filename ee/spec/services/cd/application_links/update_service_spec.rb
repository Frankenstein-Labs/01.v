# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationLinks::UpdateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:current_user) { create(:user) }

  let_it_be_with_reload(:application_link) do
    create(:cd_application_link, application: application,
      name: 'Old runbook', url: 'https://old.example.com', link_type: :runbook)
  end

  let(:params) { { name: 'Payments dashboard', url: 'https://dash.example.com', link_type: :dashboard } }

  subject(:result) do
    described_class.new(application_link, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'updates the link and returns a success response', :aggregate_failures do
      expect(result).to be_success
      expect(result.payload[:application_link]).to have_attributes(
        name: 'Payments dashboard',
        url: 'https://dash.example.com',
        link_type: 'dashboard'
      )
      expect(application_link.reload).to have_attributes(
        name: 'Payments dashboard',
        url: 'https://dash.example.com',
        link_type: 'dashboard'
      )
    end

    context 'when the url is not a valid http(s) URL' do
      let(:params) { super().merge(url: 'javascript:alert(1)') }

      it 'does not update the link and returns the error', :aggregate_failures do
        expect(result).to be_error
        expect(result.message).to include('Url is blocked: Only allowed schemes are http, https')
        expect(application_link.reload.url).to eq('https://old.example.com')
      end
    end
  end
end
