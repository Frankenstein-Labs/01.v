# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UpgradeUrlBuilder, feature_category: :subscription_management do
  describe '#build' do
    let(:subscription_portal_url) { Gitlab::Routing.url_helpers.subscription_portal_url }
    let_it_be(:namespace) { create(:group) }

    subject(:builder) { described_class.new(plan_id: 'plan-id', namespace: namespace) }

    context 'when the namespace can be upgraded' do
      before do
        allow(namespace).to receive(:upgradable?).and_return(true)
      end

      it 'generates the customers dot upgrade URL' do
        expect(builder.build)
          .to eq "#{subscription_portal_url}/gitlab/namespaces/#{namespace.id}/upgrade/plan-id"
      end

      it 'includes any additional params in the URL' do
        expect(builder.build(source: 'source'))
          .to eq "#{subscription_portal_url}/gitlab/namespaces/#{namespace.id}/upgrade/plan-id?source=source"
      end
    end

    context 'when the namespace cannot be upgraded' do
      before do
        allow(namespace).to receive(:upgradable?).and_return(false)
      end

      it 'falls back to the standard purchase URL' do
        expect(builder.build)
          .to eq "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&plan_id=plan-id"
      end
    end

    context 'when the plan is not supplied' do
      subject(:builder) { described_class.new(plan_id: nil, namespace: namespace) }

      it 'falls back to the standard purchase URL' do
        allow(namespace).to receive(:upgradable?).and_return(true)

        expect(builder.build).to eq Gitlab::Routing.url_helpers.promo_pricing_url
      end
    end

    context 'when the namespace is not supplied' do
      subject(:builder) { described_class.new(plan_id: 'plan-id', namespace: nil) }

      it 'falls back to the standard purchase URL' do
        expect(builder.build).to eq "/-/subscriptions/groups/new?plan_id=plan-id"
      end
    end
  end
end
