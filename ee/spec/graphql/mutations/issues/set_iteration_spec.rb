# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Issues::SetIteration, feature_category: :team_planning do
  include GraphqlHelpers
  let_it_be(:cadence) { create(:iterations_cadence) }

  let(:issue) { create(:issue) }
  let(:current_user) { create(:user) }

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let(:iteration) { create(:iteration, iterations_cadence: cadence) }
    let(:iteration_id) { iteration&.to_global_id }
    let(:mutated_issue) { subject[:issue] }

    subject { mutation.resolve(project_path: issue.project.full_path, iid: issue.iid, iteration_id: iteration_id) }

    it_behaves_like 'permission level for issue mutation is correctly verified'

    context 'when the user can update the issue' do
      before do
        issue.project.add_developer(current_user)
      end

      it 'returns the issue with the iteration' do
        expect(mutated_issue).to eq(issue)
        expect(mutated_issue.iteration).to eq(iteration)
        expect(subject[:errors]).to be_empty
      end

      it 'returns errors issue could not be updated' do
        # Make the issue invalid
        issue.update_column(:author_id, nil)

        expect(subject[:errors]).not_to be_empty
      end

      context 'when passing iteration_id as nil' do
        let(:iteration_id) { nil }

        it 'removes the iteration' do
          issue.update!(iteration: create(:iteration, iterations_cadence: cadence))

          expect(mutated_issue.iteration).to be_nil
        end

        it 'does not do anything if the issue already does not have a iteration' do
          expect(mutated_issue.iteration).to be_nil
        end
      end

      context 'when iteration_id does not exist' do
        let(:iteration_id) do
          ::Types::GlobalIDType[::Iteration]
            .coerce_isolated_input("gid://gitlab/Iteration/#{non_existing_record_id}")
        end

        it 'raises an execution error with the loads-style message' do
          expect { subject }.to raise_error(
            GraphQL::ExecutionError,
            "No object found for `iterationId: #{iteration_id.to_s.inspect}`"
          )
        end
      end

      context 'when user cannot read the iteration' do
        let_it_be(:private_group) { create(:group, :private) }
        let_it_be(:private_cadence) { create(:iterations_cadence, group: private_group) }
        let_it_be(:iteration) { create(:iteration, iterations_cadence: private_cadence) }

        it 'raises a resource not available error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end
  end
end
