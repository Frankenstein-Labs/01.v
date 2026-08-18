# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::DuoSeatsMetric, feature_category: :service_ping do
  describe 'initialize' do
    context 'when initialized with invalid parameters' do
      it 'raises an ArgumentError for invalid subscription_type' do
        expect do
          described_class.new(time_frame: 'none', options: { subscription_type: 'invalid', seats_type: 'purchased' })
        end.to raise_error(ArgumentError, /Unknown parameters: subscription: invalid/)
      end

      it 'raises an ArgumentError for invalid seats_type' do
        expect do
          described_class.new(time_frame: 'none', options: { subscription_type: 'pro', seats_type: 'invalid' })
        end.to raise_error(ArgumentError, /Unknown parameters: seats:invalid/)
      end

      it 'raises an ArgumentError for both invalid subscription_type and seats_type' do
        expect do
          described_class.new(time_frame: 'none', options: { subscription_type: 'invalid', seats_type: 'invalid' })
        end.to raise_error(ArgumentError, /Unknown parameters: subscription: invalid, seats:invalid/)
      end

      it 'raises an ArgumentError when subscription_type is missing' do
        expect do
          described_class.new(time_frame: 'none', options: { seats_type: 'purchased' })
        end.to raise_error(ArgumentError, /Unknown parameters: subscription:/)
      end

      it 'raises an ArgumentError when seats_type is missing' do
        expect do
          described_class.new(time_frame: 'none', options: { subscription_type: 'pro' })
        end.to raise_error(ArgumentError, /Unknown parameters: seats:/)
      end
    end
  end

  context "when metric type is pro" do
    context 'when there are no active Duo purchases' do
      let(:expected_value) { nil }

      before do
        allow(GitlabSubscriptions::AddOnPurchase)
          .to receive(:for_gitlab_duo_pro)
                .and_return(GitlabSubscriptions::AddOnPurchase.none)
      end

      it_behaves_like 'a correct instrumented metric value',
        { time_frame: 'none', options: { subscription_type: 'pro', seats_type: 'purchased' } }

      it_behaves_like 'a correct instrumented metric value',
        { time_frame: 'none', options: { subscription_type: 'pro', seats_type: 'assigned' } }
    end

    context 'when there are active Duo purchases' do
      let_it_be(:user) { create(:user) }
      let_it_be(:duo_pro_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, quantity: 5)
      end

      before_all do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: duo_pro_purchase
        )
      end

      describe 'purchased seats' do
        let(:expected_value) { 5 }

        it_behaves_like 'a correct instrumented metric value',
          { time_frame: 'none', options: { subscription_type: 'pro', seats_type: 'purchased' } }
      end

      describe 'assigned seats' do
        let(:expected_value) { 1 }

        it_behaves_like 'a correct instrumented metric value',
          { time_frame: 'none', options: { subscription_type: 'pro', seats_type: 'assigned' } }
      end
    end
  end

  context "when metric type is enterprise" do
    context 'when there are no active Duo purchases' do
      let(:expected_value) { nil }

      before do
        allow(GitlabSubscriptions::AddOnPurchase)
          .to receive(:for_duo_enterprise)
                .and_return(GitlabSubscriptions::AddOnPurchase.none)
      end

      it_behaves_like 'a correct instrumented metric value',
        { time_frame: 'none', options: { subscription_type: 'enterprise', seats_type: 'purchased' } }

      it_behaves_like 'a correct instrumented metric value',
        { time_frame: 'none', options: { subscription_type: 'enterprise', seats_type: 'assigned' } }
    end

    context 'when there are active Duo purchases' do
      let_it_be(:user) { create(:user) }

      let_it_be(:duo_enterprise_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, quantity: 3)
      end

      before_all do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: duo_enterprise_purchase
        )
      end

      describe 'purchased seats' do
        let(:expected_value) { 3 }

        it_behaves_like 'a correct instrumented metric value',
          { time_frame: 'none', options: { subscription_type: 'enterprise', seats_type: 'purchased' } }
      end

      describe 'assigned seats' do
        let(:expected_value) { 1 }

        it_behaves_like 'a correct instrumented metric value',
          { time_frame: 'none', options: { subscription_type: 'enterprise', seats_type: 'assigned' } }
      end
    end
  end

  context "when metric type is amazon_q" do
    context 'when there are no active Duo purchases' do
      let(:expected_value) { nil }

      before do
        allow(GitlabSubscriptions::AddOnPurchase)
          .to receive(:for_duo_amazon_q)
          .and_return(GitlabSubscriptions::AddOnPurchase.none)
      end

      it_behaves_like 'a correct instrumented metric value',
        { time_frame: 'none', options: { subscription_type: 'amazon_q', seats_type: 'purchased' } }

      it_behaves_like 'a correct instrumented metric value',
        { time_frame: 'none', options: { subscription_type: 'amazon_q', seats_type: 'assigned' } }
    end

    context 'when there are active Duo purchases' do
      let_it_be(:user) { create(:user) }

      let_it_be(:duo_amazon_q_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_amazon_q, quantity: 7)
      end

      before_all do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: duo_amazon_q_purchase
        )
      end

      describe 'purchased seats' do
        let(:expected_value) { 7 }

        it_behaves_like 'a correct instrumented metric value',
          { time_frame: 'none', options: { subscription_type: 'amazon_q', seats_type: 'purchased' } }
      end

      describe 'assigned seats' do
        let(:expected_value) { 1 }

        it_behaves_like 'a correct instrumented metric value',
          { time_frame: 'none', options: { subscription_type: 'amazon_q', seats_type: 'assigned' } }
      end
    end
  end
end
