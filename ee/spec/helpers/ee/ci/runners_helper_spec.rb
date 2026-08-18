# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::Ci::RunnersHelper, feature_category: :fleet_visibility do
  let_it_be_with_refind(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace, owner: user) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#admin_runners_app_data' do
    subject(:data_attributes) { helper.admin_runners_app_data }

    it 'has no runner_dashboard_path if runner_performance_insights feature is not licensed' do
      expect(data_attributes[:runner_dashboard_path]).to be_nil
    end

    context 'when runner_performance_insights feature is licensed' do
      let(:expected_path) { ::Gitlab::Routing.url_helpers.dashboard_admin_runners_path }

      before do
        stub_licensed_features(runner_performance_insights: true)
      end

      it 'returns dashboard path' do
        expect(data_attributes[:runner_dashboard_path]).to eq expected_path
      end
    end
  end

  describe '#group_runners_data_attributes' do
    let_it_be(:group) { create(:group) }

    subject(:data_attributes) { helper.group_runners_data_attributes(group) }

    it 'has no runner_dashboard_path if runner_performance_insights_for_namespace feature is not licensed' do
      expect(data_attributes[:runner_dashboard_path]).to be_nil
    end

    context 'when runner_performance_insights_for_namespace feature is licensed' do
      let(:expected_path) { ::Gitlab::Routing.url_helpers.dashboard_group_runners_path(group) }

      before do
        stub_licensed_features(runner_performance_insights_for_namespace: [group])
      end

      it 'returns dashboard path' do
        expect(data_attributes[:runner_dashboard_path]).to eq expected_path
      end
    end
  end

  shared_examples_for 'minutes notification' do
    let(:show_warning) { true }
    let(:context_level) { project }
    let(:threshold) { double('Ci::Minutes::Notification', show_callout?: show_warning) }

    before do
      allow(::Ci::Minutes::Notification).to receive(:new).and_return(threshold)
    end

    context 'with a project and namespace' do
      context 'without purchases_additional_minutes feature' do
        let(:saas_feature_enabled) { false }

        it { is_expected.to be_falsey }
      end

      context 'when on dot com' do
        it { is_expected.to be_truthy }

        context 'without a persisted project passed' do
          let(:project) { build(:project) }
          let(:context_level) { namespace }

          it { is_expected.to be_truthy }
        end

        context 'without a persisted namespace passed' do
          let(:namespace) { build(:namespace) }

          it { is_expected.to be_truthy }
        end

        context 'with neither a project nor a namespace' do
          let(:project) { build(:project) }
          let(:namespace) { build(:namespace) }

          it { is_expected.to be_falsey }

          context 'when show_pipeline_minutes_notification_dot? has been called before' do
            it 'does not do all the notification and query work again' do
              expect(threshold).not_to receive(:show_callout?)
              expect(project).to receive(:persisted?).once

              helper.show_pipeline_minutes_notification_dot?(project, namespace)

              expect(subject).to be_falsey
            end
          end
        end

        context 'when show notification is falsey' do
          let(:show_warning) { false }

          it { is_expected.to be_falsey }
        end

        context 'when show_pipeline_minutes_notification_dot? has been called before' do
          it 'does not do all the notification and query work again' do
            expect(threshold).to receive(:show_callout?).once
            expect(project).to receive(:persisted?).once

            helper.show_pipeline_minutes_notification_dot?(project, namespace)

            expect(subject).to be_truthy
          end
        end
      end
    end
  end

  describe '#toggle_shared_runners_settings_data' do
    let(:valid_card) { true }

    subject { helper.toggle_shared_runners_settings_data(project) }

    it 'includes identity_verification_path' do
      expect(subject[:identity_verification_path]).to eq identity_verification_path
    end
  end

  context 'with notifications' do
    let(:saas_feature_enabled) { true }

    describe '.show_buy_pipeline_minutes?' do
      subject { helper.show_buy_pipeline_minutes?(project, namespace) }

      context 'with purchases_additional_minutes: feature' do
        it_behaves_like 'minutes notification' do
          before do
            stub_saas_features(purchases_additional_minutes: saas_feature_enabled)
          end
        end
      end
    end

    describe '.show_pipeline_minutes_notification_dot?' do
      subject { helper.show_pipeline_minutes_notification_dot?(project, namespace) }

      before do
        stub_saas_features(purchases_additional_minutes: saas_feature_enabled)
      end

      it_behaves_like 'minutes notification'

      context 'when the notification dot has been acknowledged' do
        before do
          create(:callout, user: user, feature_name: described_class::BUY_PIPELINE_MINUTES_NOTIFICATION_DOT)
          expect(helper).not_to receive(:show_out_of_pipeline_minutes_notification?)
        end

        it { is_expected.to be_falsy }
      end

      context 'when the notification dot has not been acknowledged' do
        before do
          expect(helper).to receive(:show_out_of_pipeline_minutes_notification?).and_return(true)
        end

        it { is_expected.to be_truthy }
      end
    end

    describe '.show_buy_pipeline_with_subtext?' do
      subject { helper.show_buy_pipeline_with_subtext?(project, namespace) }

      before do
        stub_saas_features(purchases_additional_minutes: saas_feature_enabled)
      end

      context 'when the notification dot has not been acknowledged' do
        before do
          expect(helper).not_to receive(:show_out_of_pipeline_minutes_notification?)
        end

        it { is_expected.to be_falsey }
      end

      context 'when the notification dot has been acknowledged' do
        before do
          create(:callout, user: user, feature_name: described_class::BUY_PIPELINE_MINUTES_NOTIFICATION_DOT)
          expect(helper).to receive(:show_out_of_pipeline_minutes_notification?).and_return(true)
        end

        it { is_expected.to be_truthy }
      end
    end
  end
end
