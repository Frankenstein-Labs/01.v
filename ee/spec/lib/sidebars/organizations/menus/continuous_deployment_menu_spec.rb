# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Organizations::Menus::ContinuousDeploymentMenu, feature_category: :continuous_delivery do
  let_it_be(:organization) { build_stubbed(:organization) }
  let_it_be(:user) { build_stubbed(:user) }
  let(:context) { Sidebars::Context.new(current_user: user, container: organization) }

  subject(:menu) { described_class.new(context) }

  describe '#configure_menu_items' do
    context 'when ai_native_deploy feature flag is enabled and current_user is present' do
      it 'returns true' do
        expect(menu.configure_menu_items).to be true
      end
    end

    context 'when ai_native_deploy feature flag is disabled' do
      before do
        stub_feature_flags(ai_native_deploy: false)
      end

      it 'returns false' do
        expect(menu.configure_menu_items).to be false
      end
    end

    context 'when current_user is nil' do
      let(:context) { Sidebars::Context.new(current_user: nil, container: organization) }

      it 'returns false' do
        expect(menu.configure_menu_items).to be false
      end
    end
  end

  describe '#title' do
    it 'returns Deploy' do
      expect(menu.title).to eq('Deploy')
    end
  end

  describe '#sprite_icon' do
    it 'returns correct icon' do
      expect(menu.sprite_icon).to eq('deployments')
    end
  end

  describe '#pick_into_super_sidebar?' do
    it 'returns true' do
      expect(menu.pick_into_super_sidebar?).to be true
    end
  end

  describe 'applications menu item' do
    before do
      menu.configure_menu_items
    end

    let(:applications_menu_item) { menu.renderable_items.find { |item| item.item_id == :deploy_applications } }

    it 'has correct attributes', :aggregate_failures do
      expect(applications_menu_item.title).to eq('Applications')
      expect(applications_menu_item.link).to eq("/o/#{organization.path}/-/deploy/applications")
      expect(applications_menu_item.active_routes).to eq(page: "/o/#{organization.path}/-/deploy/applications")
      expect(applications_menu_item.item_id).to eq(:deploy_applications)
    end
  end

  describe 'environments menu item' do
    before do
      menu.configure_menu_items
    end

    let(:environments_menu_item) { menu.renderable_items.find { |item| item.item_id == :deploy_environments } }

    it 'has correct attributes', :aggregate_failures do
      expect(environments_menu_item.title).to eq('Environments')
      expect(environments_menu_item.link).to eq("/o/#{organization.path}/-/deploy/environments")
      expect(environments_menu_item.active_routes).to eq(page: "/o/#{organization.path}/-/deploy/environments")
      expect(environments_menu_item.item_id).to eq(:deploy_environments)
    end
  end
end
