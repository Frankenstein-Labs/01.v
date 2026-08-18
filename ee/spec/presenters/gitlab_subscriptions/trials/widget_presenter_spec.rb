# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::WidgetPresenter, feature_category: :acquisition do
  describe '#attributes' do
    let(:user) { build(:user) }
    let(:current_user) { user }
    let(:current_group) { nil }
    let(:subscriptions_trials_enabled) { false }

    before do
      stub_saas_features(subscriptions_trials: subscriptions_trials_enabled)

      allow(Ability).to receive(:allowed?).and_call_original
    end

    subject { described_class.new(current_group, user: current_user).attributes.keys }

    context 'for Gitlab.com', :saas do
      let(:subscriptions_trials_enabled) { true }
      let(:group) { build(:group, id: non_existing_record_id) }
      let(:current_group) { group }

      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, current_group).and_return(true)
      end

      context 'when eligible for ultimate trial widget' do
        let(:trial_widget_attribute_keys) { [:trial_widget_data_attrs] }

        before do
          build(:gitlab_subscription, :active_trial, :ultimate_trial, namespace: group)
        end

        it { is_expected.to match_array(trial_widget_attribute_keys) }

        context 'when eligible for both duo pro and ultimate trial widget' do
          let(:current_group) { create(:group) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- https://gitlab.com/gitlab-org/gitlab/-/issues/467062

          before do
            build(
              :gitlab_subscription,
              :active_trial, :ultimate_trial,
              namespace: current_group, trial_starts_on: Time.current, trial_ends_on: 60.days.from_now
            )
          end

          it { is_expected.to match_array(trial_widget_attribute_keys) }
        end
      end

      context 'when eligible for duo pro widget' do
        let(:current_group) { create(:group) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- https://gitlab.com/gitlab-org/gitlab/-/issues/467062
        let(:duo_pro_trial_widget_attribute_keys) { [:trial_widget_data_attrs] }

        before do
          build(:gitlab_subscription, :ultimate, namespace: current_group)
          create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: current_group) # rubocop:todo RSpec/FactoryBot/AvoidCreate -- https://gitlab.com/gitlab-org/gitlab/-/issues/467062
        end

        it { is_expected.to match_array(duo_pro_trial_widget_attribute_keys) }
      end

      context 'when eligible for duo enterprise widget' do
        let(:current_group) { build(:group) }
        let(:duo_enterprise_trial_widget_attribute_keys) { [:trial_widget_data_attrs] }
        let(:add_on_purchase) do
          build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active_trial, namespace: current_group)
        end

        before do
          build(:gitlab_subscription, :ultimate, namespace: current_group)

          allow(GitlabSubscriptions::Trials::DuoEnterprise)
            .to receive(:any_add_on_purchase_for_namespace).with(current_group).and_return(add_on_purchase)
        end

        it { is_expected.to match_array(duo_enterprise_trial_widget_attribute_keys) }
      end

      context 'when on premium trial' do
        context 'when group is not eligible for widget' do
          before do
            build(
              :gitlab_subscription,
              :active_trial, :premium_trial, namespace: current_group,
              trial_starts_on: Time.current, trial_ends_on: 60.days.from_now
            )
          end

          it { is_expected.to match_array([]) }
        end
      end

      context 'when not eligible for widget' do
        let(:add_on_purchase) do
          build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active_trial, namespace: current_group)
        end

        before do
          allow(GitlabSubscriptions::Trials::DuoEnterprise)
            .to receive(:any_add_on_purchase_for_namespace).with(current_group).and_return(add_on_purchase)
        end

        context 'when namespace is not present' do
          let(:current_group) { nil }

          it { is_expected.to match_array([]) }
        end

        context 'when subscriptions_trials feature is not available' do
          let(:subscriptions_trials_enabled) { false }

          it { is_expected.to match_array([]) }
        end

        context 'when user is not authorized' do
          let(:current_user) { build(:user) }

          it { is_expected.to match_array([]) }
        end

        context 'when user does not exist' do
          let(:current_user) { nil }

          it { is_expected.to match_array([]) }
        end

        context 'when not eligible for either widget' do
          let(:add_on_purchase) { nil }

          it { is_expected.to match_array([]) }
        end
      end
    end

    context 'for Self-managed' do
      let(:current_group) { nil }

      before do
        allow(License).to receive(:current).and_return(build(:license, :ultimate_trial))
        allow(Ability).to receive(:allowed?).with(user, :admin_all_resources).and_return(true)
      end

      context 'when eligible for self-managed ultimate trial widget' do
        let(:trial_widget_attribute_keys) { [:trial_widget_data_attrs] }

        it { is_expected.to match_array(trial_widget_attribute_keys) }
      end

      context 'when it is a dedicated instance' do
        before do
          stub_application_setting(gitlab_dedicated_instance: true)
        end

        it { is_expected.to match_array([]) }
      end
    end
  end
end
