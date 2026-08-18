# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::YourWork::Menus::OrbitMenu, feature_category: :knowledge_graph do
  let_it_be(:user) { build_stubbed(:user) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }
  let(:menu) { described_class.new(context) }

  describe '#title' do
    it 'returns Orbit' do
      expect(menu.title).to eq('Orbit')
    end
  end

  describe '#sprite_icon' do
    it 'returns orbit' do
      expect(menu.sprite_icon).to eq('orbit')
    end
  end

  describe '#render?' do
    before do
      stub_config(knowledge_graph: { 'enabled' => true })
      stub_feature_flags(knowledge_graph: true)
    end

    it 'returns true when feature flag is enabled and service is configured' do
      expect(menu.render?).to be(true)
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(knowledge_graph: false)
      end

      it 'returns false' do
        expect(menu.render?).to be(false)
      end
    end

    context 'when service is not configured' do
      before do
        stub_config(knowledge_graph: { 'enabled' => false })
      end

      it 'returns false' do
        expect(menu.render?).to be(false)
      end
    end

    context 'when user is nil' do
      let(:context) { Sidebars::Context.new(current_user: nil, container: nil) }

      it 'returns falsey' do
        expect(menu.render?).to be_falsey
      end
    end
  end

  describe '#active_routes' do
    it 'returns the orbit controller' do
      expect(menu.active_routes).to eq({ controller: 'dashboard/orbit' })
    end
  end

  describe '#link' do
    it 'returns the orbit dashboard path' do
      expect(menu.link).to eq('/dashboard/orbit')
    end
  end
end
