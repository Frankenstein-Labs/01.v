# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ManuallyCreateService, feature_category: :vulnerability_management do
  before do
    stub_licensed_features(security_dashboard: true)
  end

  let_it_be(:user) { create(:user) }

  let(:project) { create(:project) } # cannot use let_it_be here: caching causes problems with permission-related tests
  let(:different_project) { create(:project) }
  let(:service_object) { described_class.new(project, user, params: params) }
  let(:execute_service_with_params) do
    ->(custom_params) { described_class.new(project, user, params: custom_params).execute }
  end

  subject(:create_vulnerability) { service_object.execute }

  context 'with an authorized user with proper permissions' do
    before do
      project.add_maintainer(user)
    end

    context 'with valid parameters' do
      let(:scanner_attributes) do
        {
          id: "my-custom-scanner",
          name: "My Custom Scanner",
          url: "https://superscanner.com",
          vendor: vendor_attributes,
          version: "21.37.00"
        }
      end

      let(:vendor_attributes) do
        {
          name: "Custom Scanner Vendor"
        }
      end

      let(:identifier_attributes) do
        {
          name: "Test identifier 1",
          url: "https://test.com"
        }
      end

      let(:identifier_fingerprint) do
        Digest::SHA1.hexdigest("other:#{identifier_attributes[:name]}")
      end

      let(:params) do
        {
          vulnerability: {
            name: "Test vulnerability",
            state: "detected",
            severity: "unknown",
            identifiers: [identifier_attributes],
            scanner: scanner_attributes,
            solution: "Explanation of how to fix the vulnerability.",
            description: "A long text section describing the vulnerability more fully."
          }
        }
      end

      let(:vulnerability) { create_vulnerability.payload[:vulnerability] }

      context 'with custom external_type and external_id' do
        let(:identifier_attributes) do
          {
            name: "Test identifier 1",
            url: "https://test.com",
            external_id: "my external id",
            external_type: "my external type"
          }
        end

        let(:identifier_fingerprint) do
          Digest::SHA1.hexdigest("#{identifier_attributes[:external_type]}:#{identifier_attributes[:external_id]}")
        end

        it 'uses them to create a Vulnerabilities::Identifier' do
          primary_identifier = vulnerability.finding.primary_identifier
          expect(primary_identifier.external_id).to eq(identifier_attributes[:external_id])
          expect(primary_identifier.external_type).to eq(identifier_attributes[:external_type])
          expect(primary_identifier.fingerprint).to eq(identifier_fingerprint)
        end
      end

      it 'increases vulnerability count by 1' do
        expect { create_vulnerability }.to change { project.reload.security_statistics.vulnerability_count }.by(1)
      end

      it 'creates a new Vulnerability' do
        expect { create_vulnerability }.to change { Vulnerability.count }.by(1)
      end

      it 'marks the project as vulnerable' do
        expect { create_vulnerability }.to change { project.reload.project_setting.has_vulnerabilities? }.to(true)
      end

      it 'creates a Vulnerability with correct attributes' do
        expect(vulnerability.report_type).to eq("generic")
        expect(vulnerability.state).to eq(params.dig(:vulnerability, :state))
        expect(vulnerability.severity).to eq(params.dig(:vulnerability, :severity))
      end

      it 'creates associated objects', :aggregate_failures do
        expect { create_vulnerability }.to change { Vulnerabilities::Finding.count }.by(1)
          .and change { Vulnerabilities::Scanner.count }.by(1)
          .and change { Vulnerabilities::Identifier.count }.by(1)
      end

      it 'creates a vulnerability_finding_risk_scores record' do
        expect { create_vulnerability }.to change { Vulnerabilities::FindingRiskScore.count }.by(1)
      end

      context 'when Scanner already exists' do
        let!(:scanner) { create(:vulnerabilities_scanner, external_id: scanner_attributes[:id], project: project) }

        it 'does not create a new Scanner' do
          expect { create_vulnerability }.to not_change(Vulnerabilities::Scanner, :count)
          expect(vulnerability.finding.scanner_id).to eq(scanner.id)
        end
      end

      # See https://gitlab.com/gitlab-org/gitlab/-/issues/355802#note_874700035
      context 'when Scanner with the same name exists in a different project' do
        let!(:scanner) { create(:vulnerabilities_scanner, external_id: scanner_attributes[:id], project: different_project) }

        it 'creates a new Scanner in the correct project', :aggregate_failures do
          expect { create_vulnerability }.to change { Vulnerabilities::Scanner.count }.by(1)
          expect(vulnerability.finding.scanner_id).not_to eq(scanner.id)
        end
      end

      context 'when Identifier already exists' do
        let(:attributes) { identifier_attributes.merge(project: project, external_type: "other", external_id: identifier_attributes[:name]) }
        let!(:identifier) { create(:vulnerabilities_identifier, attributes) }

        it 'does not create a new Identifier' do
          expect { create_vulnerability }.not_to change { Vulnerabilities::Identifier.count }
        end
      end

      it 'creates all objects with correct attributes' do
        expect(vulnerability.title).to eq(params.dig(:vulnerability, :name))
        expect(vulnerability.report_type).to eq("generic")
        expect(vulnerability.state).to eq(params.dig(:vulnerability, :state))
        expect(vulnerability.severity).to eq(params.dig(:vulnerability, :severity))
        expect(vulnerability.description).to eq(params.dig(:vulnerability, :description))
        expect(vulnerability.finding_description).to eq(params.dig(:vulnerability, :description))
        expect(vulnerability[:solution]).to eq(params.dig(:vulnerability, :solution))

        finding = vulnerability.finding
        expect(finding.report_type).to eq("generic")
        expect(finding.severity).to eq(params.dig(:vulnerability, :severity))
        expect(finding.description).to eq(params.dig(:vulnerability, :description))
        expect(finding.solution).to eq(params.dig(:vulnerability, :solution))
        expect(finding.location).to be_empty
        expect(finding.raw_metadata).to eq("{}")
        expect(vulnerability.finding_id).to eq(finding.id)

        expect(vulnerability.vulnerability_read.state).to eq(params.dig(:vulnerability, :state))
        expect(vulnerability.vulnerability_read.severity).to eq(params.dig(:vulnerability, :severity))
        expect(vulnerability.vulnerability_read.vulnerability_occurrence_id).to eq(finding.id)
        expect(vulnerability.vulnerability_read.security_project_tracked_context_id).to eq(finding.security_project_tracked_context_id)

        scanner = finding.scanner
        expect(scanner.name).to eq(params.dig(:vulnerability, :scanner, :name))

        primary_identifier = finding.primary_identifier
        expect(primary_identifier.name).to eq(params.dig(:vulnerability, :identifiers, 0, :name))
        expect(primary_identifier.url).to eq(params.dig(:vulnerability, :identifiers, 0, :url))
        expect(primary_identifier.external_id).to eq(params.dig(:vulnerability, :identifiers, 0, :name))
        expect(primary_identifier.external_type).to eq("other")
        expect(primary_identifier.fingerprint).to eq(identifier_fingerprint)
      end

      it 'creates separate vulnerabilities when submitted twice with the same details' do
        first = described_class.new(project, user, params: params).execute
        second = described_class.new(project, user, params: params).execute
        results = [first, second]

        expect(results).to all(be_success)

        uuids = results.map { |result| result.payload[:vulnerability].finding_uuid }

        expect(uuids).to all(be_present)
        expect(uuids.first).not_to eq(uuids.last)
      end

      it 'sets the `traversal_ids` of the `vulnerability_reads` record' do
        expect(vulnerability.vulnerability_read.traversal_ids).to eq(project.namespace.traversal_ids)
      end

      context "when state fields match state" do
        let(:params) do
          {
            vulnerability: {
              name: "Test vulnerability",
              state: "confirmed",
              severity: "unknown",
              confirmed_at: Time.now.iso8601,
              identifiers: [identifier_attributes],
              scanner: scanner_attributes
            }
          }
        end

        it 'creates Vulnerability in a different state with timestamps' do
          freeze_time do
            expect(vulnerability.state).to eq(params.dig(:vulnerability, :state))
            expect(vulnerability.confirmed_at).to eq(params.dig(:vulnerability, :confirmed_at))
            expect(vulnerability.confirmed_by).to eq(user)
          end
        end
      end

      context "when state fields don't match state" do
        let(:params) do
          {
            vulnerability: {
              name: "Test vulnerability",
              state: "detected",
              severity: "unknown",
              confirmed_at: Time.now.iso8601,
              identifiers: [identifier_attributes],
              scanner: scanner_attributes
            }
          }
        end

        it 'returns an error' do
          result = create_vulnerability
          expect(result.success?).to be_falsey
          expect(create_vulnerability.message).to match(/confirmed_at can only be set/)
        end
      end

      context "when state doesn't have timestamp" do
        let(:params) do
          {
            vulnerability: {
              name: "Test vulnerability",
              state: state,
              severity: "unknown",
              identifiers: [identifier_attributes],
              scanner: scanner_attributes
            }
          }
        end

        where(:state) { %w[confirmed resolved dismissed] }

        with_them do
          it 'sets the current time' do
            freeze_time do
              expect(create_vulnerability).to be_success
              expect(vulnerability.send("#{state}_at")).to eq(Time.zone.now)
            end
          end
        end
      end

      context 'when the project does not have vulnerability quota' do
        let(:mock_vulnerability_quota) { instance_double(Vulnerabilities::Quota, validate!: false) }

        before do
          allow(project).to receive(:vulnerability_quota).and_return(mock_vulnerability_quota)
        end

        it 'does not create the vulnerability' do
          expect { create_vulnerability }.not_to change { Vulnerability.count }
        end
      end

      it_behaves_like 'reacting to archived and traversal_ids changes'
      it_behaves_like 'assigns tracked context to vulnerability finding'
    end

    context 'with invalid parameters' do
      let(:params) do
        {
          vulnerability: {
            identifiers: [{
              name: "Test identfier 1",
              url: "https://test.com"
            }],
            scanner: {
              name: "My manual scanner"
            }
          }
        }
      end

      it 'returns an error' do
        expect(create_vulnerability.error?).to be_truthy
      end

      it 'returns all ActiveRecord errors' do
        expect(create_vulnerability.payload[:errors]).to include("Name can't be blank", "Severity can't be blank")
      end

      it 'does not mark project as vulnerable' do
        expect { create_vulnerability }.not_to change { project.reload.project_setting.has_vulnerabilities? }.from(false)
      end

      it 'does not change vulnerability_count' do
        expect { create_vulnerability }.to not_change { project.reload.security_statistics.vulnerability_count }
      end
    end
  end

  context 'when user does not have rights to dismiss a vulnerability' do
    let(:params) { {} }

    before do
      project.add_reporter(user)
    end

    it 'raises an "access denied" error' do
      expect { create_vulnerability }.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end
end
