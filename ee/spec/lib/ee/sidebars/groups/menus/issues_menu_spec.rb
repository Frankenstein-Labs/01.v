# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::IssuesMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }

  let(:group) do
    build(:group, :private).tap do |g|
      g.add_owner(owner)
    end
  end

  let(:user) { owner }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group) }

  describe 'Menu Items' do
    subject { described_class.new(context).renderable_items.find { |e| e.item_id == item_id } }

    describe 'Iterations' do
      let(:item_id) { :iterations }
      let(:iterations_enabled) { true }

      before do
        stub_licensed_features(iterations: iterations_enabled)
      end

      context 'when licensed feature iterations is not enabled' do
        let(:iterations_enabled) { false }

        it 'does not include iterations menu item' do
          is_expected.to be_nil
        end
      end

      context 'when licensed feature iterations is enabled' do
        context 'when user can read iterations' do
          it 'includes iterations menu item' do
            is_expected.to be_present
          end
        end

        context 'when user cannot read iterations' do
          let(:user) { nil }

          it 'does not include iterations menu item' do
            is_expected.to be_nil
          end
        end
      end

      it 'contains the iteration cadences link' do
        expect(subject.link).to include "/groups/#{group.full_path}/-/cadences"
      end

      it 'includes iteration and iteration_cadences active routes' do
        expect(subject.active_routes[:path]).to contain_exactly('iterations#index', 'iterations#show', 'iterations#new', 'iteration_cadences#index')
      end

      it 'tags the item as a Premium feature with Feature Library metadata', :aggregate_failures do
        serialized = subject.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end
  end

  describe 'Feature Library metadata' do
    before do
      stub_licensed_features(iterations: true)
    end

    it 'gives every item a description and a unique library_icon', :aggregate_failures do
      serialized = described_class.new(context).renderable_items.map(&:serialize_for_super_sidebar)

      expect(serialized).to all(include(:description, :library_icon))
      icons = serialized.map { |item| item[:library_icon] }
      expect(icons).to match_array(icons.uniq)
    end
  end
end
