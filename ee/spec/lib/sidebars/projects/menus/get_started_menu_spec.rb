# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::GetStartedMenu, feature_category: :onboarding do
  let(:project) { build(:project) }
  let(:learn_gitlab_enabled) { true }
  let(:context) do
    Sidebars::Projects::Context.new(
      current_user: nil,
      container: project,
      learn_gitlab_enabled: learn_gitlab_enabled
    )
  end

  subject(:menu) { described_class.new(context) }

  it 'does not contain any sub menu' do
    expect(menu.has_items?).to be false
  end

  describe '#title' do
    it 'returns the title' do
      expect(menu.title).to eq _('Get started')
    end
  end

  describe '#render?' do
    context 'when learn gitlab is enabled' do
      it 'returns true' do
        expect(menu.render?).to be true
      end
    end

    context 'when learn gitlab is disabled' do
      let(:learn_gitlab_enabled) { false }

      it 'returns false' do
        expect(menu.render?).to be false
      end
    end
  end

  it_behaves_like 'serializable as super_sidebar_menu_args' do
    let(:extra_attrs) do
      {
        item_id: :get_started,
        active_routes: { controller: :get_started },
        sprite_icon: 'bulb',
        super_sidebar_parent: ::Sidebars::StaticMenu
      }
    end
  end
end
