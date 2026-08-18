# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProcessScanEventsService, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :test_observability) }

    let(:pipeline) { artifact.job.pipeline }

    let(:internal_event_name) { 'dummy_event_for_testing_abcdefg' }
    let(:internal_event_definition) do
      Gitlab::Tracking::EventDefinition.new(
        "config/events/#{internal_event_name}",
        {
          action: internal_event_name,
          internal_events: true,
          identifiers: %w[project user],
          additional_properties: {
            label: { description: 'desc' },
            property: { description: 'desc' },
            value: { description: 'desc' },
            content_type: { description: 'desc' },
            operations: { description: 'desc' },
            overrides_command: { description: 'desc' },
            per_request_script: { description: 'desc' },
            status: { description: 'desc' },
            version: { description: 'desc' },
            version_major: { description: 'desc' },
            time_s: { description: 'desc' },
            parse_time_s: { description: 'desc' }
          }
        }
      )
    end

    before do
      artifact.job.update!(status: :success)
      allow(Gitlab::Tracking::EventDefinition).to receive_messages(
        find: internal_event_definition, internal_event_exists?: true)
    end

    shared_examples 'process security report' do
      context 'with security report' do
        let!(:service_object) { described_class.new(pipeline) }

        context 'with known event' do
          before do
            allow(service_object).to receive(:event_allowed?).with(internal_event_name).and_return(true)
          end

          it "calls track_internal_event with 'testing_unknown_events_abcdefg'" do
            expect { service_object.execute }.to trigger_internal_events(internal_event_name).with(
              project: pipeline.project,
              additional_properties: {
                content_type: "json",
                label: "openapi",
                operations: 10,
                overrides_command: 1,
                per_request_script: 1,
                property: "294f623d-b2ce-4568-8008-6fd4a5fb3330",
                status: "completed",
                value: 60,
                version: "5.5.5",
                version_major: 5
              }
            )
          end
        end

        context 'with unknown event' do
          it 'tracks and raises error in dev/test ::Security::ProcessScanEventsService::ScanEventNotInAllowListError' do
            expect { service_object.execute }.to raise_error(
              ::Security::ProcessScanEventsService::ScanEventNotInAllowListError,
              "Event not in allow list 'dummy_event_for_testing_abcdefg'")
          end

          it 'tracks error in prod ::Security::ProcessScanEventsService::ScanEventNotInAllowListError' do
            allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
            expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
              instance_of(::Security::ProcessScanEventsService::ScanEventNotInAllowListError), any_args)

            service_object.execute
          end
        end
      end
    end

    context 'with successful job' do
      include_examples 'process security report'
    end

    context 'with failed job' do
      before do
        artifact.job.update!(status: :failed)
      end

      include_examples 'process security report'
    end

    context 'with invalid security report JSON' do
      let(:artifact_invalid_json) { create(:ee_ci_job_artifact, :test_observability) }
      let(:service_object) { described_class.new(artifact_invalid_json.job.pipeline) }

      before do
        # rubocop:disable AnyInstanceOf -- Each call to ProcessScanEventsService::report_artifacts results in different object instances being returned
        allow_any_instance_of(::Ci::JobArtifact).to receive(:each_blob)
                                                      .and_yield("[][]{{(*$)@&%(*@&%^@$!_@)iowuejrfiqwoiqwfqwdfoij")
        # rubocop:enable AnyInstanceOf -- AST: Dynamic Analysis
      end

      it 'tracks error parsing job artifact' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(::JSON::ParserError),
          {
            pipeline: an_instance_of(::Ci::Pipeline),
            artifact: an_instance_of(::Ci::JobArtifact)
          }
        )

        expect { service_object.execute }.not_to trigger_internal_events(internal_event_name)
      end
    end

    context 'when additional_properties contain BigDecimal values' do
      let!(:service_object) { described_class.new(pipeline) }

      before do
        allow(service_object).to receive(:event_allowed?).with(internal_event_name).and_return(true)
        allow(service_object).to receive(:scan_observability_events_data).and_return(
          [
            {
              event: internal_event_name,
              time_s: BigDecimal('1.153'),
              parse_time_s: BigDecimal('0.42')
            }
          ]
        )
      end

      it 'converts BigDecimal values to Float before tracking' do
        expect { service_object.execute }.to trigger_internal_events(internal_event_name).with(
          project: pipeline.project,
          additional_properties: {
            time_s: 1.153,
            parse_time_s: 0.42
          }
        )
      end
    end
  end

  describe 'report events' do
    context 'with SAST scan event' do
      let(:sast_artifact) { create(:ee_ci_job_artifact, :sast_observability) }
      let(:sast_pipeline) { sast_artifact.job.pipeline }
      let(:sast_service_object) { described_class.new(sast_pipeline) }
      let(:sast_scan_event_name) { 'collect_sast_scan_metrics_from_pipeline' }

      before do
        sast_artifact.job.update!(status: :success)
      end

      it "triggers event data from 'collect_sast_scan_metrics_from_pipeline'" do
        expect { sast_service_object.execute }.to trigger_internal_events(sast_scan_event_name).with(
          project: sast_pipeline.project,
          additional_properties: {
            label: "semgrep",
            property: "294f623d-b2ce-4568-8008-6fd4a5fb3330",
            value: 1,
            version: "1.1.1",
            exit_code: 2,
            override_count: 3,
            passthrough_count: 4,
            custom_exclude_path_count: 5,
            time_s: 100,
            file_count: 1000,
            language_feature_usage: '{".cpp":{"modules":6}}'
          }
        )
      end
    end

    context 'with SAST scan event carrying performance metrics' do
      let(:sast_artifact) { create(:ee_ci_job_artifact, :sast_observability_performance) }
      let(:sast_pipeline) { sast_artifact.job.pipeline }
      let(:sast_service_object) { described_class.new(sast_pipeline) }
      let(:sast_scan_event_name) { 'collect_sast_scan_metrics_from_pipeline' }

      before do
        sast_artifact.job.update!(status: :success)
      end

      it "triggers event data from 'collect_sast_scan_metrics_from_pipeline' with performance fields" do
        expected_perf_breakdown = {
          front_end_time_s: 12.5,
          import_resolution_time_s: 3.2,
          tagger_time_s: 8.1,
          slicing_time_s: 41.7,
          source_count: 812,
          sink_count: 96,
          taint_analysis_count: 96,
          taint_positive_count: 7,
          taint_p95_time_s: 0.4,
          budget_call_depth_count: 3
        }
        perf_breakdown_matcher = satisfy('match the expected perf breakdown when JSON-parsed') do |json|
          Gitlab::Json::SafeParser.parse(json) == expected_perf_breakdown.deep_stringify_keys
        end

        expect { sast_service_object.execute }.to trigger_internal_events(sast_scan_event_name).with(
          project: sast_pipeline.project,
          additional_properties: {
            label: "advanced-sast",
            property: "294f623d-b2ce-4568-8008-6fd4a5fb3330",
            value: 0,
            version: "2.0.0",
            exit_code: 0,
            override_count: 3,
            passthrough_count: 4,
            custom_exclude_path_count: 5,
            time_s: 100,
            file_count: 1000,
            language_feature_usage: '{".cpp":{"modules":6}}',
            total_size_bytes: 52428800,
            parse_time_s: 12.5,
            rule_count: 42,
            peak_memory_bytes: 2147483648,
            cpu_count: 4,
            memory_limit_bytes: 8589934592,
            pipeline_source: "merge_request_event",
            perf_breakdown: perf_breakdown_matcher
          }
        )
      end
    end

    context 'with Secret Detection scan event' do
      let(:secret_detection_artifact) { create(:ee_ci_job_artifact, :secret_detection_observability) }
      let(:secret_detection_pipeline) { secret_detection_artifact.job.pipeline }
      let(:secret_detection_service_object) { described_class.new(secret_detection_pipeline) }
      let(:secret_detection_scan_event_name) { 'collect_secrets_analyzer_scan_metrics_from_pipeline' }

      before do
        secret_detection_artifact.job.update!(status: :success)
      end

      it "triggers event data from 'collect_secrets_analyzer_scan_metrics_from_pipeline'" do
        expect do
          secret_detection_service_object.execute
        end.to trigger_internal_events(secret_detection_scan_event_name).with(
          project: secret_detection_pipeline.project,
          additional_properties: {
            time_s: 1.1530000000000001,
            exit_code: 0,
            git_strategy: "FetchRange",
            commit_count: 69,
            bytes_scanned: 12345,
            leaks_found: 1,
            repo_size_kb: 101,
            pipeline_type: "MergeRequest"
          }
        )
      end
    end

    context 'with GitLab Secrets Scanner scan event' do
      let(:gitlab_secrets_scanner_artifact) { create(:ee_ci_job_artifact, :gitlab_secrets_scanner_observability) }
      let(:gitlab_secrets_scanner_pipeline) { gitlab_secrets_scanner_artifact.job.pipeline }
      let(:gitlab_secrets_scanner_service_object) { described_class.new(gitlab_secrets_scanner_pipeline) }
      let(:gitlab_secrets_scanner_scan_event_name) { 'collect_gss_source_code_analyzer_scan_metrics_from_pipeline' }

      before do
        gitlab_secrets_scanner_artifact.job.update!(status: :success)
      end

      it "triggers event data from 'collect_gss_source_code_analyzer_scan_metrics_from_pipeline'" do
        expect do
          gitlab_secrets_scanner_service_object.execute
        end.to trigger_internal_events(gitlab_secrets_scanner_scan_event_name).with(
          user: gitlab_secrets_scanner_pipeline.user,
          project: gitlab_secrets_scanner_pipeline.project,
          namespace: gitlab_secrets_scanner_pipeline.project.namespace,
          additional_properties: {
            time_s: 1.153,
            exit_code: 0,
            git_strategy: "FetchRange",
            commit_count: 69,
            bytes_scanned: 12345,
            leaks_found: 1,
            repo_size_kb: 101,
            pipeline_type: "MergeRequest"
          }
        )
      end
    end

    context 'with DAST scan events' do
      using RSpec::Parameterized::TableSyntax

      let(:dast_artifact) { create(:ee_ci_job_artifact, :dast_observability) }
      let(:dast_pipeline) { dast_artifact.job.pipeline }
      let(:dast_service_object) { described_class.new(dast_pipeline) }

      before do
        dast_artifact.job.update!(status: :success)
      end

      where(:event_name, :expected_properties) do
        'collect_dast_scan_page_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          label: '560',
          value: 1904,
          check_items_count: 320
        }
        'collect_dast_scan_form_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          label: '68',
          value: 60,
          form_fields_found: 127,
          form_submission_attempts: 43,
          successful_submissions: 31,
          failed_submissions: 12,
          forms_per_minute: 0.88,
          successful_navigation_from_forms: 31,
          failed_navigation_from_forms: 18
        }
        'collect_dast_scan_crawl_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          label: '124',
          value: 2004,
          max_crawl_depth: 5
        }
        'collect_dast_scan_ff_form_hashing_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          label: '1904',
          value: 60,
          forms_per_minute: 0.88,
          max_crawl_depth: 5,
          average_form_depth: 4.7,
          crawl_surface_area: 2004
        }
        'collect_dast_scan_version_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          value: 6,
          label: '12',
          patch: 0
        }
        'collect_dast_scan_run_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          value: 5,
          label: '1',
          auth_type: '2',
          panic_st_f: 'main.divideByZero()',
          panic_st_l: '/path/to/your/file.go:6'
        }
        'collect_dast_scan_vulnerability_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          value: 5,
          label: '1',
          passive: 4
        }
        'collect_dast_scan_runner_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          value: 5,
          label: '1',
          arch: 'amd64'
        }
        'collect_dast_scan_config_variable_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          label: 'DAST_CONFIG_VARIABLE'
        }
        'collect_dast_scan_w3c_metrics_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          label: '1',
          value: 1,
          svg_usage: 0,
          file_api_usage: 1,
          web_rtc_usage: 1,
          web_authentication_usage: 1,
          wasm_usage: 0,
          web_share_api_usage: 1,
          trusted_types_usage: 1,
          editcontext_api_usage: 1,
          wai_aria_usage: 1
        }
        'collect_dast_scan_grouped_urls_similarity_from_pipeline' | {
          property: '294f623d-b2ce-4568-8008-6fd4a5fb3330',
          label: 'https://example.com/page/*/details',
          value: 4,
          median: 30,
          ninety_percentile: 31,
          first_quartile: 25,
          max: 34
        }
      end

      with_them do
        it "triggers event data from '#{params[:event_name]}'" do
          expect { dast_service_object.execute }.to trigger_internal_events(event_name).with(
            project: dast_pipeline.project,
            additional_properties: expected_properties
          )
        end
      end
    end

    context 'with Gemnasium scan events' do
      using RSpec::Parameterized::TableSyntax

      let(:ds_artifact) { create(:ee_ci_job_artifact, artifact) }
      let(:ds_pipeline) { ds_artifact.job.pipeline }
      let(:ds_service_object) { described_class.new(ds_pipeline) }

      where(:artifact, :event_name, :expected_properties) do
        [
          [:dependency_scanning_gemnasium_observability,
            'collect_gemnasium_scan_metrics_from_pipeline', {
              property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
              label: '6.1.9',
              value: 100
            }],
          [:dependency_scanning_gemnasium_observability,
            'collect_gemnasium_scan_sbom_metrics_from_pipeline', {
              property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
              label: 'npm',
              value: 352,
              input_file_path: "package-lock.json"
            }],
          [:dependency_scanning_gemnasium_observability,
            'collect_gemnasium_scan_performance_metrics_from_pipeline', {
              property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
              value: 40
            }],
          [:dependency_scanning_gemnasium_observability,
            'collect_gemnasium_scan_non_default_config_metrics_from_pipeline', {
              property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
              label: 'DS_INCLUDE_DEV_DEPENDENCIES'
            }],
          [:dependency_scanning_gemnasium_python_observability,
            'collect_gemnasium_python_scan_metrics_from_pipeline', {
              property: 'eb0e47db-9d04-4557-ae8e-c3b9dffc601e',
              label: '6.2.0',
              value: 15
            }],
          [:dependency_scanning_gemnasium_python_observability,
            'collect_gemnasium_python_scan_sbom_metrics_from_pipeline', {
              property: 'eb0e47db-9d04-4557-ae8e-c3b9dffc601e',
              label: 'pypi',
              value: 12,
              input_file_path: "requirements.txt"
            }],
          [:dependency_scanning_gemnasium_python_observability,
            'collect_gemnasium_python_scan_performance_metrics_from_pipeline', {
              property: 'eb0e47db-9d04-4557-ae8e-c3b9dffc601e',
              value: 28
            }],
          [:dependency_scanning_gemnasium_python_observability,
            'collect_gemnasium_python_scan_non_default_config_metrics_from_pipeline', {
              property: 'eb0e47db-9d04-4557-ae8e-c3b9dffc601e',
              label: 'DS_INCLUDE_DEV_DEPENDENCIES'
            }],
          [:dependency_scanning_gemnasium_maven_observability,
            'collect_gemnasium_maven_scan_metrics_from_pipeline', {
              property: '077e707f-175c-4eed-a998-1be56780666d',
              label: '6.2.0',
              value: 59
            }],
          [:dependency_scanning_gemnasium_maven_observability,
            'collect_gemnasium_maven_scan_sbom_metrics_from_pipeline', {
              property: '077e707f-175c-4eed-a998-1be56780666d',
              label: 'maven',
              value: 36,
              input_file_path: "pom.xml"
            }],
          [:dependency_scanning_gemnasium_maven_observability,
            'collect_gemnasium_maven_scan_performance_metrics_from_pipeline', {
              property: '077e707f-175c-4eed-a998-1be56780666d',
              value: 13
            }],
          [:dependency_scanning_gemnasium_maven_observability,
            'collect_gemnasium_maven_scan_non_default_config_metrics_from_pipeline', {
              property: '077e707f-175c-4eed-a998-1be56780666d',
              label: 'DS_INCLUDE_DEV_DEPENDENCIES'
            }]
        ]
      end

      with_them do
        it "triggers event data from '#{params[:event_name]}'" do
          expect { ds_service_object.execute }.to trigger_internal_events(event_name).with(
            project: ds_pipeline.project,
            additional_properties: expected_properties
          )
        end
      end
    end

    context 'with DS scan events' do
      using RSpec::Parameterized::TableSyntax

      let(:ds_artifact) { create(:ee_ci_job_artifact, :dependency_scanning_observability) }
      let(:ds_pipeline) { ds_artifact.job.pipeline }
      let(:ds_service_object) { described_class.new(ds_pipeline) }

      where(:event_name, :expected_properties) do
        [
          ['collect_ds_analyzer_scan_duration_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            value: 100
          }],
          ['collect_ds_analyzer_scan_sbom_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'npm',
            value: 352,
            input_file_path: 'package-lock.json'
          }],
          ['collect_ds_analyzer_scan_static_reachability_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'npm',
            value: 352,
            in_use: 10,
            input_file_path: "package-lock.json"
          }],
          ['collect_ds_analyzer_scan_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: '6.1.9',
            value: 40
          }],
          ['collect_ds_analyzer_scan_security_report_duration_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            value: 30
          }],
          ['collect_ds_analyzer_scan_static_reachability_duration_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            value: 20
          }],
          ['collect_ds_analyzer_scan_sbom_duration_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            value: 10
          }],
          ['collect_ds_analyzer_scan_java_sr_coverage_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            value: 95
          }],
          ['collect_ds_analyzer_scan_non_default_config_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'DS_INCLUDE_DEV_DEPENDENCIES'
          }],
          ['collect_ds_analyzer_scan_ci_integration_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'template:v2'
          }],
          ['collect_ds_analyzer_scan_sr_failure_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'error'
          }],
          ['collect_ds_analyzer_scan_sr_sbom_failure_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'error',
            language: 'python',
            input_file_path: "a/b/requirements.txt"
          }],
          ['collect_ds_analyzer_sbom_scan_cache_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'cache_hit',
            input_file_path: "ui/package-lock.json"
          }],
          ['collect_ds_analyzer_scan_manifest_fallback_metrics_from_pipeline', {
            property: 'e1552d18-eb8b-4e3e-bd15-a286ad1bc0f4',
            label: 'pip',
            input_file_path: "c/d/requirements.txt"
          }]
        ]
      end

      with_them do
        it "triggers event data from '#{params[:event_name]}'" do
          expect { ds_service_object.execute }.to trigger_internal_events(event_name).with(
            project: ds_pipeline.project,
            additional_properties: expected_properties
          )
        end
      end
    end
  end
end
