# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::ExperimentalCommunicationOptInWorker, feature_category: :user_management do
  describe '#perform' do
    subject(:perform) { described_class.new.perform(user.id) }

    let(:organization) { FFaker::Company.name }
    let(:user) { create(:user, company: organization) }

    it 'calls customer dot opt-in API with expected params' do
      expect(::Gitlab::SubscriptionPortal::Client).to receive(:opt_in_lead).with(
        user_id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        email: user.email,
        company_name: organization,
        product_interaction: 'Beta Program Opt In'
      )

      perform
    end
  end
end
