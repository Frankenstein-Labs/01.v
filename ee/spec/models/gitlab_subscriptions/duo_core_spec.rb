# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoCore, feature_category: :'add-on_provisioning' do
  describe '.any_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.any_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be(false) }
    end
  end
end
