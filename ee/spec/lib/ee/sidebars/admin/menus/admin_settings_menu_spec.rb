# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::AdminSettingsMenu, feature_category: :navigation do
  let_it_be(:user) { build(:user, :admin) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  describe 'Menu Items' do
    subject(:items) { described_class.new(context).renderable_items.find { |e| e.item_id == item_id } }

    describe 'Roles and permissions menu', feature_category: :user_management do
      let(:item_id) { :roles_and_permissions }

      it { is_expected.not_to be_present }

      context 'when user can view member roles' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :view_member_roles).and_return(true)
        end

        it { is_expected.to be_present }

        context 'when in SaaS mode', :saas do
          it { is_expected.to be_present }
        end
      end
    end

    describe 'Usage quotas' do
      let(:item_id) { :admin_usage_quotas }

      context 'when the instance is a Dedicated instance' do
        before do
          stub_application_setting(gitlab_dedicated_instance: true)
        end

        it { is_expected.to be_present }

        context 'when in SaaS mode', :saas do
          before do
            stub_application_setting(gitlab_dedicated_instance: false)
          end

          it { is_expected.not_to be_present }
        end
      end
    end

    describe 'Service accounts menu', feature_category: :user_management do
      let(:item_id) { :service_accounts }

      it { is_expected.not_to be_present }

      context 'when user can view service accounts' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :admin_service_accounts).and_return(true)
        end

        it { is_expected.to be_present }

        context 'when in SaaS mode', :saas do
          it { is_expected.not_to be_present }
        end
      end
    end

    describe 'Search', feature_category: :global_search do
      let(:item_id) { :search }

      it { is_expected.to be_present }
    end

    describe 'Work items menu', feature_category: :team_planning do
      let(:item_id) { :work_item_settings }

      it { is_expected.to be_present }

      context 'when on SaaS' do
        before do
          stub_saas_features(namespace_scoped_work_item_types: true)
        end

        it { is_expected.not_to be_present }
      end
    end
  end
end
