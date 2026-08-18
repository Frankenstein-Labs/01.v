# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::SuperSidebarMenus::DuoAgentsMenu, feature_category: :duo_agent_platform do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }

  subject(:menu) { described_class.new(context) }

  before do
    allow(group).to receive(:duo_features_enabled).and_return(true)
  end

  describe '#configure_menu_items' do
    using RSpec::Parameterized::TableSyntax

    where(:read_flow_permission, :read_mcp_server_permission, :configure_result, :expected_items) do
      true  | false | true | [:ai_agents, :ai_flows]
      true  | true  | true | [:ai_agents, :ai_flows, :ai_catalog_mcp_servers]
      false | true  | true | [:ai_agents, :ai_catalog_mcp_servers]
      false | false | true | [:ai_agents]
    end

    with_them do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item_consumer, group).and_return(true)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(read_flow_permission)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow,
          group).and_return(read_flow_permission)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server,
          group).and_return(read_mcp_server_permission)
      end

      it "returns correct configure result" do
        expect(menu.configure_menu_items).to eq(configure_result)
      end

      it "renders expected menu items" do
        expect(menu.renderable_items.size).to eq(expected_items.size)
        expect(menu.renderable_items.map(&:item_id)).to match_array(expected_items)
      end
    end
  end

  context 'when current_user is nil' do
    let(:context) { Sidebars::Groups::Context.new(current_user: nil, container: group) }

    it 'returns false' do
      expect(menu.configure_menu_items).to be false
    end
  end

  context 'when duo_features_enabled is false' do
    before do
      allow(group).to receive(:duo_features_enabled).and_return(false)
    end

    it 'returns false' do
      expect(menu.configure_menu_items).to be false
    end
  end

  context 'when user cannot read AI catalog' do
    before do
      stub_feature_flags(ai_catalog_public_explore: false)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item_consumer, group).and_return(false)
    end

    it 'returns false' do
      expect(menu.configure_menu_items).to be false
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

  describe 'flows menu item' do
    before do
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item_consumer, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, group).and_return(false)

      menu.configure_menu_items
    end

    let(:flows_menu_item) { menu.renderable_items.find { |item| item.item_id == :ai_flows } }

    it 'has correct title' do
      expect(flows_menu_item.title).to eq('Flows')
    end

    it 'has correct link' do
      expect(flows_menu_item.link).to eq("/groups/#{group.full_path}/-/automate/flows")
    end

    it 'has correct active routes' do
      expect(flows_menu_item.active_routes).to be_nil
    end

    it 'has correct item id' do
      expect(flows_menu_item.item_id).to eq(:ai_flows)
    end

    context 'when user has read_ai_foundational_flow but not read_ai_catalog_flow permission' do
      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:read_ai_catalog_flow, group).and_return(false)
        allow(user).to receive(:can?).with(:read_ai_foundational_flow, group).and_return(true)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, group).and_return(false)

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
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, group).and_return(false)

        configured_menu.configure_menu_items
      end

      it 'does not show the flows menu item' do
        flows_menu_item = configured_menu.renderable_items.find { |item| item.item_id == :ai_flows }
        expect(flows_menu_item).to be_nil
      end
    end
  end

  describe 'mcp servers menu item' do
    before do
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item_consumer, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(false)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(false)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, group).and_return(true)

      menu.configure_menu_items
    end

    let(:mcp_servers_menu_item) do
      menu.renderable_items.find { |item| item.item_id == :ai_catalog_mcp_servers }
    end

    it 'has correct title' do
      expect(mcp_servers_menu_item.title).to eq('MCP servers')
    end

    it 'has correct link' do
      expect(mcp_servers_menu_item.link).to eq("/groups/#{group.full_path}/-/automate/mcp-servers")
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
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, group).and_return(false)

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
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item_consumer, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_mcp_server, group).and_return(true)
    end

    it 'gives every renderable item a library_icon', :aggregate_failures do
      menu.configure_menu_items
      serialized = menu.renderable_items.map(&:serialize_for_super_sidebar)

      expect(serialized).to be_present
      expect(serialized).to all(include(:library_icon))
    end
  end
end
