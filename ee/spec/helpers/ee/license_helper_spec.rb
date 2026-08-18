# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseHelper, feature_category: :subscription_management do
  def stub_default_url_options(host: "localhost", protocol: "http", port: nil, script_name: '')
    url_options = { host: host, protocol: protocol, port: port, script_name: script_name }
    allow(Rails.application.routes).to receive(:default_url_options).and_return(url_options)
  end

  describe '#seats_calculation_message' do
    subject(:method) { seats_calculation_message(license) }

    let(:license) { double('License', 'exclude_guests_from_active_count?' => exclude_guests) }

    context 'and guest are excluded from the active count' do
      let(:exclude_guests) { true }

      it 'returns the message' do
        expect(method).to eq(
          "Users with a Guest role or those who don't belong to a Project or Group will not use a seat from " \
            "your license."
        )
      end
    end

    context 'and guest are NOT excluded from the active count' do
      let(:exclude_guests) { false }

      it 'returns nil' do
        expect(method).to be_blank
      end
    end
  end

  describe '#licensed_users' do
    context 'with a restricted license count' do
      let(:license) do
        double('License', restricted?: { active_user_count: true }, restrictions: { active_user_count: 5 })
      end

      it 'returns a number as string' do
        license = double('License', restricted?: true, restrictions: { active_user_count: 5 })

        expect(licensed_users(license)).to eq '5'
      end
    end

    context 'without a restricted license count' do
      let(:license) { double('License', restricted?: false) }

      it 'returns Unlimited' do
        expect(licensed_users(license)).to eq 'Unlimited'
      end
    end
  end

  describe '#cloud_license_view_data', :enable_admin_mode do
    let(:current_user) { build(:admin) }

    before do
      allow(helper).to receive_messages(
        subscription_portal_manage_url: 'subscriptions_manage_url',
        self_managed_new_trial_url: 'self_managed_new_trial_url',
        current_user: current_user
      )
    end

    context 'when there is a current license' do
      let(:license) { double('License', plan: 'custom plan') }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the data for the view' do
        expect(helper.cloud_license_view_data).to eq(
          {
            has_active_license: 'true',
            groups_count: nil,
            projects_count: nil,
            users_count: nil,
            customers_portal_url: 'subscriptions_manage_url',
            free_trial_path: new_self_managed_trials_path,
            subscription_sync_path: sync_seat_link_admin_license_path,
            license_remove_path: admin_license_path,
            congratulation_svg_path: helper.image_path('illustrations/cloud-check-sm.svg'),
            license_usage_file_path: admin_license_usage_export_path(format: :csv),
            is_admin: 'true',
            settings_add_license_path: general_admin_application_settings_path(anchor: 'js-add-license-toggle'),
            purchase_credits_path: subscription_portal_self_managed_purchase_credits_url
          }
        )
      end

      context 'when the current user is not an admin' do
        it 'returns false for is_admin value' do
          allow(current_user).to receive(:can_admin_all_resources?).and_return(false)

          expect(helper.cloud_license_view_data[:is_admin]).to eq('false')
        end
      end
    end

    context 'when there is no current license' do
      # rubocop:disable RSpec/FactoryBot/AvoidCreate -- uses finders which need db persistence
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:user) { create(:user) }
      # rubocop:enable RSpec/FactoryBot/AvoidCreate

      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'returns the data for the view' do
        expect(helper.cloud_license_view_data).to eq(
          {
            has_active_license: 'false',
            groups_count: 1,
            projects_count: 1,
            users_count: 2,
            customers_portal_url: 'subscriptions_manage_url',
            free_trial_path: new_self_managed_trials_path,
            subscription_sync_path: sync_seat_link_admin_license_path,
            license_remove_path: admin_license_path,
            congratulation_svg_path: helper.image_path('illustrations/cloud-check-sm.svg'),
            license_usage_file_path: admin_license_usage_export_path(format: :csv),
            is_admin: 'true',
            settings_add_license_path: general_admin_application_settings_path(anchor: 'js-add-license-toggle'),
            purchase_credits_path: subscription_portal_self_managed_purchase_credits_url
          }
        )
      end
    end

    context 'when the current user cannot delete licenses' do
      before do
        allow(current_user).to receive(:can?).and_call_original
        allow(current_user).to receive(:can?).with(:delete_license).and_return(false)
      end

      it 'returns the data for the view without the license_remove_path set' do
        expect(helper.cloud_license_view_data).to include(license_remove_path: '')
      end
    end
  end

  describe '#show_promotions?' do
    context 'without a user' do
      subject { helper.show_promotions?(nil) }

      it { is_expected.to be(false) }
    end

    context 'with a user' do
      let_it_be(:selected_user) { build_stubbed(:user) }

      subject { helper.show_promotions?(selected_user) }

      context 'when gitlab_com_subscriptions saas feature available' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it { is_expected.to be(true) }
      end

      context 'when gitlab_com_subscriptions saas feature is not available' do
        it { is_expected.to be(false) }
      end

      context 'on EE' do
        context 'with hide on self managed true' do
          subject { helper.show_promotions?(selected_user, hide_on_self_managed: true) }

          it { is_expected.to be(false) }
        end

        context 'without a valid license' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it { is_expected.to be(true) }
        end

        context 'with a valid license' do
          let_it_be(:license) { build_stubbed(:license) }

          before do
            allow(License).to receive(:current).and_return(license)
          end

          context 'with expired license' do
            before do
              allow(license).to receive(:expired?).and_return(true)
            end

            it { is_expected.to be(true) }
          end

          context 'with non expired license' do
            before do
              allow(license).to receive(:expired?).and_return(false)
            end

            it { is_expected.to be(false) }
          end
        end
      end
    end
  end
end
