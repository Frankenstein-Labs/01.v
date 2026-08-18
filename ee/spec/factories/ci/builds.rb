# frozen_string_literal: true

require_relative '../../../../spec/support/helpers/ci/job_factory_helpers'

FactoryBot.define do
  factory :ee_ci_build, class: 'Ci::Build', parent: :ci_build do
    transient do
      secrets { nil }
    end

    after(:build) do |build, evaluator|
      Ci::JobFactoryHelpers.mutate_temp_job_definition(build, secrets: evaluator.secrets) if evaluator.secrets
    end

    trait :protected_environment_failure do
      failed
      failure_reason { Ci::Build.failure_reasons[:protected_environment_failure] }
    end

    %i[api_fuzzing codequality container_scanning cluster_image_scanning dast dependency_scanning
      license_scanning performance browser_performance load_performance sast
      secret_detection coverage_fuzzing repository_xray sarif].each do |report_type|
      trait :"legacy_#{report_type}" do
        success
        artifacts
        name { report_type }

        options do
          {
            artifacts: {
              paths: [Enums::Ci::JobArtifact.default_file_names[report_type]]
            }
          }
        end
      end

      trait report_type do
        options do
          {
            artifacts: {
              reports: {
                report_type => Enums::Ci::JobArtifact.default_file_names[report_type]
              }
            }
          }
        end

        after(:build) do |build|
          build.job_artifacts << build(:ee_ci_job_artifact, report_type, job: build)
        end

        after(:create) do |build|
          if Security::Scan.scan_types.include?(report_type)
            SecApplicationRecord.feature_flagged_transaction_for(build.project) do
              build.security_scans << build(:security_scan, scan_type: report_type, build: build)
            end
          end
        end
      end
    end

    trait :dependency_list do
      name { :dependency_scanning }

      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :dependency_list, job: build)
      end
    end

    trait :dependency_scanning_with_matching_licenses do
      name { :dependency_scanning }

      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :dependency_scanning_with_matching_licenses_data, job: build)
        build.job_artifacts << build(:ee_ci_job_artifact, :license_scanning, job: build)
      end
    end

    trait :cyclonedx_with_matching_dependency_files do
      name { :dependency_scanning }

      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :dependency_scanning_with_matching_licenses_data, job: build)
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx, job: build)
      end
    end

    trait :metrics do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :metrics, job: build)
      end
    end

    # has two metrics, one duplicated with :metrics above
    trait :metrics_alternate do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :metrics_alternate, job: build)
      end
    end

    trait :sast_feature_branch do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :sast_feature_branch, job: build)
      end
    end

    trait :advanced_sast do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :advanced_sast, job: build)
      end
    end

    trait :sast_differential_scan do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :sast_differential_scan, job: build)
      end
    end

    trait :sast_semgrep do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :sast_semgrep, job: build)
      end
    end

    trait :secret_detection_feature_branch do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :secret_detection_feature_branch, job: build)
      end
    end

    trait :dast_feature_branch do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :dast_feature_branch, job: build)
      end
    end

    trait :container_scanning_feature_branch do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :container_scanning_feature_branch, job: build)
      end
    end

    trait :corrupted_container_scanning_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :corrupted_container_scanning_report, job: build)
      end
    end

    trait :cluster_image_scanning_feature_branch do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cluster_image_scanning_feature_branch, job: build)
      end
    end

    trait :corrupted_cluster_image_scanning_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :corrupted_cluster_image_scanning_report, job: build)
      end
    end

    trait :dependency_scanning_feature_branch do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :dependency_scanning_feature_branch, job: build)
      end
    end

    trait :dependency_scanning_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :dependency_scanning_report, job: build)
      end
    end

    trait :corrupted_dependency_scanning_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :corrupted_dependency_scanning_report, job: build)
      end
    end

    trait :license_scanning_feature_branch do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :license_scanning_feature_branch, job: build)
      end
    end

    trait :corrupted_license_scanning_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :license_scan, :with_corrupted_data, job: build)
      end
    end

    trait :low_severity_dast_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :low_severity_dast_report, job: build)
      end
    end

    %w[1 1_1 2 2_1].each do |version|
      trait :"license_scan_v#{version}" do
        after :build do |build|
          build.job_artifacts << build(:ee_ci_job_artifact, :license_scan, :"v#{version}", job: build)
        end
      end
    end

    trait :license_scanning_custom_license do
      after :build do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :license_scanning_custom_license, job: build)
      end
    end

    trait :requirements_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :all_passing_requirements, job: build)
      end
    end

    trait :requirements_v2_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :all_passing_requirements_v2, job: build)
      end
    end

    trait :coverage_fuzzing_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :coverage_fuzzing, job: build)
      end
    end

    trait :api_fuzzing_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :api_fuzzing, job: build)
      end
    end

    trait :cyclonedx do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx, job: build)
      end
    end

    trait :cyclonedx_with_license do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx_with_license, job: build)
      end
    end

    trait :cyclonedx_3rd_party do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx_3rd_party, job: build)
      end
    end

    trait :cyclonedx_dependency_scanning do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx_dependency_scanning, job: build)
      end
    end

    trait :cyclonedx_container_scanning do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx_container_scanning, job: build)
      end
    end

    trait :cyclonedx_container_scanning_for_registry do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx_container_scanning_for_registry, job: build)
      end
    end

    trait :cyclonedx_pypi_only do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :cyclonedx_pypi_only, job: build)
      end
    end

    trait :corrupted_cyclonedx do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :corrupted_cyclonedx, job: build)
      end
    end

    trait :with_invalid_cyclonedx_report do
      after(:build) do |build|
        build.job_artifacts << build(:ee_ci_job_artifact, :invalid_cyclonedx, job: build)
      end
    end

    trait :execution_policy_job do
      options do
        {
          policy: {
            name: 'My policy'
          }
        }
      end
    end

    trait :execution_policy_job_with_variables_override do
      execution_policy_job

      transient do
        variables_override_exceptions { ['TEST_VAR'] }
      end

      after(:build) do |build, evaluator|
        updated_options = build.options.deep_merge(
          policy: { variables_override: { allowed: false, exceptions: evaluator.variables_override_exceptions } }
        )

        Ci::JobFactoryHelpers.mutate_temp_job_definition(build, options: updated_options)
      end
    end
  end
end
