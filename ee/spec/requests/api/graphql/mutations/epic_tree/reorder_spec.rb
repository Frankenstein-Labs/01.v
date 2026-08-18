# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an epic tree', feature_category: :portfolio_management do
  include GraphqlHelpers
  include LegacyEpicsHelper

  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:private_project) { create(:project, :private, group: private_group) }
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:base_epic) { create(:epic, group: group) }
  let_it_be(:epic1) { create(:epic, group: group, parent: base_epic, relative_position: 10) }
  let_it_be(:epic2) { create(:epic, group: group, parent: base_epic, relative_position: 20) }
  let_it_be(:issue1) { create(:issue, project: project) }
  let_it_be(:issue2) { create(:issue, project: project) }
  let_it_be(:private_issue) { create(:issue, project: private_project) }
  let_it_be(:epic_issue1) { create(:epic_issue, epic: base_epic, issue: issue1, relative_position: 10) }
  let_it_be_with_refind(:epic_issue2) { create(:epic_issue, epic: base_epic, issue: issue2, relative_position: 20) }
  let_it_be(:epic_issue3) { create(:epic_issue, epic: base_epic, issue: private_issue, relative_position: 30) }

  let(:mutation) do
    graphql_mutation(:epic_tree_reorder, variables)
  end

  let(:relative_position) { :after }
  let(:new_parent_id) { nil }
  let(:variables) do
    {
      base_epic_id: GitlabSchema.id_from_object(base_epic).to_s,
      moved: {
        id: GitlabSchema.id_from_object(epic2).to_s,
        adjacent_reference_id: GitlabSchema.id_from_object(epic1).to_s,
        relative_position: relative_position,
        new_parent_id: new_parent_id
      }
    }
  end

  def mutation_response
    graphql_mutation_response(:epic_tree_reorder)
  end

  shared_examples 'a mutation that does not update the tree' do
    it 'does not change relative_positions' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(epic1.reload.relative_position).to eq(10)
      expect(epic2.reload.relative_position).to eq(20)
      expect(epic_issue1.reload.relative_position).to eq(10)
      expect(epic_issue2.reload.relative_position).to eq(20)
    end
  end

  context 'when epics and subepics features are enabled' do
    before do
      stub_licensed_features(epics: true, subepics: true)
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that does not update the tree'

      it 'returns the error message' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to contain_exactly('You don\'t have permissions to move the objects.')
      end

      context 'when user cannot reorder issue' do
        before do
          group.add_guest(current_user)
          variables[:moved][:id] = GitlabSchema.id_from_object(epic_issue3).to_s
          variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(epic_issue1).to_s
        end

        it_behaves_like 'a mutation that does not update the tree'

        it 'returns the error message' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['errors']).to contain_exactly('You don\'t have permissions to move the objects.')
        end
      end

      context 'when user cannot reorder adjacent reference' do
        before do
          group.add_guest(current_user)
          variables[:moved][:id] = GitlabSchema.id_from_object(epic_issue2).to_s
          variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(epic_issue3).to_s
        end

        it_behaves_like 'a mutation that does not update the tree'

        it 'returns the error message' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['errors']).to contain_exactly('You don\'t have permissions to move the objects.')
        end
      end
    end

    context 'when the user has permission' do
      context 'when moving an epic' do
        before do
          group.add_guest(current_user)
        end

        context 'when moving an epic is successful' do
          it 'updates the epics relative positions' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(epic1.reload.relative_position).to be > epic2.reload.relative_position
          end

          it 'returns nil in errors' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['array']).to be_nil
          end

          context 'when a new_parent_id is provided' do
            let(:new_parent_id) { GitlabSchema.id_from_object(base_epic).to_s }
            let_it_be(:other_epic) { create(:epic, group: group) }
            let_it_be(:epic2) { create(:epic, group: group, parent: other_epic, relative_position: 20) }

            it 'updates the epics relative positions and updates the parent' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(epic1.reload.relative_position).to be > epic2.reload.relative_position
              expect(epic2.parent).to eq base_epic
            end

            it 'returns nil in errors' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(mutation_response['array']).to be_nil
            end
          end
        end

        context 'when relative_position is invalid' do
          let(:relative_position) { :invalid }

          before do
            post_graphql_mutation(mutation, current_user: current_user)
          end

          it_behaves_like 'a mutation that returns top-level errors',
            errors: ['Variable $epicTreeReorderInput of type EpicTreeReorderInput! was provided invalid value for moved.relativePosition (Expected "invalid" to be one of: before, after)']
        end

        context 'when object being moved is not supported type' do
          before do
            variables[:moved][:id] = GitlabSchema.id_from_object(issue1).to_s
            variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(issue2).to_s
          end

          it 'returns the error message' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(graphql_errors.first['message']).to include("\"#{variables[:moved][:id]}\" does not represent an instance of EpicTreeSorting")
            expect(graphql_errors.first['message']).to include("\"#{variables[:moved][:adjacent_reference_id]}\" does not represent an instance of EpicTreeSorting")
          end
        end

        context 'when moving an epic fails due to the parents of the relative position object and the moving object mismatching' do
          let(:epic2) { create(:epic, relative_position: 20, group: private_group) }

          before do
            private_group.add_guest(current_user)
          end

          it_behaves_like 'a mutation that does not update the tree'

          it 'returns the error message' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['errors']).to eq(["The sibling object's parent must match the current parent epic."])
          end
        end

        context 'when the new parent is another epic and subepics feature is disabled' do
          let(:new_parent_id) { GitlabSchema.id_from_object(base_epic).to_s }

          before do
            stub_licensed_features(epics: true, subepics: false)
            other_epic = create(:epic, group: group)
            assign_epic_parent(epic2, other_epic)
          end

          it_behaves_like 'a mutation that does not update the tree'

          it 'returns the error message' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['errors']).to eq(['You don\'t have permissions to move the objects.'])
          end
        end
      end

      context 'when moving an issue' do
        before do
          group.add_guest(current_user)
          variables[:moved][:id] = GitlabSchema.id_from_object(epic_issue2).to_s
          variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(epic_issue1).to_s
        end

        it 'updates the epics relative positions' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(epic_issue1.reload.relative_position).to be > epic_issue2.reload.relative_position
        end

        it 'returns nil in errors' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['array']).to be_nil
        end

        context 'when a new_parent_id is provided' do
          let_it_be(:new_parent_id) { GitlabSchema.id_from_object(base_epic).to_s }
          let_it_be(:other_epic) { create(:epic, group: group) }

          before do
            epic_issue2.work_item_parent_link.update_attribute(:work_item_parent, other_epic.work_item)
            epic_issue2.update_attribute(:epic, other_epic)
            epic_issue2.work_item_parent_link.update!(relative_position: 20)
            epic_issue2.update!(relative_position: 20)
          end

          it "updates the epic's relative positions and parent" do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(epic_issue1.reload.relative_position).to be > epic_issue2.reload.relative_position
            expect(epic_issue2.parent).to eq base_epic
          end

          it 'returns nil in errors' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['array']).to be_nil
          end
        end
      end

      context 'when moving an issue fails due to the parents of the relative position object and the moving object mismatching' do
        let_it_be(:private_issue) { create(:issue, project: private_project) }
        let_it_be(:private_epic) { create(:epic, group: private_group) }
        let_it_be(:private_epic_issue) { create(:epic_issue, epic: private_epic, issue: private_issue, relative_position: 20) }

        before do
          group.add_guest(current_user)
          private_group.add_guest(current_user)
          variables[:moved][:id] = GitlabSchema.id_from_object(private_epic_issue).to_s
          variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(epic_issue1).to_s
        end

        it_behaves_like 'a mutation that does not update the tree'

        it 'returns the error message' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['errors']).to eq(["The sibling object's parent must match the current parent epic."])
        end
      end
    end
  end
end
