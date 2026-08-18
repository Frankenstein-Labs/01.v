# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::MergeRequests::SetBlockingMergeRequests, feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, source_branch: 'feature-a') }
  let_it_be(:blocking_mr1) { create(:merge_request, source_project: project, source_branch: 'feature-b') }
  let_it_be(:blocking_mr2) { create(:merge_request, source_project: project, source_branch: 'feature-c') }

  let(:current_user) { user }
  let(:blocking_references) { ["!#{blocking_mr1.iid}"] }

  let(:mutation_vars) do
    {
      project_path: project.full_path,
      iid: merge_request.iid.to_s,
      blocking_merge_request_references: blocking_references
    }
  end

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(blocking_merge_requests: true)
  end

  describe '#resolve' do
    subject(:resolve) { mutation.resolve(**mutation_vars) }

    context 'when user has permissions' do
      it 'sets blocking merge requests' do
        result = resolve

        expect(result[:merge_request]).to eq(merge_request)
        expect(result[:errors]).to be_empty
        expect(merge_request.reload.blocking_merge_requests).to contain_exactly(blocking_mr1)
      end

      context 'with multiple blocking merge requests' do
        let(:blocking_references) { ["!#{blocking_mr1.iid}", "!#{blocking_mr2.iid}"] }

        it 'sets all blocking merge requests' do
          result = resolve

          expect(result[:merge_request]).to eq(merge_request)
          expect(result[:errors]).to be_empty
          expect(merge_request.reload.blocking_merge_requests).to contain_exactly(blocking_mr1, blocking_mr2)
        end
      end

      context 'with empty array' do
        let(:blocking_references) { [] }

        before do
          create(:merge_request_block, blocking_merge_request: blocking_mr1, blocked_merge_request: merge_request)
        end

        it 'removes all blocking merge requests' do
          expect(merge_request.reload.blocking_merge_requests).to contain_exactly(blocking_mr1)

          result = resolve

          expect(result[:merge_request]).to eq(merge_request)
          expect(result[:errors]).to be_empty
          expect(merge_request.reload.blocking_merge_requests).to be_empty
        end
      end

      context 'with cross-project reference' do
        let_it_be(:other_project) { create(:project, :repository) }
        let_it_be(:other_mr) { create(:merge_request, source_project: other_project, source_branch: 'feature-d') }
        let(:blocking_references) { ["#{other_project.full_path}!#{other_mr.iid}"] }

        before_all do
          other_project.add_developer(user)
        end

        it 'sets blocking merge request from another project' do
          result = resolve

          expect(result[:merge_request]).to eq(merge_request)
          expect(result[:errors]).to be_empty
          expect(merge_request.reload.blocking_merge_requests).to contain_exactly(other_mr)
        end
      end

      context 'with invalid reference' do
        let(:blocking_references) { ['!99999'] }

        it 'returns an error' do
          result = resolve

          expect(result[:merge_request]).to eq(merge_request)
          expect(result[:errors]).not_to be_empty
          expect(result[:errors].first).to include('failed to save: !99999')
        end
      end

      context 'when replacing existing blocking MRs' do
        before do
          create(:merge_request_block, blocking_merge_request: blocking_mr1, blocked_merge_request: merge_request)
        end

        let(:blocking_references) { ["!#{blocking_mr2.iid}"] }

        it 'replaces the blocking merge requests' do
          expect(merge_request.reload.blocking_merge_requests).to contain_exactly(blocking_mr1)

          result = resolve

          expect(result[:merge_request]).to eq(merge_request)
          expect(result[:errors]).to be_empty
          expect(merge_request.reload.blocking_merge_requests).to contain_exactly(blocking_mr2)
        end
      end
    end

    context 'when user does not have permissions' do
      let_it_be(:guest) { create(:user) }
      let(:current_user) { guest }

      before_all do
        project.add_guest(guest)
      end

      it 'raises an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(blocking_merge_requests: false)
      end

      it 'raises an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          .with_message('Blocking merge requests feature is not available')
      end
    end

    context 'when merge request does not exist' do
      let(:mutation_vars) do
        {
          project_path: project.full_path,
          iid: '99999',
          blocking_merge_request_references: blocking_references
        }
      end

      it 'raises an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
