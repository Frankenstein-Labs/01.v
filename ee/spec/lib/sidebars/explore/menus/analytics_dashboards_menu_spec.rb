# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Explore::Menus::AnalyticsDashboardsMenu, feature_category: :navigation do
  let_it_be(:current_user) { build_stubbed(:user) }

  let(:context) { Sidebars::Context.new(current_user: current_user, container: nil) }

  subject(:menu_item) { described_class.new(context) }

  describe '#link' do
    it 'matches the expected path pattern' do
      expect(menu_item.link).to match %r{explore/analytics_dashboards}
    end
  end

  describe '#title' do
    it 'returns the correct title' do
      expect(menu_item.title).to eq 'Analytics dashboards'
    end
  end

  describe '#sprite_icon' do
    it 'returns the correct icon' do
      expect(menu_item.sprite_icon).to eq 'chart'
    end
  end

  describe '#active_routes' do
    it 'returns the correct active routes' do
      expect(menu_item.active_routes).to eq({ controller: ['explore/analytics_dashboards'] })
    end
  end

  describe '#render?' do
    it 'renders the menu' do
      expect(menu_item.render?).to be(true)
    end

    context 'when the explore_analytics_dashboards feature flag is disabled' do
      before do
        stub_feature_flags(explore_analytics_dashboards: false)
      end

      it 'does not render the menu' do
        expect(menu_item.render?).to be(false)
      end
    end
  end
end
