# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::RepositoryMenu do
  let_it_be(:project) { create(:project, :small_repo) }

  let(:user) { project.first_owner }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project, current_ref: 'master') }

  describe 'File Locks' do
    subject { described_class.new(context).renderable_items.index { |e| e.item_id == :file_locks } }

    context 'when licensed feature file locks is not enabled' do
      it 'does not include file locks menu item' do
        stub_licensed_features(file_locks: false)

        is_expected.to be_nil
      end
    end

    context 'when licensed feature file locks is enabled' do
      it 'includes file locks menu item' do
        stub_licensed_features(file_locks: true)

        is_expected.to be_present
      end
    end
  end

  describe 'File Locks Feature Library metadata' do
    subject(:file_locks_item) do
      described_class.new(context).renderable_items.find { |e| e.item_id == :file_locks }
    end

    context 'when file_locks is licensed' do
      before do
        stub_licensed_features(file_locks: true)
      end

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = file_locks_item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end
  end
end
