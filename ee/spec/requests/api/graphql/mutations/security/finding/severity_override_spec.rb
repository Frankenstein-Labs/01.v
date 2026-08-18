# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Finding::SeverityOverride, feature_category: :vulnerability_management do
  include GraphqlHelpers

  def create_mutation(mutation_input)
    graphql_mutation(
      :security_finding_severity_override,
      mutation_input
    ) do
      <<~QL
        clientMutationId
        errors
        securityFinding {
          uuid
          severity
        }
      QL
    end
  end

  let(:mutation) { create_mutation(mutation_input) }

  describe '#resolve' do
    include_context 'with dependency scanning security report findings'

    let_it_be(:scan) do
      create(
        :security_scan,
        :latest_successful,
        scan_type: :dependency_scanning,
        pipeline: pipeline,
        build: artifact.job
      )
    end

    let_it_be(:security_finding) do
      create(
        :security_finding,
        severity: report_finding.severity,
        uuid: report_finding.uuid,
        scan: scan
      )
    end

    let_it_be(:current_user) { create(:user) }
    let_it_be(:finding_uuid) { security_finding.uuid }
    let_it_be(:new_severity) { 'HIGH' }
    let_it_be(:mutation_input) { { uuid: security_finding.uuid.to_s, severity: new_severity } }
    let_it_be(:error_message) { 'severity override failed' }
    let_it_be(:error_result) do
      ServiceResponse.error(message: error_message, reason: :unprocessable_entity)
    end

    let(:mutation_response) { graphql_mutation_response(:security_finding_severity_override) }
    let(:response_finding) { mutation_response['securityFinding'] }

    context 'when the user has access to vulnerability management' do
      before do
        stub_licensed_features(security_dashboard: true)
        stub_feature_flags(hide_vulnerability_severity_override: false)
      end

      context 'when user does not have access to the project' do
        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when no uuid is provided' do
        let_it_be(:mutation_input) { { severity: new_severity } }

        let(:error_message) { graphql_errors.first['message'] }

        it 'raises an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(error_message).to include('Expected value to not be null')
        end
      end

      context 'when no severity is provided' do
        let_it_be(:mutation_input) { { uuid: finding_uuid } }

        let(:error_message) { graphql_errors.first['message'] }

        it 'raises an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(error_message).to include('Expected value to not be null')
        end
      end

      context 'when the user has access to the project' do
        let_it_be(:expected_finding) do
          security_finding.slice(:uuid).merge('severity' => new_severity)
        end

        before do
          security_finding.project.add_maintainer(current_user)
        end

        # These tests currently raises Gitlab::QueryLimiting::Transaction::ThresholdExceededError due to
        # checks on the sec application record ensuring that the vuln db trigger is being feature flagged.
        #
        # It should be cleaned up when the feature flag is removed.
        # For ease of code search, related feature flag: turn_off_vulnerability_read_create_db_trigger_function
        context 'when the severity override succeeds', skip: 'temporarily produces too many queries in test env' do
          it 'returns the security finding with updated severity' do
            Gitlab::QueryLimiting.with_suppressed do
              post_graphql_mutation(mutation, current_user: current_user)
            end

            expect(response_finding).to match(expected_finding)
            expect(mutation_response['errors']).to be_empty
          end

          it 'creates a severity override record' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { Vulnerabilities::SeverityOverride.count }.by(1)
          end
        end

        context 'when the severity override fails' do
          before do
            allow_next_instance_of(::Security::Findings::SeverityOverrideService) do |service|
              allow(service).to receive(:execute).and_return(error_result)
            end
          end

          it 'returns an error and no security finding' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response_finding).to be_nil
            expect(mutation_response['errors']).to match_array([error_message])
          end
        end

        context 'when new severity matches the existing severity' do
          let(:new_severity) { security_finding.severity.capitalize }

          it 'doesnt add a new severity override record' do
            expect do
              post_graphql_mutation(create_mutation({ uuid: security_finding.uuid.to_s,
                severity: new_severity }), current_user: current_user)
            end.not_to change { Vulnerabilities::SeverityOverride.count }
          end
        end

        # These tests currently raises Gitlab::QueryLimiting::Transaction::ThresholdExceededError due to
        # checks on the sec application record ensuring that the vuln db trigger is being feature flagged.
        #
        # It should be cleaned up when the feature flag is removed.
        # For ease of code search, related feature flag: turn_off_vulnerability_read_create_db_trigger_function
        context 'when security finding already has a different severity value',
          skip: 'temporarily produces too many queries in test env' do
          let(:previous_severity) { 'CRITICAL' }

          before do
            mutation_input[:severity] = previous_severity
            post_graphql_mutation(create_mutation(mutation_input), current_user: current_user)
            mutation_input[:severity] = new_severity
          end

          it 'returns the correct severity value' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response_finding).to match(expected_finding)
            expect(mutation_response['errors']).to be_empty
          end

          it 'creates severity overrides records for the related vulnerability' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to not_change { Vulnerability.count }
              .and not_change { Vulnerabilities::Finding.count }
              .and change { Vulnerabilities::SeverityOverride.count }.by(1)
          end
        end
      end

      context 'when the feature flag is disabled' do
        before do
          security_finding.project.add_maintainer(current_user)
          stub_feature_flags(hide_vulnerability_severity_override: true)
        end

        it 'returns ResourceNotAvailable error' do
          post_graphql_mutation(mutation, current_user: current_user)
          expect_graphql_errors_to_include("Gitlab::Access::AccessDeniedError")
        end
      end
    end

    context 'when the security dashboard is not available to the user' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end
end
