# frozen_string_literal: true

FactoryBot.define do
  factory :ee_ci_job_artifact, class: '::Ci::JobArtifact', parent: :ci_job_artifact do
    trait :verification_succeeded do
      common_security_report # with file
      after(:create) do |instance, _|
        instance.verification_checksum = 'abc'
        instance.verification_state = Ci::JobArtifact.verification_state_value(:verification_started)
        instance.verification_succeeded!
      end
    end

    trait :verification_failed do
      common_security_report # with file

      # Geo::VerifiableReplicator#after_verifiable_update tries to verify the replicable async and
      # marks it as verification pending when the model record is created/updated.
      #
      # Tip: You must set current node to primary, or else you can get a PG::ForeignKeyViolation
      # because save_verification_details is returning early.
      after(:create) do |instance, evaluator|
        instance.verification_failure = evaluator.verification_failure || 'Could not calculate the checksum'
        instance.verification_failed!
      end
    end

    trait :sast_without_any_identifiers do
      file_type { :sast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-without-any-identifiers.json'), 'application/json')
      end
    end

    trait :sast_with_signatures_and_vulnerability_flags do
      file_type { :sast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-with-signatures-and-flags.json'), 'application/json')
      end
    end

    trait :sast_with_signatures_and_vulnerability_flags_with_duplicate_identifiers do
      file_type { :sast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-with-signatures-and-flags-duplicate-identifiers.json'), 'application/json')
      end
    end

    trait :sast_observability do
      file_format { :raw }
      file_type { :sast }

      after(:stub, :build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-observability.json'), 'application/json')
      end
    end

    trait :sast_observability_performance do
      file_format { :raw }
      file_type { :sast }

      after(:stub, :build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-observability-performance.json'), 'application/json')
      end
    end

    trait :secret_detection_observability do
      file_format { :raw }
      file_type { :secret_detection }

      after(:stub, :build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-secret-detection-report-observability.json'), 'application/json')
      end
    end

    trait :gitlab_secrets_scanner_observability do
      file_format { :raw }
      file_type { :secret_detection }

      after(:stub, :build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-secret-detection-report-gss-observability.json'), 'application/json')
      end
    end

    trait :empty_sast_report do
      file_type { :sast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-empty-sast-report.json'), 'application/json')
      end
    end

    trait :advanced_sast do
      file_format { :raw }
      file_type { :sast }

      after(:stub, :build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-advanced-sast-full.json'), 'application/json')
      end
    end

    trait :sast_differential_scan do
      file_format { :raw }
      file_type { :sast }

      after(:stub, :build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-differential.json'), 'application/json')
      end
    end

    trait :semgrep_web_vulnerabilities do
      file_type { :sast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/semgrep-web-vulnerabilities.json'),
          'application/json'
        )
      end
    end

    trait :semgrep_api_vulnerabilities do
      file_type { :sast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/semgrep-api-vulnerabilities.json'),
          'application/json'
        )
      end
    end

    trait :sast_semgrep do
      file_type { :sast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-sast-report-semgrep.json'),
          'application/json'
        )
      end
    end

    trait :dast_with_evidence do
      file_type { :dast }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-with-evidence.json'), 'application/json')
      end
    end

    trait :dast do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report.json'), 'application/json')
      end
    end

    trait :dast_observability do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-observability.json'), 'application/json')
      end
    end

    trait :test_observability do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-test.json'), 'application/json')
      end
    end

    trait :dast_missing_version do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-missing-version.json'), 'application/json')
      end
    end

    trait :dast_feature_branch do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/feature-branch/gl-dast-report.json'), 'application/json')
      end
    end

    trait :dast_multiple_sites do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-multiple-sites.json'), 'application/json')
      end
    end

    trait :dast_missing_scan_field do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-missing-scan.json'), 'application/json')
      end
    end

    trait :dast_large_scanned_resources_field do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-large-scanned-resources.json'), 'application/json')
      end
    end

    trait :low_severity_dast_report do
      file_format { :raw }
      file_type { :dast }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dast-report-low-severity.json'), 'application/json')
      end
    end

    trait :license_scanning do
      file_type { :license_scanning }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-license-scanning-report.json'), 'application/json')
      end
    end

    trait :license_scanning_feature_branch do
      file_type { :license_scanning }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/feature-branch/gl-license-scanning-report.json'), 'application/json')
      end
    end

    trait :license_scanning_custom_license do
      file_type { :license_scanning }
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/license_compliance/gl-license-scanning-report-custom-license.json'), 'application/json')
      end
    end

    trait :performance do
      file_format { :raw }
      file_type { :performance }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'text/plain')
      end
    end

    trait :browser_performance do
      file_format { :raw }
      file_type { :browser_performance }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'text/plain')
      end
    end

    trait :load_performance do
      file_format { :raw }
      file_type { :load_performance }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'text/plain')
      end
    end

    trait :dependency_scanning do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dependency-scanning-report.json'), 'application/json')
      end
    end

    trait :dependency_scanning_with_new_DS_analyzer do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dependency-scanning-report-new-DS-analyzer.json'), 'application/json')
      end
    end

    trait :dependency_scanning_remediation do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/remediations/gl-dependency-scanning-report.json'), 'application/json')
      end
    end

    trait :dependency_scanning_feature_branch do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/feature-branch/gl-dependency-scanning-report.json'), 'application/json')
      end
    end

    trait :dependency_scanning_python do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-dependency-scanning-report-python.json'), 'application/json')
      end
    end

    trait :corrupted_dependency_scanning_report do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'application/json')
      end
    end

    ['', 'python', 'maven'].each do |analyzer|
      trait :"dependency_scanning_gemnasium#{analyzer.present? ? "_#{analyzer}" : ''}_observability" do
        file_format { :raw }
        file_type { :dependency_scanning }

        after(:build) do |artifact, _|
          artifact.file = fixture_file_upload(
            Rails.root.join("ee/spec/fixtures/security_reports/master/gl-dependency-scanning-report-gemnasium#{analyzer.present? ? "-#{analyzer}" : ''}-observability.json"), 'application/json')
        end
      end
    end

    trait :dependency_scanning_observability do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join("ee/spec/fixtures/security_reports/master/gl-dependency-scanning-report-observability.json"), 'application/json')
      end
    end

    trait :container_scanning do
      file_format { :raw }
      file_type { :container_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-container-scanning-report.json'), 'application/json')
      end
    end

    trait :cluster_image_scanning do
      file_format { :raw }
      file_type { :cluster_image_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-cluster-image-scanning-report.json'), 'application/json')
      end
    end

    trait :container_scanning_feature_branch do
      file_format { :raw }
      file_type { :container_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/feature-branch/gl-container-scanning-report.json'), 'application/json')
      end
    end

    trait :corrupted_container_scanning_report do
      file_format { :raw }
      file_type { :container_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'application/json')
      end
    end

    trait :cluster_image_scanning_feature_branch do
      file_format { :raw }
      file_type { :cluster_image_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/feature-branch/gl-cluster-image-scanning-report.json'), 'application/json')
      end
    end

    trait :corrupted_cluster_image_scanning_report do
      file_format { :raw }
      file_type { :cluster_image_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'application/json')
      end
    end

    trait :metrics do
      file_format { :gzip }
      file_type { :metrics }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/metrics.txt.gz'), 'application/x-gzip')
      end
    end

    trait :metrics_alternate do
      file_format { :gzip }
      file_type { :metrics }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/alternate_metrics.txt.gz'), 'application/x-gzip')
      end
    end

    trait :dependency_list do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/dependency_list/gl-dependency-scanning-report.json'), 'application/json')
      end
    end

    trait :dependency_scanning_with_matching_licenses_data do
      file_format { :raw }
      file_type { :dependency_scanning }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/dependency_list/with_matching_licenses/gl-dependency-scanning-report.json'), 'application/json')
      end
    end

    trait :license_scan do
      file_type { :license_scanning }
      file_format { :raw }
    end

    %w[1 1_1 2 2_1].each do |version|
      trait :"v#{version}" do
        after(:build) do |artifact, _|
          filename = "gl-#{artifact.file_type.dasherize}-report-v#{version.sub(/_/, '.')}.json"
          path = Rails.root.join("ee/spec/fixtures/security_reports/license_compliance/#{filename}")
          artifact.file = fixture_file_upload(path, "application/json")
        end
      end
    end

    trait :with_corrupted_data do
      after :build do |artifact, _|
        path = Rails.root.join('spec/fixtures/trace/sample_trace')
        artifact.file = fixture_file_upload(path, 'application/json')
      end
    end

    trait :all_passing_requirements do
      file_format { :raw }
      file_type { :requirements }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/requirements_management/all_passing_report.json'), 'application/json')
      end
    end

    trait :all_passing_requirements_v2 do
      file_format { :raw }
      file_type { :requirements_v2 }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/requirements_management/all_passing_report.json'), 'application/json')
      end
    end

    trait :coverage_fuzzing do
      file_format { :raw }
      file_type { :coverage_fuzzing }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-coverage-fuzzing-report.json'),
          'application/json')
      end
    end

    trait :api_fuzzing do
      file_format { :raw }
      file_type { :api_fuzzing }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/master/gl-api-fuzzing-report.json'),
          'application/json')
      end
    end

    trait :sarif do
      file_format { :raw }
      file_type { :sarif }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/sarif/minimal.sarif.json'),
          'application/json')
      end
    end

    trait :cyclonedx do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :cyclonedx_with_license do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-with-license.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :cyclonedx_3rd_party do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-3rd-party.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :cyclonedx_dependency_scanning do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-dependency-scanning.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :cyclonedx_container_scanning do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-container-scanning.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :cyclonedx_container_scanning_for_registry do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-container-scanning-for-registry.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :cyclonedx_pypi_only do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-pypi-only.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :corrupted_cyclonedx do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-corrupted.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :invalid_cyclonedx do
      file_format { :gzip }
      file_type { :cyclonedx }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/sbom/gl-sbom-invalid.cdx.json.gz'),
          'application/x-gzip')
      end
    end

    trait :repository_xray do
      file_format { :gzip }
      file_type { :repository_xray }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/repository_xray/gl-repository-xray.json.gz'), 'application/x-gzip')
      end
    end

    trait :sarif do
      file_format { :raw }
      file_type { :sarif }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('ee/spec/fixtures/security_reports/sarif/valid.sarif.json'), 'application/json')
      end
    end
  end
end
