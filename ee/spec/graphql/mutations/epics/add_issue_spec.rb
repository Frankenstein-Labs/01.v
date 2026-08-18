# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Epics::AddIssue, feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be_with_reload(:epic) { create(:epic, group: group) }

  let(:current_user) { issue.author }
  let(:issue) { create(:issue, project: project) }

  subject(:mutation) { described_class.new(object: group, context: query_context, field: nil) }

  describe '#resolve' do
    subject do
      mutation.resolve(
        group_path: group.full_path,
        iid: epic.iid,
        issue_iid: issue.iid,
        project_path: project.full_path
      )
    end

    it_behaves_like 'epic mutation for user without access'

    context 'when the user have admin_epic_relation permissions for the epic' do
      before do
        stub_licensed_features(epics: true)
        group.add_guest(current_user)
      end

      context 'when the epic has reached max child limit' do
        let(:expected_error) do
          _('parent already has maximum number of children')
        end

        before do
          stub_const("WorkItems::ParentLink::MAX_CHILDREN", 2)
        end

        it 'raises an error' do
          create_list(:epic, 2, :with_work_item_parent, parent: epic, group: group)

          expect(subject[:errors][0]).to include(expected_error)
        end
      end

      it 'adds the issue to the epic' do
        expect(subject[:epic_issue]).to eq(issue)
        expect(subject[:epic_issue].epic).to eq(epic)
        expect(issue.reload.epic).to eq(epic)
        expect(subject[:errors]).to be_empty
      end

      it 'returns error if the issue is already assigned to the epic' do
        issue.update!(epic: epic)
        create(:parent_link, work_item: WorkItem.find(issue.id), work_item_parent: epic.work_item)

        expect(subject[:errors]).to match_array(['Issue(s) already assigned'])
      end

      it 'returns error if issue is not found' do
        issue.update!(project: create(:project))
        message = "No matching issue found. Make sure that you are adding a valid issue URL."

        expect(subject[:errors]).to match_array([message])
      end
    end
  end
end
