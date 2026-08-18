# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Issues::SetEpic, feature_category: :team_planning do
  include GraphqlHelpers
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:issue) { create(:issue, project: project) }

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be_with_reload(:epic) { create(:epic, group: group) }
    let_it_be_with_reload(:confidential_epic) { create(:epic, group: group, confidential: true) }

    let(:epic_id) { epic&.to_global_id }
    let(:mutated_issue) { subject[:issue] }

    subject { mutation.resolve(project_path: issue.project.full_path, iid: issue.iid, epic_id: epic_id) }

    it_behaves_like 'permission level for issue mutation is correctly verified', true

    context 'when the user can update the issue' do
      before do
        stub_licensed_features(epics: true)
        project.add_reporter(current_user)
        group.add_guest(current_user)
      end

      context 'when user can read epic' do
        it 'returns the issue with the epic' do
          expect(mutated_issue).to eq(issue)
          expect(mutated_issue.epic).to eq(epic)
          expect(subject[:errors]).to be_empty
        end

        it 'returns errors if issue could not be updated' do
          issue.update_column(:author_id, nil)

          expect(subject[:errors]).to eq(["Author can't be blank"])
        end

        context 'when passing epic_id as nil' do
          let(:epic_id) { nil }

          it 'removes the epic' do
            issue.update!(epic: create(:epic, group: group))

            expect(mutated_issue.epic).to be_nil
          end

          it 'does not do anything if the issue already does not have a epic' do
            expect(mutated_issue.epic).to be_nil
          end
        end

        context 'when epic is confidential but issue is public' do
          let(:epic_id) { confidential_epic.to_global_id }

          it 'returns an error with appropriate message' do
            group.add_reporter(current_user)

            expect(subject[:errors].first).to include("cannot assign a non-confidential issue to a confidential parent. Make the issue confidential and try again.")
          end
        end

        context 'with assigning epic error' do
          let(:mock_service) { double('service', execute: { status: :error, message: 'failed to assign epic' }) }

          it 'returns an error with appropriate message' do
            expect(::WorkItems::LegacyEpics::EpicIssues::CreateService).to receive(:new).and_return(mock_service)

            expect(subject[:errors].first).to include('failed to assign epic')
          end
        end
      end

      context 'when user can not read epic' do
        let(:epic_id) { confidential_epic.to_global_id }

        it 'raises an error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when epic_id does not exist' do
        let(:epic_id) { ::Types::GlobalIDType[::Epic].coerce_isolated_input("gid://gitlab/Epic/#{non_existing_record_id}") }

        it 'raises an execution error with the loads-style message' do
          expect { subject }.to raise_error(
            GraphQL::ExecutionError,
            "No object found for `epicId: #{epic_id.to_s.inspect}`"
          )
        end
      end
    end
  end
end
