# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AscpScanCreate', feature_category: :static_application_security_testing do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:guest) { create(:user) }

  let(:current_user) { maintainer }
  let(:commit_sha) { 'abc123def456' }

  let(:input) do
    {
      projectPath: project.full_path,
      commitSha: commit_sha,
      scanType: 'FULL'
    }
  end

  let(:mutation) { graphql_mutation(:ascp_scan_create, input, scan_fields) }

  def scan_fields
    <<~FIELDS
      scan {
        id
        scanSequence
        commitSha
        scanType
        baseCommitSha
        baseScan {
          id
        }
      }
      errors
    FIELDS
  end

  def mutation_result
    graphql_mutation_response(:ascp_scan_create)
  end

  before_all do
    project.add_maintainer(maintainer)
    project.add_guest(guest)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'GraphQL mutation' do
    context 'when user has permissions' do
      it 'creates a scan' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { Security::Ascp::Scan.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_result['errors']).to be_empty
        expect(mutation_result['scan']).to include(
          'scanSequence' => 1,
          'commitSha' => commit_sha,
          'scanType' => 'FULL'
        )
      end

      context 'when there are existing scans' do
        let_it_be(:existing_scan) { create(:security_ascp_scan, project: project, scan_sequence: 5) }

        it 'increments the scan_sequence' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['scan']['scanSequence']).to eq(6)
        end
      end

      context 'with incremental scan' do
        let_it_be(:base_scan) { create(:security_ascp_scan, :full, project: project) }

        let(:input) do
          {
            projectPath: project.full_path,
            commitSha: commit_sha,
            scanType: 'INCREMENTAL',
            baseScanId: base_scan.to_global_id.to_s,
            baseCommitSha: 'base123'
          }
        end

        it 'creates an incremental scan with base_scan reference' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['errors']).to be_empty
          expect(mutation_result['scan']).to include(
            'scanType' => 'INCREMENTAL',
            'baseCommitSha' => 'base123'
          )
          expect(mutation_result['scan']['baseScan']).to include(
            'id' => base_scan.to_global_id.to_s
          )
        end
      end

      context 'when service returns an error' do
        let(:input) do
          {
            projectPath: project.full_path,
            commitSha: commit_sha,
            scanType: 'INCREMENTAL'
          }
        end

        it 'returns errors and nil scan' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['scan']).to be_nil
          expect(mutation_result['errors']).not_to be_empty
        end
      end
    end

    context 'when user does not have permissions' do
      let(:current_user) { guest }

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when security_dashboard feature is not available' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end
end
