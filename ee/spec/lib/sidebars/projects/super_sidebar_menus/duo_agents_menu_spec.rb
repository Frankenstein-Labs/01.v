# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::SuperSidebarMenus::DuoAgentsMenu, feature_category: :duo_agent_platform do
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:user) { build_stubbed(:user) }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

  subject(:menu) { described_class.new(context) }

  before do
    allow(user).to receive(:can?).and_call_original
    allow(user).to receive(:can?).with(:read_ai_catalog_item_consumer, project).and_return(true)
  end

  describe '#configure_menu_items' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_features_enabled, :duo_remote_flows_enabled, :can_manage_ai_flow_triggers,
      :read_flow_permission, :read_mcp_server_permission, :configure_result, :expected_items) do
      true  | true  | false | false | false | true  | [:agents_onboarding, :ai_catalog_agents, :agents_runs]
      true  | true  | true  | true  | false | true  | [:agents_onboarding, :ai_catalog_agents, :ai_flows,
        :ai_flow_triggers, :agents_runs]
      true  | true  | true  | false | false | true  | [:agents_onboarding, :ai_catalog_agents, :ai_flow_triggers,
        :agents_runs]
      true  | false | false | false | false | true  | [:agents_onboarding, :ai_catalog_agents]
      true  | false | true  | true  | false | true  | [:agents_onboarding, :ai_catalog_agents, :ai_flows,
        :ai_flow_triggers]
      true  | false | true  | false | false | true  | [:agents_onboarding, :ai_catalog_agents, :ai_flow_triggers]
      false | true  | false | false | false | false | []
      false | true  | true  | false | false | false | []
      false | true  | true  | true  | false | false | []
      false | false | false | false | false | false | []
      false | false | true  | false | false | false | []
      true  | true  | false | false | true  | true  | [:agents_onboarding, :ai_catalog_agents, :agents_runs,
        :ai_catalog_mcp_servers]
      true  | true  | true  | true  | true  | true  | [:agents_onboarding, :ai_catalog_agents, :ai_flows,
        :ai_flow_triggers, :agents_runs, :ai_catalog_mcp_servers]
      true  | false | false | false | true  | true  | [:agents_onboarding, :ai_catalog_agents,
        :ai_catalog_mcp_servers]
      false | false | false | false | true  | false | []
    end

    with_them do
      before do
        stub_feature_flags(duo_agent_onboarding: true)

        project.project_setting.assign_attributes(
          duo_remote_flows_enabled: duo_remote_flows_enabled,
          duo_features_enabled: duo_features_enabled
        )
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(can_manage_ai_flow_triggers)
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(read_flow_permission)
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(read_flow_permission)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server,
          project).and_return(read_mcp_server_permission)
      end

      it "returns correct configure result" do
        expect(menu.configure_menu_items).to eq(configure_result)
      end

      it "renders expected menu items" do
        expect(menu.renderable_items.size).to eq(expected_items.size)

        if expected_items.any?
          expect(menu.renderable_items.map(&:item_id)).to match_array(expected_items)
        else
          expect(menu.renderable_items).to be_empty
        end
      end
    end
  end

  context 'when current_user is nil' do
    let(:context) { Sidebars::Projects::Context.new(current_user: nil, container: project) }

    it 'returns false' do
      expect(menu.configure_menu_items).to be false
    end
  end

  context 'when user cannot read AI catalog' do
    before do
      stub_feature_flags(ai_catalog_public_explore: false)
      project.project_setting.duo_features_enabled = true
      allow(user).to receive(:can?).with(:read_ai_catalog_item_consumer, project).and_return(false)
    end

    it 'returns false' do
      expect(menu.configure_menu_items).to be false
    end
  end

  describe "when user can only read foundational flows" do
    before do
      stub_feature_flags(ai_catalog_public_explore: true)
      project.project_setting.assign_attributes(
        duo_remote_flows_enabled: true,
        duo_features_enabled: true
      )
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(false)
    end

    it 'shows the flows menu item' do
      expect(menu.renderable_items.map(&:item_id)).to include(:ai_flows)
    end
  end

  describe '#title' do
    it 'returns AI' do
      expect(menu.title).to eq('AI')
    end

    context 'when ai_catalog_public_explore is disabled' do
      before do
        stub_feature_flags(ai_catalog_public_explore: false)
      end

      it 'returns Automate' do
        expect(menu.title).to eq('Automate')
      end
    end
  end

  describe '#sprite_icon' do
    it 'returns correct icon' do
      expect(menu.sprite_icon).to eq('tanuki-ai')
    end
  end

  describe 'agents runs menu item' do
    before do
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_call_original
      allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_call_original
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(false)

      project.project_setting.assign_attributes(duo_remote_flows_enabled: true, duo_features_enabled: true)
      menu.configure_menu_items
    end

    let(:menu_item) { menu.renderable_items.find { |item| item.item_id == :agents_runs } }

    it 'has correct title' do
      expect(menu_item.title).to eq('Sessions')
    end

    it 'has correct link' do
      expect(menu_item.link).to eq("/#{project.full_path}/-/automate/agent-sessions")
    end

    it 'has correct active routes' do
      expect(menu_item.active_routes).to be_nil
    end

    it 'has correct item id' do
      expect(menu_item.item_id).to eq(:agents_runs)
    end
  end

  describe 'flow triggers menu item' do
    context 'when user can manage ai flow triggers' do
      before do
        project.project_setting.duo_features_enabled = true
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(true)
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_call_original
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_call_original
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(false)
        menu.configure_menu_items
      end

      let(:flow_triggers_menu_item) { menu.renderable_items.find { |item| item.item_id == :ai_flow_triggers } }

      it 'has correct title' do
        expect(flow_triggers_menu_item.title).to eq('Triggers')
      end

      it 'has correct link' do
        expect(flow_triggers_menu_item.link).to eq("/#{project.full_path}/-/automate/triggers")
      end

      it 'has correct active routes' do
        expect(flow_triggers_menu_item.active_routes).to be_nil
      end

      it 'has correct item id' do
        expect(flow_triggers_menu_item.item_id).to eq(:ai_flow_triggers)
      end
    end

    context 'when user cannot manage ai flow triggers' do
      before do
        project.project_setting.duo_features_enabled = true
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_call_original
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_call_original
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(false)
        menu.configure_menu_items
      end

      it 'does not render flow triggers menu item' do
        flow_triggers_menu_item = menu.renderable_items.find { |item| item.item_id == :ai_flow_triggers }
        expect(flow_triggers_menu_item).to be_nil
      end
    end
  end

  describe 'flows menu item' do
    before do
      project.project_setting.duo_features_enabled = true
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(true)

      menu.configure_menu_items
    end

    let(:flows_menu_item) { menu.renderable_items.find { |item| item.item_id == :ai_flows } }

    it 'has correct title' do
      expect(flows_menu_item.title).to eq('Flows')
    end

    it 'has correct link' do
      expect(flows_menu_item.link).to eq("/#{project.full_path}/-/automate/flows")
    end

    it 'has correct active routes' do
      expect(flows_menu_item.active_routes).to be_nil
    end

    it 'has correct item id' do
      expect(flows_menu_item.item_id).to eq(:ai_flows)
    end

    context 'when user has read_ai_foundational_flow but not read_ai_catalog_flow permission' do
      before do
        project.project_setting.duo_features_enabled = true
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(true)

        menu.configure_menu_items
      end

      it 'still shows the flows menu item' do
        flows_menu_item = menu.renderable_items.find { |item| item.item_id == :ai_flows }
        expect(flows_menu_item).not_to be_nil
        expect(flows_menu_item.title).to eq('Flows')
      end
    end

    context 'when user has neither read_ai_foundational_flow nor read_ai_catalog_flow permission' do
      let(:configured_menu) { described_class.new(context) }

      before do
        project.project_setting.assign_attributes(duo_features_enabled: true, duo_remote_flows_enabled: false)
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(false)

        configured_menu.configure_menu_items
      end

      it 'does not show the flows menu item' do
        flows_menu_item = configured_menu.renderable_items.find { |item| item.item_id == :ai_flows }
        expect(flows_menu_item).to be_nil
      end
    end
  end

  describe 'onboarding menu item' do
    before do
      stub_feature_flags(duo_agent_onboarding: true)
      project.project_setting.duo_features_enabled = true
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(false)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(false)
      menu.configure_menu_items
    end

    let(:onboarding_menu_item) { menu.renderable_items.find { |item| item.item_id == :agents_onboarding } }

    it 'has correct title' do
      expect(onboarding_menu_item.title).to eq('Onboarding')
    end

    it 'has correct link' do
      expect(onboarding_menu_item.link).to eq("/#{project.full_path}/-/automate/onboarding")
    end

    it 'has correct item id' do
      expect(onboarding_menu_item.item_id).to eq(:agents_onboarding)
    end

    context 'when the feature flag is disabled' do
      let(:fresh_menu) { described_class.new(context) }

      before do
        stub_feature_flags(duo_agent_onboarding: false)
        fresh_menu.configure_menu_items
      end

      it 'does not show the onboarding menu item' do
        expect(fresh_menu.renderable_items.find { |i| i.item_id == :agents_onboarding }).to be_nil
      end
    end

    context 'when user lacks duo_workflow access' do
      let(:fresh_menu) { described_class.new(context) }

      before do
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(false)
        fresh_menu.configure_menu_items
      end

      it 'does not show the onboarding menu item' do
        expect(fresh_menu.renderable_items.find { |i| i.item_id == :agents_onboarding }).to be_nil
      end
    end
  end

  describe 'mcp servers menu item' do
    before do
      project.project_setting.duo_features_enabled = true
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(false)
      allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(false)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(true)

      menu.configure_menu_items
    end

    let(:mcp_servers_menu_item) do
      menu.renderable_items.find { |item| item.item_id == :ai_catalog_mcp_servers }
    end

    it 'has correct title' do
      expect(mcp_servers_menu_item.title).to eq('MCP servers')
    end

    it 'has correct link' do
      expect(mcp_servers_menu_item.link).to eq("/#{project.full_path}/-/automate/mcp-servers")
    end

    it 'has correct active routes' do
      expect(mcp_servers_menu_item.active_routes).to be_nil
    end

    it 'has correct item id' do
      expect(mcp_servers_menu_item.item_id).to eq(:ai_catalog_mcp_servers)
    end

    context 'when user does not have read_ai_catalog_mcp_server permission' do
      let(:configured_menu) { described_class.new(context) }

      before do
        project.project_setting.duo_features_enabled = false
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(false)

        configured_menu.configure_menu_items
      end

      it 'does not show the mcp servers menu item' do
        item = configured_menu.renderable_items.find { |i| i.item_id == :ai_catalog_mcp_servers }
        expect(item).to be_nil
      end
    end
  end

  describe 'Feature Library metadata' do
    before do
      project.project_setting.assign_attributes(duo_remote_flows_enabled: true, duo_features_enabled: true)
      allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
      allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(true)
      allow(user).to receive(:can?).with(:read_ai_catalog_flow, project).and_return(true)
      allow(user).to receive(:can?).with(:read_ai_foundational_flow, project).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, project).and_return(true)
    end

    it 'gives every renderable item a library_icon', :aggregate_failures do
      menu.configure_menu_items
      serialized = menu.renderable_items.map(&:serialize_for_super_sidebar)

      expect(serialized).to be_present
      expect(serialized).to all(include(:library_icon))
    end
  end
end
