# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::OverrideUuidsService, feature_category: :vulnerability_management do
  describe '#execute' do
    let(:signature_1) { create_finding_signature('location', 'signature value 1') }
    let(:signature_2) { create_finding_signature('location', 'signature value 2') }
    let(:signature_3) { create_finding_signature('location', 'signature value 3') }
    let(:location_1) { create(:ci_reports_security_locations_sast, start_line: 0) }
    let(:location_2) { create(:ci_reports_security_locations_sast, start_line: 1) }
    let(:matching_report_identifier) { create(:ci_reports_security_identifier, external_id: vulnerability_identifier.external_id, external_type: vulnerability_identifier.external_type) }
    let(:matching_report_finding_by_signature) { create(:ci_reports_security_finding, uuid: SecureRandom.uuid, context_unaware_uuid: SecureRandom.uuid, vulnerability_finding_signatures_enabled: true, signatures: [signature_1], identifiers: [matching_report_identifier], scanner: report_scanner) }
    let(:matching_report_finding_by_location) { create(:ci_reports_security_finding, uuid: SecureRandom.uuid, context_unaware_uuid: SecureRandom.uuid, vulnerability_finding_signatures_enabled: true, signatures: [signature_2], location: location_2, identifiers: [matching_report_identifier], scanner: report_scanner) }
    let(:matching_report_finding_by_location_conflict) { create(:ci_reports_security_finding, vulnerability_finding_signatures_enabled: true, signatures: [signature_3], location: location_1, scanner: report_scanner, identifiers: [matching_report_identifier]) }
    let(:unmatching_report_finding) { create(:ci_reports_security_finding, vulnerability_finding_signatures_enabled: true, signatures: [signature_1], scanner: report_scanner) }
    let(:report) do
      create(
        :ci_reports_security_report,
        findings: [
          unmatching_report_finding,
          matching_report_finding_by_signature,
          matching_report_finding_by_location,
          matching_report_finding_by_location_conflict
        ],
        pipeline: pipeline
      )
    end

    let(:service_object) { described_class.new(report) }

    let(:pipeline) { create(:ci_pipeline) }
    let(:tracked_context) { create(:security_project_tracked_context, :tracked, context_name: pipeline.ref, project: pipeline.project) }
    let(:vulnerability_scanner) { create(:vulnerabilities_scanner, external_id: 'gitlab-sast', project: pipeline.project) }
    let(:vulnerability_identifier) { create(:vulnerabilities_identifier, fingerprint: 'e2bd6788a715674769f48fadffd0bd3ea16656f5') }

    let(:vulnerability_finding_1) do
      create(
        :vulnerabilities_finding,
        project: pipeline.project,
        uuid: SecureRandom.uuid,
        new_uuid: SecureRandom.uuid,
        location_fingerprint: location_1.fingerprint,
        primary_identifier: vulnerability_identifier,
        scanner: vulnerability_scanner,
        project_tracked_context: tracked_context
      )
    end

    let(:vulnerability_finding_2) do
      create(
        :vulnerabilities_finding,
        project: pipeline.project,
        uuid: SecureRandom.uuid,
        new_uuid: SecureRandom.uuid,
        location_fingerprint: location_2.fingerprint,
        primary_identifier: vulnerability_identifier,
        scanner: vulnerability_scanner,
        project_tracked_context: tracked_context
      )
    end

    let(:report_scanner) { create(:ci_reports_security_scanner, external_id: 'gitlab-sast') }

    def create_finding_signature(algorithm_type, signature_value)
      ::Gitlab::Ci::Reports::Security::FindingSignature.new(
        algorithm_type: algorithm_type,
        signature_value: signature_value,
        qualified_signature: true
      )
    end

    before do
      create(:vulnerabilities_finding_signature, :location, finding: vulnerability_finding_1, signature_sha: Digest::SHA1.digest('signature value 1'))
      create(:vulnerabilities_finding_signature, :location, finding: vulnerability_finding_2, signature_sha: Digest::SHA1.digest('foo'))
    end

    subject(:override_uuids) { service_object.execute }

    context 'when the `vulnerability_finding_signatures` is enabled' do
      before do
        stub_licensed_features(vulnerability_finding_signatures: true)
      end

      def create_vulnerability_finding(uuid, location_fingerprint = nil)
        create(
          :vulnerabilities_finding,
          project: pipeline.project,
          uuid: uuid,
          location_fingerprint: location_fingerprint,
          primary_identifier: vulnerability_identifier,
          scanner: vulnerability_scanner,
          project_tracked_context: tracked_context
        )
      end

      it 'overrides finding uuids and prioritizes the existing findings' do
        expect { override_uuids }
          .to change { report.findings.map(&:overridden_uuid) }.from(Array.new(4) { nil }).to([an_instance_of(String), an_instance_of(String), nil, nil])
          .and change { matching_report_finding_by_signature.uuid }.to(vulnerability_finding_1.uuid)
          .and change { matching_report_finding_by_signature.overridden_uuid }.to(matching_report_finding_by_signature.uuid)
          .and change { matching_report_finding_by_location.uuid }.to(vulnerability_finding_2.uuid)
          .and change { matching_report_finding_by_location.overridden_uuid }.to(matching_report_finding_by_location.uuid)
          .and not_change { matching_report_finding_by_location_conflict.uuid }
          .and not_change { unmatching_report_finding.uuid }
      end

      context 'when a finding has only a scope_offset signature match' do
        def create_scope_offset_test_data
          finding = create(
            :vulnerabilities_finding,
            project: pipeline.project,
            uuid: SecureRandom.uuid,
            new_uuid: SecureRandom.uuid,
            primary_identifier: vulnerability_identifier,
            scanner: vulnerability_scanner,
            project_tracked_context: tracked_context
          )

          report_finding = create(
            :ci_reports_security_finding,
            uuid: SecureRandom.uuid,
            context_unaware_uuid: SecureRandom.uuid,
            vulnerability_finding_signatures_enabled: true,
            signatures: [
              create_finding_signature('location', 'no match location value'),
              create_finding_signature('scope_offset', 'scope offset value')
            ],
            identifiers: [matching_report_identifier],
            scanner: report_scanner
          )

          report = create(:ci_reports_security_report, findings: [report_finding], pipeline: pipeline)

          create(:vulnerabilities_finding_signature, :scope_offset,
            finding: finding,
            signature_sha: Digest::SHA1.digest('scope offset value'))

          service = described_class.new(report)

          { finding: finding, report_finding: report_finding, report: report, service: service }
        end

        let(:test_data) { create_scope_offset_test_data }

        it 'overrides finding uuid based on the matching scope_offset signature' do
          expect { test_data[:service].execute }
            .to change { test_data[:report_finding].uuid }.to(test_data[:finding].uuid)
            .and change { test_data[:report_finding].overridden_uuid }.to(test_data[:report_finding].uuid)
        end
      end

      context 'when findings have multiple signature types with partial matches' do
        def create_mixed_signatures_test_data
          signature_values = {
            offset_1: 'scope offset value 1',
            offset_2: 'scope offset value 2',
            compressed_1: 'scope offset compressed value 1',
            compressed_2: 'scope offset compressed value 2',
            non_match_offset: 'different offset value',
            non_match_compressed: 'different compressed value',
            other_non_match_1: 'some non-matching value',
            other_non_match_2: 'some other non-matching value'
          }

          vuln_4 = create(
            :vulnerabilities_finding,
            project: pipeline.project,
            uuid: SecureRandom.uuid,
            primary_identifier: vulnerability_identifier,
            scanner: vulnerability_scanner,
            project_tracked_context: tracked_context
          )

          vuln_5 = create(
            :vulnerabilities_finding,
            project: pipeline.project,
            uuid: SecureRandom.uuid,
            primary_identifier: vulnerability_identifier,
            scanner: vulnerability_scanner,
            project_tracked_context: tracked_context
          )

          report_4 = create(
            :ci_reports_security_finding,
            uuid: SecureRandom.uuid,
            vulnerability_finding_signatures_enabled: true,
            signatures: [
              create_finding_signature('scope_offset', signature_values[:offset_1]),
              create_finding_signature('scope_offset_compressed', signature_values[:non_match_compressed])
            ],
            identifiers: [matching_report_identifier],
            scanner: report_scanner
          )

          report_5 = create(
            :ci_reports_security_finding,
            uuid: SecureRandom.uuid,
            vulnerability_finding_signatures_enabled: true,
            signatures: [
              create_finding_signature('scope_offset', signature_values[:non_match_offset]),
              create_finding_signature('scope_offset_compressed', signature_values[:compressed_2])
            ],
            identifiers: [matching_report_identifier],
            scanner: report_scanner
          )

          report = create(
            :ci_reports_security_report,
            findings: [report_4, report_5],
            pipeline: pipeline
          )

          create(:vulnerabilities_finding_signature, :scope_offset,
            finding: vuln_4,
            signature_sha: Digest::SHA1.digest(signature_values[:offset_1]))
          create(:vulnerabilities_finding_signature, :scope_offset_compressed,
            finding: vuln_4,
            signature_sha: Digest::SHA1.digest(signature_values[:other_non_match_1]))

          create(:vulnerabilities_finding_signature, :scope_offset,
            finding: vuln_5,
            signature_sha: Digest::SHA1.digest(signature_values[:other_non_match_2]))
          create(:vulnerabilities_finding_signature, :scope_offset_compressed,
            finding: vuln_5,
            signature_sha: Digest::SHA1.digest(signature_values[:compressed_2]))

          service = described_class.new(report)

          {
            vuln_4: vuln_4,
            vuln_5: vuln_5,
            report_4: report_4,
            report_5: report_5,
            report: report,
            service: service
          }
        end

        let(:test_data) { create_mixed_signatures_test_data }

        it 'overrides uuid based on the matching signature' do
          expect { test_data[:service].execute }
            .to change { test_data[:report_4].uuid }.to(test_data[:vuln_4].uuid)
            .and change { test_data[:report_4].overridden_uuid }.to(test_data[:report_4].uuid)
            .and change { test_data[:report_5].uuid }.to(test_data[:vuln_5].uuid)
            .and change { test_data[:report_5].overridden_uuid }.to(test_data[:report_5].uuid)
        end
      end

      context 'when a finding has no signature matches' do
        def create_no_match_test_data
          report_finding = create(
            :ci_reports_security_finding,
            uuid: SecureRandom.uuid,
            vulnerability_finding_signatures_enabled: true,
            signatures: [
              create_finding_signature('scope_offset', 'no match value 1'),
              create_finding_signature('scope_offset_compressed', 'no match value 2')
            ],
            identifiers: [matching_report_identifier],
            scanner: report_scanner
          )

          report = create(:ci_reports_security_report, findings: [report_finding], pipeline: pipeline)
          service = described_class.new(report)

          { report_finding: report_finding, report: report, service: service }
        end

        let(:test_data) { create_no_match_test_data }

        it 'does not override the finding uuid' do
          test_data[:report_finding].uuid

          expect { test_data[:service].execute }
            .to not_change { test_data[:report_finding].uuid }
            .and not_change { test_data[:report_finding].overridden_uuid }
        end
      end

      context 'when a finding has multiple matching signatures with different priorities' do
        def create_multiple_matches_test_data
          vuln_finding_offset = create(
            :vulnerabilities_finding,
            project: pipeline.project,
            uuid: SecureRandom.uuid,
            primary_identifier: vulnerability_identifier,
            scanner: vulnerability_scanner,
            project_tracked_context: tracked_context
          )

          vuln_finding_compressed = create(
            :vulnerabilities_finding,
            project: pipeline.project,
            uuid: SecureRandom.uuid,
            primary_identifier: vulnerability_identifier,
            scanner: vulnerability_scanner,
            project_tracked_context: tracked_context
          )

          create(:vulnerabilities_finding_signature, :scope_offset,
            finding: vuln_finding_offset,
            signature_sha: Digest::SHA1.digest('matching scope offset value'))

          create(:vulnerabilities_finding_signature, :scope_offset_compressed,
            finding: vuln_finding_compressed,
            signature_sha: Digest::SHA1.digest('matching scope offset compressed value'))

          # Create report finding matches both of the signatures above
          report_finding = create(
            :ci_reports_security_finding,
            uuid: SecureRandom.uuid,
            vulnerability_finding_signatures_enabled: true,
            signatures: [
              create_finding_signature('scope_offset', 'matching scope offset value'),
              create_finding_signature('scope_offset_compressed', 'matching scope offset compressed value')
            ],
            identifiers: [matching_report_identifier],
            scanner: report_scanner
          )

          report = create(:ci_reports_security_report, findings: [report_finding], pipeline: pipeline)
          service = described_class.new(report)

          {
            vuln_finding_offset: vuln_finding_offset,
            vuln_finding_compressed: vuln_finding_compressed,
            report_finding: report_finding,
            report: report,
            service: service
          }
        end

        let(:test_data) { create_multiple_matches_test_data }

        it 'overrides uuid based on the highest priority matching signature' do
          allow_next_instance_of(Array) do |instance|
            allow(instance).to receive(:sort_by).and_call_original
          end

          # Ensure the signatures have their priority values defined
          expect(test_data[:report_finding].signatures.first).to receive(:priority).and_return(1)
          expect(test_data[:report_finding].signatures.last).to receive(:priority).and_return(2)

          test_data[:service].execute

          # Iff the highest priority signature (scope_offset_compressed) was used,
          # the report finding's uuid should match the compressed finding's UUID
          expect(test_data[:report_finding].uuid).to eq(test_data[:vuln_finding_compressed].uuid)

          # It should not match the offset finding's uuid,
          # otherwise priotization would not work propery
          expect(test_data[:report_finding].uuid).not_to eq(test_data[:vuln_finding_offset].uuid)
        end
      end

      context 'with different tracked context' do
        let(:service) { described_class.new(report) }
        let(:other_tracked_context) do
          create(
            :security_project_tracked_context, :tracked,
            context_name: 'other-branch',
            project: pipeline.project
          )
        end

        context 'when an existing finding matches but belongs to a different tracked context' do
          let(:report) { create(:ci_reports_security_report, findings: [report_finding], pipeline: pipeline) }
          let(:report_finding) do
            create(
              :ci_reports_security_finding,
              uuid: SecureRandom.uuid,
              context_unaware_uuid: SecureRandom.uuid,
              vulnerability_finding_signatures_enabled: true,
              signatures: [create_finding_signature('location', 'cross context signature')],
              identifiers: [matching_report_identifier],
              scanner: report_scanner
            )
          end

          let(:existing_finding) do
            create(
              :vulnerabilities_finding,
              project: pipeline.project,
              uuid: SecureRandom.uuid,
              new_uuid: SecureRandom.uuid,
              primary_identifier: vulnerability_identifier,
              scanner: vulnerability_scanner,
              project_tracked_context: other_tracked_context
            )
          end

          before do
            create(:vulnerabilities_finding_signature, :location,
              finding: existing_finding,
              signature_sha: Digest::SHA1.digest('cross context signature'))
          end

          it 'updates only context_unaware_uuid and leaves uuid unchanged' do
            expect { service.execute }
              .to change { report_finding.context_unaware_uuid }.to(existing_finding.context_unaware_uuid)
              .and not_change { report_finding.uuid }
              .and not_change { report_finding.overridden_uuid }
          end
        end

        context 'when the existing context_unaware_uuid is already present in the batch' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- All helpers are needed
          let(:shared_context_unaware_uuid) { SecureRandom.uuid }

          let(:existing_finding_1) do
            create(
              :vulnerabilities_finding,
              project: pipeline.project,
              uuid: SecureRandom.uuid,
              new_uuid: shared_context_unaware_uuid,
              primary_identifier: vulnerability_identifier,
              scanner: vulnerability_scanner,
              project_tracked_context: other_tracked_context
            )
          end

          let(:existing_finding_2) do
            create(
              :vulnerabilities_finding,
              project: pipeline.project,
              uuid: SecureRandom.uuid,
              new_uuid: shared_context_unaware_uuid,
              primary_identifier: vulnerability_identifier,
              scanner: vulnerability_scanner,
              project_tracked_context: other_tracked_context
            )
          end

          let(:report_finding_1) do
            create(
              :ci_reports_security_finding,
              uuid: SecureRandom.uuid,
              context_unaware_uuid: SecureRandom.uuid,
              vulnerability_finding_signatures_enabled: true,
              signatures: [create_finding_signature('location', 'dup sig 1')],
              identifiers: [matching_report_identifier],
              scanner: report_scanner
            )
          end

          let(:report_finding_2) do
            create(
              :ci_reports_security_finding,
              uuid: SecureRandom.uuid,
              context_unaware_uuid: SecureRandom.uuid,
              vulnerability_finding_signatures_enabled: true,
              signatures: [create_finding_signature('location', 'dup sig 2')],
              identifiers: [matching_report_identifier],
              scanner: report_scanner
            )
          end

          let(:report) do
            create(
              :ci_reports_security_report,
              findings: [report_finding_1, report_finding_2],
              pipeline: pipeline
            )
          end

          before do
            create(:vulnerabilities_finding_signature, :location,
              finding: existing_finding_1,
              signature_sha: Digest::SHA1.digest('dup sig 1'))

            create(:vulnerabilities_finding_signature, :location,
              finding: existing_finding_2,
              signature_sha: Digest::SHA1.digest('dup sig 2'))
          end

          it 'only assigns the existing context_unaware_uuid to the first matching report finding' do
            expect { service.execute }
              .to change { report_finding_1.context_unaware_uuid }.to(shared_context_unaware_uuid)
              .and not_change { report_finding_2.context_unaware_uuid }
              .and not_change { report_finding_1.uuid }
              .and not_change { report_finding_2.uuid }
          end
        end

        context 'when a batch contains both same-context and different-context matches' do
          let(:same_ctx_existing_finding) do
            create(
              :vulnerabilities_finding,
              project: pipeline.project,
              uuid: SecureRandom.uuid,
              new_uuid: SecureRandom.uuid,
              primary_identifier: vulnerability_identifier,
              scanner: vulnerability_scanner,
              project_tracked_context: tracked_context
            )
          end

          let(:diff_ctx_existing_finding) do
            create(
              :vulnerabilities_finding,
              project: pipeline.project,
              uuid: SecureRandom.uuid,
              new_uuid: SecureRandom.uuid,
              primary_identifier: vulnerability_identifier,
              scanner: vulnerability_scanner,
              project_tracked_context: other_tracked_context
            )
          end

          let(:same_ctx_report_finding) do
            create(
              :ci_reports_security_finding,
              uuid: SecureRandom.uuid,
              context_unaware_uuid: SecureRandom.uuid,
              vulnerability_finding_signatures_enabled: true,
              signatures: [create_finding_signature('location', 'same ctx sig')],
              identifiers: [matching_report_identifier],
              scanner: report_scanner
            )
          end

          let(:diff_ctx_report_finding) do
            create(
              :ci_reports_security_finding,
              uuid: SecureRandom.uuid,
              context_unaware_uuid: SecureRandom.uuid,
              vulnerability_finding_signatures_enabled: true,
              signatures: [create_finding_signature('location', 'diff ctx sig')],
              identifiers: [matching_report_identifier],
              scanner: report_scanner
            )
          end

          let(:report) do
            create(
              :ci_reports_security_report,
              findings: [same_ctx_report_finding, diff_ctx_report_finding],
              pipeline: pipeline
            )
          end

          before do
            create(:vulnerabilities_finding_signature, :location,
              finding: same_ctx_existing_finding,
              signature_sha: Digest::SHA1.digest('same ctx sig'))

            create(:vulnerabilities_finding_signature, :location,
              finding: diff_ctx_existing_finding,
              signature_sha: Digest::SHA1.digest('diff ctx sig'))
          end

          it 'fully overrides the same-context finding and only updates context_unaware_uuid on the other' do
            previous_uuid = same_ctx_report_finding.uuid

            expect { service.execute }
              .to change { same_ctx_report_finding.uuid }.to(same_ctx_existing_finding.uuid)
              .and change { same_ctx_report_finding.overridden_uuid }.to(previous_uuid)
              .and change { same_ctx_report_finding.context_unaware_uuid }.to(same_ctx_existing_finding.context_unaware_uuid)
              .and change { diff_ctx_report_finding.context_unaware_uuid }.to(diff_ctx_existing_finding.context_unaware_uuid)
              .and not_change { diff_ctx_report_finding.uuid }
              .and not_change { diff_ctx_report_finding.overridden_uuid }
          end
        end
      end
    end

    context 'when the `vulnerability_finding_signatures` is disabled' do
      before do
        stub_licensed_features(vulnerability_finding_signatures: false)
      end

      it 'does not override finding uuids despite signatures being present' do
        expect { override_uuids }
          .to not_change { matching_report_finding_by_signature.uuid }
          .and not_change { matching_report_finding_by_signature.overridden_uuid }
          .and not_change { matching_report_finding_by_location.uuid }
          .and not_change { matching_report_finding_by_location.overridden_uuid }
      end
    end
  end
end
