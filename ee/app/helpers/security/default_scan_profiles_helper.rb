# frozen_string_literal: true

module Security
  module DefaultScanProfilesHelper
    def self.default_scan_profiles
      [
        build_secret_detection_scan_profile,
        build_sast_scan_profile,
        build_dependency_scanning_scan_profile,
        build_dependency_scanning_post_processing_profile
      ]
    end

    def self.build_secret_detection_scan_profile
      Security::ScanProfile.new(
        scan_type: :secret_detection,
        name: 'Secret Detection (default)',
        description: "Protect your repository from leaked secrets like API keys, tokens, and passwords. " \
          "This profile uses industry-standard rules optimized to minimize false positives. " \
          "When enabled, secrets are detected in real time during git push events and blocked " \
          "before they're committed.",
        gitlab_recommended: true,
        scan_profile_triggers_attributes: [
          { trigger_type: :git_push_event },
          { trigger_type: :default_branch_pipeline },
          { trigger_type: :merge_request_pipeline }
        ]
      )
    end

    def self.build_sast_scan_profile
      Security::ScanProfile.new(
        scan_type: :sast,
        name: 'SAST (default)',
        description: "Identify security vulnerabilities in your source code before they reach production. " \
          "This profile scans for issues like SQL injection, cross-site scripting, hardcoded credentials, and " \
          "insecure data handling. It uses GitLab's curated ruleset, continuously updated to detect real issues " \
          "while minimizing false positives.",
        gitlab_recommended: true,
        scan_profile_triggers_attributes: [
          { trigger_type: :default_branch_pipeline },
          { trigger_type: :merge_request_pipeline }
        ]
      )
    end

    def self.build_dependency_scanning_scan_profile
      Security::ScanProfile.new(
        scan_type: :dependency_scanning,
        name: 'Dependency Scanning (default)',
        description: "Identify known vulnerabilities in your project's open source dependencies before they reach " \
          "production. This profile scans all dependencies — including transitive ones — across merge request and " \
          "branch pipelines, so security issues are caught early and compared against your default branch.",
        gitlab_recommended: true,
        scan_profile_triggers_attributes: [
          { trigger_type: :default_branch_pipeline },
          { trigger_type: :merge_request_pipeline }
        ]
      )
    end

    def self.build_dependency_scanning_post_processing_profile
      Security::ScanProfile.new(
        scan_type: :dependency_scanning_post_processing,
        name: 'Dependency Scanning Auto-Remediation (default)',
        description: "Automatically resolve known vulnerabilities in your project's open source dependencies. " \
          "This profile opens merge requests that upgrade affected dependencies to secure versions whenever new " \
          "vulnerabilities are detected, so fixes are proposed for you without manual triage.",
        gitlab_recommended: true,
        scan_profile_triggers_attributes: [
          { trigger_type: :sbom_ingested }
        ]
      )
    end
  end
end
