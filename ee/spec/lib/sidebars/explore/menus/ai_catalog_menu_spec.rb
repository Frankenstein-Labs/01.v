# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Explore::Menus::AiCatalogMenu, feature_category: :navigation do
  let_it_be(:current_user) { build(:user) }
  let_it_be(:user) { build(:user) }

  let(:context) { Sidebars::Context.new(current_user: current_user, container: user) }
  let(:ai_catalog_available) { true }

  subject(:menu_item) { described_class.new(context) }

  before do
    allow(Ai::Catalog).to receive(:feature_available?).and_return(ai_catalog_available)
  end

  describe '#link' do
    it 'matches the expected path pattern' do
      expect(menu_item.link).to match %r{explore/ai-catalog}
    end
  end

  describe '#title' do
    it 'returns the correct title' do
      expect(menu_item.title).to eq 'AI Catalog'
    end
  end

  describe '#sprite_icon' do
    it 'returns the correct icon' do
      expect(menu_item.sprite_icon).to eq 'tanuki-ai'
    end
  end

  describe '#active_routes' do
    it 'returns the correct active routes' do
      expect(menu_item.active_routes).to eq({ controller: ['explore/ai_catalog'] })
    end
  end

  describe '#render?' do
    it 'renders the menu' do
      expect(menu_item.render?).to be(true)
    end

    context 'when AI Catalog is not available for the instance' do
      let(:ai_catalog_available) { false }

      it 'does not render the menu' do
        expect(menu_item.render?).to be(false)
      end
    end
  end
end
