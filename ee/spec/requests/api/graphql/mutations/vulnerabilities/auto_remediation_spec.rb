# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Triggering auto-remediation for a vulnerability', feature_category: :dependency_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) do
    create(:vulnerability, :with_finding, :detected, project: project, report_type: :dependency_scanning)
  end

  let_it_be(:sbom_occurrence) do
    create(:sbom_occurrence, project: project, package_manager: 'bundler').tap do |occurrence|
      create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability)
    end
  end

  let(:vulnerability_gid) { GitlabSchema.id_from_object(vulnerability).to_s }

  let(:mutation) do
    graphql_mutation(:vulnerability_auto_remediation, vulnerability_id: vulnerability_gid)
  end

  def mutation_response
    graphql_mutation_response(:vulnerability_auto_remediation)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  shared_examples 'a denied request' do
    it 'returns a top-level authorization error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(
        a_hash_including(
          'message' => 'The resource that you are attempting to access does not exist or you don\'t have ' \
            'permission to perform this action'
        )
      )
    end
  end

  context 'when the user is not authenticated' do
    let(:current_user) { nil }

    it_behaves_like 'a denied request'
  end

  context 'when the user does not have permission' do
    let(:current_user) { user }

    it_behaves_like 'a denied request'
  end

  context 'when the user has permission' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      allow(DependencyManagement::SecurityUpdate::Eligibility)
        .to receive(:remediation_profile).and_return(instance_double(Security::ScanProfile))
    end

    context 'when no remediation configuration is available' do
      before do
        allow(DependencyManagement::SecurityUpdate::Eligibility)
          .to receive(:remediation_profile).and_return(nil)
      end

      it 'returns an error without evaluating eligibility or triggering the update', :aggregate_failures do
        expect(DependencyManagement::SecurityUpdate::SbomOccurrenceFinder).not_to receive(:new)
        expect(DependencyManagement::SecurityUpdate::UpdateService).not_to receive(:new)

        post_graphql_mutation(mutation, current_user: user)

        expect(mutation_response['status']).to be_nil
        expect(mutation_response['errors'])
          .to contain_exactly('Automated dependency security updates not configured')
      end
    end

    context 'when authenticating with an access token' do
      before do
        allow(DependencyManagement::SecurityUpdate::Eligibility).to receive(:remediable?).and_return(false)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :resolve_vulnerability do
        let(:boundary_object) { project }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'when the vulnerability has a remediable supported dependency' do
      before do
        allow(DependencyManagement::SecurityUpdate::Eligibility).to receive(:remediable?).and_return(true)
      end

      it 'triggers the update and returns IN_PROGRESS', :aggregate_failures do
        expect_next_instance_of(DependencyManagement::SecurityUpdate::UpdateService, project: project) do |service|
          expect(service).to receive(:execute)
            .with(an_instance_of(DependencyManagement::SecurityUpdate::Request))
            .and_return(ServiceResponse.success(payload: { pipeline: nil }))
        end

        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_errors).to be_blank
        expect(mutation_response['status']).to eq('IN_PROGRESS')
        expect(mutation_response['errors']).to be_empty
      end

      it 'surfaces service errors', :aggregate_failures do
        expect_next_instance_of(DependencyManagement::SecurityUpdate::UpdateService, project: project) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.error(message: 'nope'))
        end

        post_graphql_mutation(mutation, current_user: user)

        expect(mutation_response['status']).to be_nil
        expect(mutation_response['errors']).to contain_exactly('nope')
      end
    end

    context 'when no fix is available' do
      before do
        allow(DependencyManagement::SecurityUpdate::Eligibility).to receive(:remediable?).and_return(false)
      end

      it 'returns NO_FIX_AVAILABLE without triggering the update', :aggregate_failures do
        expect(DependencyManagement::SecurityUpdate::UpdateService).not_to receive(:new)

        post_graphql_mutation(mutation, current_user: user)

        expect(mutation_response['status']).to eq('NO_FIX_AVAILABLE')
        expect(mutation_response['errors']).to be_empty
      end
    end

    context 'when the vulnerability has no supported dependency' do
      let(:vulnerability_gid) do
        other = create(:vulnerability, :with_finding, :detected, project: project, report_type: :dependency_scanning)
        GitlabSchema.id_from_object(other).to_s
      end

      it 'returns UNSUPPORTED without triggering the update', :aggregate_failures do
        expect(DependencyManagement::SecurityUpdate::UpdateService).not_to receive(:new)

        post_graphql_mutation(mutation, current_user: user)

        expect(mutation_response['status']).to eq('UNSUPPORTED')
        expect(mutation_response['errors']).to be_empty
      end
    end

    context 'when the vulnerability is not a dependency-scanning vulnerability' do
      let(:vulnerability_gid) do
        sast = create(:vulnerability, :with_finding, :detected, project: project, report_type: :sast)
        GitlabSchema.id_from_object(sast).to_s
      end

      it 'returns UNSUPPORTED without resolving an occurrence or triggering the update', :aggregate_failures do
        expect(DependencyManagement::SecurityUpdate::SbomOccurrenceFinder).not_to receive(:new)
        expect(DependencyManagement::SecurityUpdate::UpdateService).not_to receive(:new)

        post_graphql_mutation(mutation, current_user: user)

        expect(mutation_response['status']).to eq('UNSUPPORTED')
        expect(mutation_response['errors']).to be_empty
      end
    end
  end
end
