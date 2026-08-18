# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Resolvers::Epics::ChildrenResolver', feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be_with_refind(:group) { create(:group, :private) }
  let_it_be(:other_group) { create(:group, :private) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:base_epic) { create(:epic, group: group) }
  let_it_be_with_reload(:confidential_base_epic) { create(:epic, :confidential, group: group) }
  let_it_be(:child1) { create(:epic, group: group, parent: base_epic) }
  let_it_be(:child2) { create(:epic, group: other_group, parent: base_epic) }
  let_it_be(:closed_child) { create(:epic, :closed, group: group, parent: base_epic) }
  let_it_be(:confidential_child1) { create(:epic, :confidential, group: group, parent: confidential_base_epic) }
  let_it_be(:confidential_child2) { create(:epic, :confidential, group: other_group, parent: confidential_base_epic) }

  before do
    stub_licensed_features(epics: true)
  end

  describe '#resolve' do
    it 'returns nothing when feature disabled' do
      stub_licensed_features(epics: false)

      expect(resolve_children(base_epic)).to be_empty
    end

    it 'does not return child epics when user has no access to group epics' do
      expect(resolve_children(base_epic)).to be_empty
    end

    context 'when user has access to the base epic group' do
      before do
        group.add_reporter(current_user)
      end

      it 'returns only accessible children' do
        expect(resolve_children(base_epic)).to contain_exactly(child1, closed_child)
      end

      it 'returns only accessible confidential children' do
        expect(resolve_children(confidential_base_epic)).to contain_exactly(confidential_child1)
      end

      it 'calls the correct finder' do
        allow_next_instance_of(Epics::CrossHierarchyChildrenFinder) do |finder|
          allow(finder).to receive(:execute).and_call_original
        end

        resolve_children(base_epic)

        expect_any_instance_of(Epics::CrossHierarchyChildrenFinder) do |finder|
          expect(finder).to receive(:execute)
        end
      end

      it 'returns only open children when state is open' do
        expect(resolve_children(base_epic, { state: 'opened' })).to contain_exactly(child1)
        expect(resolve_children(base_epic, { state: 'opened' })).not_to include(closed_child)
      end

      it 'returns only closed children when state is closed' do
        expect(resolve_children(base_epic, { state: 'closed' })).to contain_exactly(closed_child)
        expect(resolve_children(base_epic, { state: 'closed' })).not_to include(child1)
      end

      context 'when user has access to all child epics groups' do
        before do
          other_group.add_reporter(current_user)
        end

        it 'returns all children' do
          expect(resolve_children(base_epic)).to contain_exactly(child1, child2, closed_child)
        end

        it 'returns confidential children' do
          expect(resolve_children(confidential_base_epic))
            .to contain_exactly(confidential_child1, confidential_child2)
        end

        context 'with subgroups' do
          let_it_be(:sub_group) { create(:group, :private, parent: group) }
          let_it_be(:child3)    { create(:epic, group: sub_group, parent: base_epic) }

          before do
            sub_group.add_developer(current_user)
          end

          it 'returns all children' do
            expect(resolve_children(base_epic)).to match_array([child3, child2, child1, closed_child])
          end
        end
      end
    end

    context 'when user is a guest in the base epic group' do
      before do
        group.add_guest(current_user)
      end

      it 'returns accessible non confidential children' do
        expect(resolve_children(base_epic)).to contain_exactly(child1, closed_child)
      end

      it 'does not return confidential children' do
        expect(resolve_children(confidential_base_epic)).to be_empty
      end
    end
  end

  def resolve_children(object, args = {}, context = { current_user: current_user })
    resolve(::Resolvers::Epics::ChildrenResolver, obj: object, args: args, ctx: context)
  end
end
