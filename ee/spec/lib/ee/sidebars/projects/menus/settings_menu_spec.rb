# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::SettingsMenu, feature_category: :navigation do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }

  let(:user) { project.first_owner }

  let(:show_promotions) { true }
  let(:show_discover_project_security) { true }
  let(:context) do
    Sidebars::Projects::Context.new(current_user: user, container: project, show_promotions: show_promotions,
      show_discover_project_security: show_discover_project_security)
  end

  let(:menu) { described_class.new(context) }

  describe 'Menu items' do
    subject { menu.renderable_items.find { |e| e.item_id == item_id } }

    describe 'General' do
      let(:item_id) { :general }

      describe 'when the user is not an admin' do
        let_it_be(:user) { create(:user) }

        before_all do
          project.add_guest(user)
        end

        before do
          allow(Ability).to receive(:allowed?).and_call_original
        end

        it 'does not include the general menu item' do
          expect(subject).to be_nil
        end

        context 'when the user has the `view_edit_page` ability' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :view_edit_page, project).and_return(true)
          end

          it 'includes the general menu item' do
            expect(subject.title).to eql('General')
          end
        end
      end
    end

    describe 'Work items', feature_category: :team_planning do
      let_it_be_with_reload(:user) { create(:user) }
      let_it_be_with_reload(:project) { create(:project, :in_group) }
      let(:item_id) { :work_items }

      subject(:work_items_menu) { menu.renderable_items.find { |e| e.item_id == item_id } }

      where(:user_role, :configurable_work_item_types_licensed, :expected_result) do
        :owner      | true  | true
        :owner      | false | false
        :maintainer | true  | true
        :maintainer | false | false
        :developer  | true  | false
        :developer  | false | false
        :guest      | true  | false
        :guest      | false | false
      end

      with_them do
        before do
          assign_user_role(user, user_role, project)
          stub_licensed_features(configurable_work_item_types: configurable_work_item_types_licensed)
        end

        it 'controls menu visibility based on user role and feature licensing' do
          expected_result ? expect(work_items_menu).to(be_present) : expect(work_items_menu).not_to(be_present)
        end
      end
    end

    describe 'Service accounts' do
      let(:item_id) { :service_accounts }

      context 'when user is project owner' do
        before do
          menu.configure_menu_items
        end

        it 'includes the service accounts menu item' do
          expect(subject.title).to eql('Service accounts')
        end
      end

      context 'when user is project maintainer' do
        let_it_be(:maintainer_user) { create(:user) }
        let(:user) { maintainer_user }
        let(:menu) { described_class.new(context) }

        before_all do
          project.add_maintainer(maintainer_user)
        end
        before do
          menu.configure_menu_items
        end

        it 'includes the service accounts menu item' do
          expect(subject.title).to eql('Service accounts')
        end
      end

      context 'when user does not have permission' do
        let_it_be(:non_owner_user) { create(:user) }
        let(:user) { non_owner_user }
        let(:menu) { described_class.new(context) }

        before_all do
          project.add_developer(non_owner_user)
        end

        before do
          menu.configure_menu_items
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe 'Custom Roles' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, :in_group) }

    let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

    subject(:menu_items) { menu.renderable_items }

    before do
      stub_licensed_features(custom_roles: true)
    end

    where(:ability, :menu_item) do
      :admin_cicd_variables          | 'CI/CD'
      :admin_push_rules              | 'Repository'
      :admin_protected_branch        | 'Repository'
      :admin_protected_environments  | 'CI/CD'
      :admin_runners                 | 'CI/CD'
      :manage_deploy_tokens          | 'Repository'
      :manage_merge_request_settings | 'Merge requests'
      :manage_project_access_tokens  | 'Access tokens'
      :admin_integrations            | 'Integrations'
      :admin_web_hook                | 'Webhooks'
    end

    with_them do
      describe "when the user has the `#{params[:ability]}` custom ability" do
        let!(:role) { create(:member_role, :guest, ability, namespace: project.group) }
        let!(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }

        it { is_expected.to include(have_attributes(title: menu_item)) }
      end
    end
  end

  def assign_user_role(user, user_role, project)
    case user_role
    when :guest then project.add_guest(user)
    when :developer then project.add_developer(user)
    when :maintainer then project.add_maintainer(user)
    when :owner then project.add_owner(user)
    end
  end

  describe 'Feature Library metadata' do
    it 'gives every renderable item the settings library_icon' do
      serialized = menu.renderable_items.map(&:serialize_for_super_sidebar)

      expect(serialized).to all(include(library_icon: 'settings'))
    end
  end
end
