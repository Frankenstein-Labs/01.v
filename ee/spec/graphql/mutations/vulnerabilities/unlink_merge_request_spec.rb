# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Vulnerabilities::UnlinkMergeRequest, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:current_user) { create(:user) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:vulnerability) { create(:vulnerability, :with_findings, project: project) }
    let_it_be(:merge_request_link) do
      create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
    end

    let(:vulnerability_global_id) { GitlabSchema.id_from_object(vulnerability) }
    let(:merge_request_global_id) { GitlabSchema.id_from_object(merge_request) }

    subject(:unlink_merge_request) do
      mutation.resolve(
        vulnerability_id: vulnerability_global_id,
        merge_request_id: merge_request_global_id
      )
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when user does not have access to the project' do
      it 'raises an error' do
        expect { unlink_merge_request }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when user has access to the project' do
      before do
        vulnerability.project.add_maintainer(current_user)
      end

      context 'when unlinking succeeds' do
        let(:service_result) { ServiceResponse.success }

        before do
          allow_next_instance_of(::VulnerabilityMergeRequestLinks::DestroyService) do |service|
            allow(service).to receive(:execute).and_return(service_result)
          end
        end

        it 'returns the vulnerability' do
          expect(unlink_merge_request[:vulnerability]).to eq(vulnerability)
          expect(unlink_merge_request[:errors]).to be_empty
        end

        it 'calls the destroy service with correct parameters' do
          expect_next_instance_of(::VulnerabilityMergeRequestLinks::DestroyService) do |service|
            expect(service).to receive(:execute).and_return(service_result)
          end

          unlink_merge_request
        end
      end

      context 'when merge request does not exist' do
        let(:non_existent_merge_request_id) do
          GitlabSchema.id_from_object(build(:merge_request, id: non_existing_record_id))
        end

        subject(:unlink_merge_request) do
          mutation.resolve(
            vulnerability_id: vulnerability_global_id,
            merge_request_id: non_existent_merge_request_id
          )
        end

        it 'returns an error' do
          expect(unlink_merge_request[:vulnerability]).to eq(vulnerability)
          expect(unlink_merge_request[:errors]).to include(
            'The merge request does not exist or you do not have permission to view it.'
          )
        end
      end

      context 'when user cannot read the merge request' do
        let_it_be(:private_project) { create(:project, :private) }
        let(:private_merge_request) { create(:merge_request, source_project: private_project) }
        let(:private_merge_request_global_id) { GitlabSchema.id_from_object(private_merge_request) }

        subject(:unlink_merge_request) do
          mutation.resolve(
            vulnerability_id: vulnerability_global_id,
            merge_request_id: private_merge_request_global_id
          )
        end

        it 'returns an error' do
          expect(unlink_merge_request[:vulnerability]).to eq(vulnerability)
          expect(unlink_merge_request[:errors]).to include(
            'The merge request does not exist or you do not have permission to view it.'
          )
        end
      end

      context 'when merge request is not linked to the vulnerability' do
        let(:unlinked_merge_request) do
          create(:merge_request, source_project: project, source_branch: 'feature', target_branch: 'main')
        end

        let(:unlinked_merge_request_global_id) { GitlabSchema.id_from_object(unlinked_merge_request) }

        subject(:unlink_merge_request) do
          mutation.resolve(
            vulnerability_id: vulnerability_global_id,
            merge_request_id: unlinked_merge_request_global_id
          )
        end

        it 'returns an error' do
          expect(unlink_merge_request[:vulnerability]).to eq(vulnerability)
          expect(unlink_merge_request[:errors]).to include('Merge request is not linked to this vulnerability')
        end
      end

      context 'when unlinking fails due to service error' do
        let(:service_result) do
          ServiceResponse.error(message: 'Service error', payload: { errors: ['Service error'] })
        end

        before do
          allow_next_instance_of(::VulnerabilityMergeRequestLinks::DestroyService) do |service|
            allow(service).to receive(:execute).and_return(service_result)
          end
        end

        it 'returns the service errors' do
          expect(unlink_merge_request[:vulnerability]).to eq(vulnerability)
          expect(unlink_merge_request[:errors]).to include('Service error')
        end
      end
    end
  end

  describe '.authorization_scopes' do
    it 'includes api and ai_workflows scope' do
      expect(described_class.authorization_scopes).to include(:api, :ai_workflows)
    end
  end
end
