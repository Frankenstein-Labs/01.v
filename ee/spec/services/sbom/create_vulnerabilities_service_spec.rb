# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::CreateVulnerabilitiesService, feature_category: :software_composition_analysis do
  describe '.execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :small_repo, :with_default_tracked_context) }
    let_it_be(:scanner) { create(:vulnerabilities_scanner, :sbom_scanner, project: project) }

    let_it_be_with_reload(:pipeline) do
      create(:ee_ci_pipeline, user: user, ref: project.default_branch, project: project)
    end

    let(:occurrence) { occurrences.first }
    let(:occurrences_count) { 5 }
    let(:known_affected_range) { "<9999" }
    let(:sbom_report) { pipeline.sbom_reports.reports.first }

    subject(:result) { described_class.execute(pipeline.id) }

    def sanitized_distro_version(source)
      "#{source.operating_system_name} #{source.operating_system_version&.gsub(/\.\d$/, '')}"
    end

    shared_examples 'skip processing' do
      it 'does not add vulnerabilities to the database' do
        expect { result }.not_to change { Vulnerability.count }
      end

      it 'does not call MarkAsResolvedService' do
        expect(Security::Ingestion::MarkAsResolvedService).not_to receive(:execute)
        result
      end

      it 'tracks internal event with proper values', :freeze_time do
        expect { result }.to trigger_internal_events('cvs_on_sbom_change')
          .with(
            project: pipeline.project,
            additional_properties: {
              label: 'pipeline_info',
              property: pipeline.id.to_s,
              start_time: Time.current.iso8601,
              end_time: Time.current.iso8601,
              possibly_affected_sbom_occurrences: 0,
              known_affected_sbom_occurrences: 0,
              sbom_occurrences_semver_dialects_errors_count: 0
            }
          )
      end
    end

    shared_examples 'process SBOM report' do |expected_report_type|
      it 'creates vulnerabilities for each advisory' do
        result

        expected_vulnerability_attributes = affected_packages.map do |affected_package|
          have_attributes(
            author_id: user.id,
            project_id: project.id,
            state: 'detected',
            report_type: expected_report_type.to_s,
            present_on_default_branch: true,
            title: affected_package.advisory.title,
            severity: affected_package.advisory.cvss_v3.severity.downcase,
            finding_description: affected_package.advisory.description,
            solution: affected_package.solution)
        end

        expect(Vulnerability.all).to match_array(expected_vulnerability_attributes)
      end

      it 'calls MarkAsResolvedService with expected arguments' do
        expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute)
          .with(pipeline, scanner, anything, project.security_project_tracked_contexts.first, expected_report_type)

        result
      end

      it 'tracks internal event with proper values', :freeze_time do
        expect { result }.to trigger_internal_events('cvs_on_sbom_change')
          .with(
            project: pipeline.project,
            additional_properties: {
              label: 'pipeline_info',
              property: pipeline.id.to_s,
              start_time: Time.current.iso8601,
              end_time: Time.current.iso8601,
              possibly_affected_sbom_occurrences: sbom_report.components.count,
              known_affected_sbom_occurrences: affected_packages.count,
              sbom_occurrences_semver_dialects_errors_count: 0
            }
          )
      end

      it 'sets tracked context for all findings' do
        result

        expect(Vulnerabilities::Finding.pluck(:security_project_tracked_context_id))
          .to all(eq(project.security_project_tracked_contexts.first.id))
      end

      context 'when tracked context creation fails' do
        before do
          allow_next_instance_of(Security::ProjectTrackedContexts::FindOrCreateService) do |instance|
            allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Create error'))
          end
        end

        it 'raises an ArgumentError' do
          expect { result }.to raise_error(ArgumentError, 'Create error')
        end
      end

      context 'when an existing vulnerability is missing from the report' do
        context 'when report type is matching' do
          before do
            SecApplicationRecord.feature_flagged_transaction_for(project) do
              create(:vulnerability,
                :with_scanner, :with_read,
                project: project, report_type: expected_report_type, scanner: scanner
              )
            end
          end

          it 'marks vulnerability as no longer detected' do
            existing_vulnerability = Vulnerability.last
            expect { result }.to change { existing_vulnerability.reload.resolved_on_default_branch }.to(true)
          end

          it 'creates DetectionTransition record' do
            existing_vulnerability = Vulnerability.last
            expect { result }.to change {
              Vulnerabilities::DetectionTransition.where(
                vulnerability_occurrence_id: existing_vulnerability.findings.pluck(:id)
              ).count
            }.by(1)
          end
        end

        context 'when report type is NOT matching' do
          before do
            other_report_type = if expected_report_type == :container_scanning
                                  :container_scanning_for_registry
                                else
                                  :container_scanning
                                end

            finding = create(:vulnerabilities_finding, scanner: scanner, project: project)
            create(:vulnerability, findings: [finding], project: project, report_type: other_report_type)
          end

          it 'does not mark vulnerability as no longer detected' do
            existing_vulnerability = Vulnerability.last
            expect { result }.not_to change { existing_vulnerability.reload.resolved_on_default_branch }.from(false)
          end

          it 'does not create DetectionTransition record' do
            existing_vulnerability = Vulnerability.last
            expect { result }.not_to change {
              Vulnerabilities::DetectionTransition.where(
                vulnerability_occurrence_id: existing_vulnerability.findings.pluck(:id)
              ).count
            }
          end
        end
      end
    end

    describe 'execute' do
      context 'when SBOM does not provide GitLab taxonomy properties' do
        let!(:ci_build) { create(:ee_ci_build, :cyclonedx_3rd_party, pipeline: pipeline, project: project) }

        it 'has no source' do
          expect(sbom_report.source).to be_nil
        end

        it 'persists the missing source error' do
          expected_error = {
            "message" => "Required GitLab CycloneDX properties are missing. " \
              "This will prevent vulnerability scanning and may result in incomplete license and package information.",
            "help_link" => "user/application_security/dependency_scanning" \
              "/dependency_scanning_sbom/#bringing-your-own-sbom"
          }

          result

          expect(pipeline.sbom_report_ingestion_errors).to eq([[expected_error]])
        end

        it_behaves_like 'skip processing'
      end

      context 'when SBOM has a Dependency Scanning taxonomy properties' do
        let!(:ci_build) { create(:ee_ci_build, :cyclonedx_dependency_scanning, pipeline: pipeline, project: project) }

        it 'has dependency_scanning source type' do
          expect(sbom_report.source.source_type).to eq(:dependency_scanning)
        end

        it 'does not persist any vulnerability scanning errors' do
          expect { result }.not_to change { pipeline.sbom_report_ingestion_errors }
        end

        it_behaves_like 'skip processing'
      end

      context 'when SBOM has a Container Scanning taxonomy properties' do
        let!(:ci_build) { create(:ee_ci_build, :cyclonedx_container_scanning, pipeline: pipeline, project: project) }

        let!(:occurrences) do
          components = sbom_report.components
          Array.new(occurrences_count) do |i|
            { purl_type: components[i].purl.type, name: components[i].name, version: components[i].version,
              input_file_path: sbom_report.source.input_file_path }
          end
        end

        it 'has container_scanning source type' do
          expect(sbom_report.source.source_type).to eq(:container_scanning)
        end

        it 'does not persist any vulnerability scanning errors' do
          expect { result }.not_to change { pipeline.sbom_report_ingestion_errors }
        end

        context 'with cvs_for_container_scanning feature flag disabled' do
          before do
            stub_feature_flags(cvs_for_container_scanning: false)
          end

          it_behaves_like 'skip processing'
        end

        context 'with affected packages matching name and purl_type only' do
          before do
            create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name])
          end

          it { expect { result }.not_to change { Vulnerability.count } }
        end

        context 'with affected packages matching name, purl_type, and version' do
          let!(:affected_packages) do
            occurrences.map do |occurrence|
              create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name],
                affected_range: known_affected_range, distro_version: sanitized_distro_version(sbom_report.source))
            end
          end

          it_behaves_like 'process SBOM report', :container_scanning

          context 'with multiple affected packages with different advisories associated with a single occurrence' do
            before do
              create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name],
                affected_range: known_affected_range, distro_version: sanitized_distro_version(sbom_report.source))
            end

            it 'creates vulnerability related to both affected packages in relation to the first occurrence' do
              expect { result }.to change { Vulnerability.count }.by(occurrences_count + 1)
            end
          end

          context 'when any SemverDialect:Error is raised' do
            before do
              create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name],
                affected_range: "invalid", distro_version: sanitized_distro_version(sbom_report.source))
            end

            it 'captures the error and tracks internal metrics with the right parameters', :freeze_time do
              expect { result }.to trigger_internal_events('cvs_on_sbom_change')
                .with(
                  project: pipeline.project,
                  additional_properties:
                    {
                      label: 'pipeline_info',
                      property: pipeline.id.to_s,
                      start_time: Time.current.iso8601,
                      end_time: Time.current.iso8601,
                      possibly_affected_sbom_occurrences: sbom_report.components.count,
                      known_affected_sbom_occurrences: occurrences.count,
                      sbom_occurrences_semver_dialects_errors_count: 1
                    }
                )
            end

            it 'still create vulnerabilities for valid advisories' do
              expect { result }.to change { Vulnerability.count }.by(occurrences_count)
            end
          end
        end
      end

      context 'when SBOM has a Container Scanning for registry taxonomy properties' do
        let!(:ci_build) do
          create(:ee_ci_build, :cyclonedx_container_scanning_for_registry, pipeline: pipeline, project: project)
        end

        let!(:occurrences) do
          components = sbom_report.components
          Array.new(occurrences_count) do |i|
            { purl_type: components[i].purl.type, name: components[i].name, version: components[i].version,
              input_file_path: sbom_report.source.input_file_path }
          end
        end

        let!(:affected_packages) do
          occurrences.map do |occurrence|
            create(:pm_affected_package, purl_type: occurrence[:purl_type], package_name: occurrence[:name],
              affected_range: known_affected_range, distro_version: sanitized_distro_version(sbom_report.source))
          end
        end

        it 'has container_scanning_for_registry source type' do
          expect(sbom_report.source.source_type).to eq(:container_scanning_for_registry)
        end

        it 'does not persist any vulnerability scanning errors' do
          expect { result }.not_to change { pipeline.sbom_report_ingestion_errors }
        end

        it_behaves_like 'process SBOM report', :container_scanning_for_registry

        context 'with cvs_for_container_scanning feature flag disabled' do
          before do
            stub_feature_flags(cvs_for_container_scanning: false)
          end

          it_behaves_like 'skip processing'
        end
      end
    end
  end
end
