# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::EndOfTrialModalComponent, :aggregate_failures, feature_category: :acquisition do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group, gitlab_subscription: gitlab_subscription) }
  let(:gitlab_subscription) do
    build_stubbed(:gitlab_subscription, :expired_trial, :free)
  end

  let(:can_read_billing) { true }
  let(:recently_expired) { true }
  let(:plans_data) { [Hashie::Mash.new(id: 1, code: ::Plan::PREMIUM)] }
  let(:feature_name) { 'end_of_trial_modal' }

  let(:monthly_commitment_total_credits) { 0 }

  before do
    allow(Ability).to receive(:allowed?).with(user, :read_billing, group).and_return(can_read_billing)
    allow(::GitlabSubscriptions::Trials).to receive(:recently_expired?).with(group).and_return(recently_expired)

    allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
      allow(instance).to receive(:execute).and_return(plans_data)
    end

    allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |instance|
      allow(instance).to receive(:execute).and_return(
        ServiceResponse.success(payload: { total_credits: monthly_commitment_total_credits })
      )
    end
  end

  subject(:component) { render_inline(described_class.new(user: user, namespace: group)) && page }

  it { is_expected.not_to have_css('#js-end-of-trial-modal') }

  context 'when saas_gitlab_com_subscriptions feature is available', :saas_gitlab_com_subscriptions do
    context 'when owner' do
      context 'when recently expired group' do
        context 'when not dismissed' do
          context 'when CDot returns plans data' do
            let(:data_attributes) do
              ::Gitlab::Json.generate({
                featureName: feature_name,
                groupId: group.id,
                groupName: group.name,
                explorePlansPath: group_billings_path(group),
                upgradeUrl: GitlabSubscriptions::PurchaseUrlBuilder.new(
                  plan_id: plans_data.first.id,
                  namespace: group
                ).build,
                purchaseCreditsUrl: ::Gitlab::Routing.url_helpers
                  .subscription_portal_gitlab_com_purchase_credits_url(group.id),
                hasMonthlyCreditCommitment: false,
                creditsGeneralizationUi: true
              })
            end

            it 'has expected modal data attributes' do
              is_expected.to have_css("#js-end-of-trial-modal[data-view-model='#{data_attributes}']")
            end

            context 'when credits_generalization_ui flag is disabled' do
              before do
                stub_feature_flags(credits_generalization_ui: false)
              end

              let(:data_attributes_flag_off) do
                ::Gitlab::Json.generate({
                  featureName: feature_name,
                  groupId: group.id,
                  groupName: group.name,
                  explorePlansPath: group_billings_path(group),
                  upgradeUrl: GitlabSubscriptions::PurchaseUrlBuilder.new(
                    plan_id: plans_data.first.id,
                    namespace: group
                  ).build,
                  purchaseCreditsUrl: ::Gitlab::Routing.url_helpers
                    .subscription_portal_gitlab_com_purchase_credits_url(group.id),
                  hasMonthlyCreditCommitment: false,
                  creditsGeneralizationUi: false
                })
              end

              it 'has creditsGeneralizationUi set to false' do
                is_expected.to have_css(
                  "#js-end-of-trial-modal[data-view-model='#{data_attributes_flag_off}']"
                )
              end
            end

            context 'when namespace has a monthly credit commitment' do
              let(:monthly_commitment_total_credits) { 100 }

              let(:data_attributes_with_commitment) do
                ::Gitlab::Json.generate({
                  featureName: feature_name,
                  groupId: group.id,
                  groupName: group.name,
                  explorePlansPath: group_billings_path(group),
                  upgradeUrl: GitlabSubscriptions::PurchaseUrlBuilder.new(
                    plan_id: plans_data.first.id,
                    namespace: group
                  ).build,
                  purchaseCreditsUrl: ::Gitlab::Routing.url_helpers
                    .subscription_portal_gitlab_com_purchase_credits_url(group.id),
                  hasMonthlyCreditCommitment: true,
                  creditsGeneralizationUi: true
                })
              end

              it 'has hasMonthlyCreditCommitment set to true' do
                is_expected.to have_css(
                  "#js-end-of-trial-modal[data-view-model='#{data_attributes_with_commitment}']"
                )
              end
            end

            context 'when FetchMonthlyCommitmentService raises an error' do
              before do
                allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |instance|
                  allow(instance).to receive(:execute).and_raise(StandardError)
                end
              end

              it 'treats commitment as zero' do
                is_expected
                  .to have_css("#js-end-of-trial-modal[data-view-model*='\"hasMonthlyCreditCommitment\":false']")
              end
            end
          end

          context 'when CDot does not return plans data' do
            let(:plans_data) { [] }

            it { is_expected.not_to have_css('#js-end-of-trial-modal') }
          end
        end

        context 'when dismissed' do
          before do
            allow(user)
              .to receive(:dismissed_callout_for_group?)
              .with(feature_name: feature_name, group: group)
              .and_return(true)
          end

          it { is_expected.not_to have_css('#js-end-of-trial-modal') }
        end
      end

      context 'when is not recently expired group' do
        let(:recently_expired) { false }

        it { is_expected.not_to have_css('#js-end-of-trial-modal') }
      end
    end

    context 'when not owner' do
      let(:can_read_billing) { false }

      it { is_expected.not_to have_css('#js-end-of-trial-modal') }
    end
  end
end
