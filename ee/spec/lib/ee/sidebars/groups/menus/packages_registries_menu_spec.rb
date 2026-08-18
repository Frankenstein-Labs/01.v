# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::PackagesRegistriesMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }
  let_it_be_with_reload(:group) do
    build(:group, :private).tap do |g|
      g.add_owner(owner)
    end
  end

  let(:user) { owner }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }
  let(:menu) { described_class.new(context) }

  it_behaves_like 'not serializable as super_sidebar_menu_args'

  describe '#render?' do
    context 'when menu has menu items to show' do
      it 'returns true' do
        expect(menu.render?).to be true
      end
    end
  end

  describe 'Menu items' do
    subject(:nav_item) { find_menu(menu, item_id) }

    describe 'Virtual Registry' do
      let(:item_id) { :virtual_registry }
      let(:maven_virtual_registry_available) { false }
      let(:container_virtual_registry_available) { false }

      before do
        allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
          .and_return(maven_virtual_registry_available)
        allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?)
          .and_return(container_virtual_registry_available)
      end

      context 'when user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end

      context 'when user has access' do
        context 'when container & maven virtual registry are unavailable' do
          it { is_expected.to be_nil }
        end

        context 'when maven virtual registry is available' do
          let(:maven_virtual_registry_available) { true }

          it { is_expected.not_to be_nil }

          it 'carries Feature Library metadata', :aggregate_failures do
            serialized = nav_item.serialize_for_super_sidebar

            expect(serialized).to include(:description, :library_icon)
          end
        end

        context 'when container virtual registry is available' do
          let(:container_virtual_registry_available) { true }

          it { is_expected.not_to be_nil }
        end
      end
    end
  end

  private

  def find_menu(menu, item)
    menu.renderable_items.find { |i| i.item_id == item }
  end
end
