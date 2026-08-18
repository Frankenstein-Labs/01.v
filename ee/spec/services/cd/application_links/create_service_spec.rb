# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationLinks::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { name: 'Payments runbook', url: 'https://runbooks.example.com/payments', link_type: :runbook } }

  subject(:result) do
    described_class.new(parent: application, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the persisted link', :aggregate_failures do
      expect { result }.to change { ::Cd::ApplicationLink.count }.by(1)

      application_link = result.payload[:application_link]
      expect(result).to be_success
      expect(application_link).to be_persisted
      expect(application_link).to have_attributes(
        application: application,
        organization: organization,
        name: 'Payments runbook',
        url: 'https://runbooks.example.com/payments',
        link_type: 'runbook'
      )
    end

    context 'when url is blank' do
      let(:params) { super().merge(url: '') }

      it 'does not create a link and returns the error' do
        expect { result }.not_to change { ::Cd::ApplicationLink.count }
        expect(result).to be_error
        expect(result.message).to include("Url can't be blank")
      end
    end

    context 'when url is not a valid http(s) URL' do
      let(:params) { super().merge(url: 'javascript:alert(1)') }

      it 'does not create a link and returns the error' do
        expect { result }.not_to change { ::Cd::ApplicationLink.count }
        expect(result).to be_error
        expect(result.message).to include('Url is blocked: Only allowed schemes are http, https')
      end
    end

    context 'when url is already taken in the application' do
      before do
        create(:cd_application_link, application: application, url: 'https://runbooks.example.com/payments')
      end

      it 'does not create a link and returns the error' do
        expect { result }.not_to change { ::Cd::ApplicationLink.count }
        expect(result).to be_error
        expect(result.message).to include('Url has already been taken')
      end
    end
  end
end
