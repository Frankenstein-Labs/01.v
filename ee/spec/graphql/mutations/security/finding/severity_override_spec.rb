# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Finding::SeverityOverride, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

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

    let_it_be_with_reload(:vulnerability_finding) do
      create(:vulnerabilities_finding, uuid: report_finding.uuid, project: project, report_type: :dependency_scanning)
    end

    let_it_be(:current_user) { create(:user) }
    let_it_be(:finding_uuid) { security_finding.uuid }
    let_it_be(:new_severity) { 'high' }

    let(:mutated_finding_uuid) { subject[:uuid] }
    let(:mutated_finding) { subject[:security_finding] }

    subject(:resolve) { mutation.resolve(uuid: finding_uuid, severity: new_severity) }

    context 'when the user has permission to override severity' do
      before do
        stub_licensed_features(security_dashboard: true)
        stub_feature_flags(hide_vulnerability_severity_override: false)
      end

      context 'when no uuid is provided' do
        it 'raises an error' do
          expect { mutation.resolve(severity: new_severity) }.to raise_error(ArgumentError)
        end
      end

      context 'when no severity is provided' do
        it 'raises an error' do
          expect { mutation.resolve(uuid: finding_uuid) }.to raise_error(ArgumentError)
        end
      end

      context 'when the user has access to the project' do
        before do
          security_finding.project.add_maintainer(current_user)
          Vulnerabilities::Finding.delete_all
        end

        context 'when the severity override is successful' do
          it 'returns the overridden security finding uuid' do
            expect(mutated_finding_uuid).to eq(finding_uuid)
            expect(resolve[:errors]).to be_empty
          end

          it 'returns the updated severity' do
            expect(mutated_finding.severity).to eq(new_severity)
            expect(resolve[:security_finding].severity).to eq(new_severity)
          end

          it 'updates the severity property for the security_finding matching vulnerability record' do
            expect(mutated_finding.severity).to eq(new_severity)
            expect(Vulnerability.last.severity).to eq(new_severity)
            expect(resolve[:errors]).to be_empty
          end

          it 'creates a severity_override record' do
            expect { resolve }.to change { Vulnerabilities::SeverityOverride.count }.by(1)
            last_severity_override = Vulnerabilities::SeverityOverride.last
            expect(last_severity_override.new_severity).to eq(new_severity)
            expect(last_severity_override.original_severity).to eq(report_finding.severity)
            expect(last_severity_override.project).to eq(security_finding.project)
            expect(last_severity_override.author).to eq(current_user)
            expect(last_severity_override.vulnerability).to eq(Vulnerability.last)
          end
        end

        context 'when the severity override fails' do
          let_it_be(:error_result) do
            ServiceResponse.error(message: "error", reason: :unprocessable_entity)
          end

          before do
            allow_next_instance_of(::Security::Findings::SeverityOverrideService) do |service|
              allow(service).to receive(:execute).and_return(error_result)
            end
          end

          it 'raises an error and no uuid is returned' do
            expect(mutated_finding_uuid).to be_nil
            expect(resolve[:errors]).to match_array(['error'])
          end

          it 'raises an error and no security finding is returned' do
            expect(mutated_finding).to be_nil
            expect(resolve[:errors]).to match_array(['error'])
          end
        end
      end
    end

    context 'when the user does not have access to the project' do
      context 'when the security dashboard is available to the user' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        context 'when user does not have access to the project' do
          it 'raises an error' do
            expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end

        context 'when vulnerability_severity_override feature flag is disabled' do
          before do
            security_finding.project.add_maintainer(current_user)
            stub_feature_flags(hide_vulnerability_severity_override: true)
          end

          it 'raises an error' do
            expect { resolve }.to raise_error(Gitlab::Access::AccessDeniedError)
          end
        end
      end

      context 'when the security dashboard is not available to the user' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end
  end
end
