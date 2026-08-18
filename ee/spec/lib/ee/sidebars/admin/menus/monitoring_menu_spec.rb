# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::MonitoringMenu, :enable_admin_mode, feature_category: :navigation do
  using RSpec::Parameterized::TableSyntax

  subject(:menu) do
    described_class.new(Sidebars::Context.new(current_user: user, container: nil))
  end

  let_it_be_with_refind(:user) { create(:user) }

  describe '#render?' do
    context 'with a non-admin user' do
      before do
        stub_licensed_features(admin_audit_log: true, custom_roles: true)
      end

      it { is_expected.not_to be_render }

      context 'with read_admin_monitoring ability' do
        let_it_be(:membership) { create(:admin_member_role, :read_admin_monitoring, user: user) }

        it { is_expected.to be_render }
      end
    end
  end

  describe "#renderable_items" do
    subject(:menu_items) { menu.renderable_items.map(&:title) }

    context 'with a non-admin user' do
      context "when user has `read_admin_monitoring`" do
        let_it_be(:membership) { create(:admin_member_role, :read_admin_monitoring, user: user) }

        where(:data_management_enabled, :geo_enabled, :expected_items) do
          true  | true  | [_('Background migrations'), _('Data management'), _('Health check'), _('System information')]
          true  | false | [_('Background migrations'), _('Health check'), _('System information')]
          false | false | [_('Background migrations'), _('Health check'), _('System information')]
        end

        with_them do
          before do
            stub_licensed_features(admin_audit_log: true, custom_roles: true, data_management: data_management_enabled)
            allow(::Gitlab::Geo).to receive(:enabled?).and_return(geo_enabled)
          end

          it 'includes the expected menu items' do
            is_expected.to match_array(expected_items)
          end
        end
      end
    end

    context 'with admin user' do
      let_it_be(:user) { create(:admin) }

      where(:data_management_enabled, :geo_enabled, :check_menu_item) do
        true  | true  | include(_('Data management'))
        true  | false | exclude(_('Data management'))
        false | false | exclude(_('Data management'))
      end

      with_them do
        before do
          stub_licensed_features(data_management: data_management_enabled)
          allow(::Gitlab::Geo).to receive(:enabled?).and_return(geo_enabled)
        end

        it { is_expected.to check_menu_item }
      end
    end
  end
end
