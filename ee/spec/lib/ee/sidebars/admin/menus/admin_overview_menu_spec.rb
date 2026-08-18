# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::AdminOverviewMenu, feature_category: :navigation do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:user) { create(:user) }

  subject(:menu) { described_class.new(Sidebars::Context.new(current_user: user, container: nil)) }

  describe '#render?' do
    context 'when user is assigned a custom admin role' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      MemberRole.all_customizable_admin_permission_keys.each do |ability|
        context "with #{ability} ability" do
          before do
            create(:admin_member_role, ability, user: user)
          end

          context 'when application setting :admin_mode is enabled' do
            before do
              stub_application_setting(admin_mode: true)
            end

            context 'when admin mode is on', :enable_admin_mode do
              it { is_expected.to be_render }
            end

            context 'when admin mode is off' do
              it { is_expected.not_to be_render }
            end
          end

          context 'when application setting :admin_mode is disabled' do
            before do
              stub_application_setting(admin_mode: false)
            end

            it { is_expected.to be_render }
          end
        end
      end
    end
  end

  describe "#renderable_items" do
    subject(:menu_items) { menu.renderable_items.map(&:title) }

    where(:custom_ability, :expected_menu_items) do
      :read_admin_users       | [_('Dashboard'), _('Users')]
      :read_admin_monitoring  | [_('Dashboard'), _('Gitaly servers')]
      :read_admin_groups      | [_('Dashboard'), _('Groups')]
      :read_admin_projects    | [_('Dashboard'), _('Projects')]
    end

    with_them do
      context 'when user is assigned a custom admin role' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context "with #{params[:custom_ability]}} ability" do
          before do
            create(:admin_member_role, custom_ability, user: user)
          end

          context 'when application setting :admin_mode is enabled' do
            before do
              stub_application_setting(admin_mode: true)
            end

            context 'when admin mode is on', :enable_admin_mode do
              it { is_expected.to match_array(expected_menu_items) }
            end

            context 'when admin mode is off' do
              it { is_expected.to match_array([]) }
            end
          end

          context 'when application setting :admin_mode is disabled' do
            before do
              stub_application_setting(admin_mode: false)
            end

            it { is_expected.to match_array(expected_menu_items) }
          end
        end
      end
    end
  end
end
