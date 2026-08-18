# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoAmazonQ, feature_category: :subscription_management do
  describe '.any_add_on_purchase' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_amazon_q) }
    let_it_be(:organization) { create(:common_organization) }

    subject { described_class.any_add_on_purchase }

    context 'when there is a duo_amazon_q add_on_purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :self_managed, organization: organization, add_on: add_on)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there is an add_on_purchase that is not duo_amazon_q' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_enterprise, organization: organization)
      end

      it { is_expected.to be_nil }
    end

    context 'when there are no add_on_purchases' do
      it { is_expected.to be_nil }
    end
  end
end
