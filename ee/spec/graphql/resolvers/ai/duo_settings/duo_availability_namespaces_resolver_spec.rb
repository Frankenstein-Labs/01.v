# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::DuoSettings::DuoAvailabilityNamespacesResolver, feature_category: :ai_abstraction_layer do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:parent) { create(:group, name: 'parent') }
  let_it_be_with_reload(:child) { create(:group, name: 'child', parent: parent) }
  let_it_be_with_reload(:grandchild) { create(:group, name: 'grandchild', parent: child) }

  let(:current_user) { admin }
  let(:args) { {} }

  subject(:result) do
    resolve(
      described_class,
      ctx: { current_user: current_user },
      args: args,
      arg_style: :internal
    )
  end

  def nodes
    result.items
  end

  describe '#resolve' do
    context 'when the current user is not an admin' do
      let(:current_user) { user }

      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(::Gitlab::Graphql::Errors::ResourceNotAvailable) do
          result
        end
      end
    end

    context 'when the current user is an admin', :enable_admin_mode do
      it 'returns all groups presented' do
        expect(nodes.map(&:full_path)).to include(parent.full_path, child.full_path, grandchild.full_path)
      end

      context 'when scoped to a parent without descendants' do
        let(:args) { { parent_id: parent.to_global_id } }

        it 'returns only direct children' do
          expect(nodes.map(&:group)).to contain_exactly(child)
        end
      end

      context 'when scoped to a parent with descendants' do
        let(:args) { { parent_id: parent.to_global_id, include_descendants: true } }

        it 'returns all descendants' do
          expect(nodes.map(&:group)).to contain_exactly(child, grandchild)
        end
      end

      context 'when an ancestor is admin-locked' do
        before do
          parent.namespace_settings.update!(
            duo_features_enabled: false,
            lock_duo_features_enabled: true,
            admin_locked_duo_features_enabled: true
          )
        end

        it 'flags the introducer as admin-locked and marks descendants as locked-by-ancestor' do
          parent_node = nodes.find { |node| node.group == parent }
          child_node = nodes.find { |node| node.group == child }

          expect(parent_node.admin_locked).to be(true)
          expect(parent_node.locked_by_ancestor).to be_nil

          expect(child_node.admin_locked).to be(false)
          expect(child_node.locked_by_ancestor).to eq(parent)
        end
      end

      context 'with an adminLocked filter' do
        let(:args) { { admin_locked: true } }

        before do
          parent.namespace_settings.update!(
            duo_features_enabled: false,
            lock_duo_features_enabled: true,
            admin_locked_duo_features_enabled: true
          )
        end

        it 'returns only introducer groups' do
          expect(nodes.map(&:group)).to contain_exactly(parent)
        end
      end
    end
  end
end
