# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::WorkItemsMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }

  let(:group) do
    build(:group, :private).tap do |g|
      g.add_owner(owner)
    end
  end

  let(:context) { Sidebars::Groups::Context.new(current_user: owner, container: group) }

  describe 'Iterations menu item' do
    subject(:iterations_item) { described_class.new(context).renderable_items.find { |e| e.item_id == :iterations } }

    before do
      stub_licensed_features(iterations: iterations_enabled)
    end

    context 'when licensed feature iterations is not enabled' do
      let(:iterations_enabled) { false }

      it { is_expected.to be_nil }
    end

    context 'when licensed feature iterations is enabled' do
      let(:iterations_enabled) { true }

      it { is_expected.to be_present }

      it 'tags the item as a Premium feature with Feature Library metadata', :aggregate_failures do
        serialized = iterations_item.serialize_for_super_sidebar

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
