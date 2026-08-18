# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DefaultScanProfilesHelper, feature_category: :security_testing_configuration do
  describe '.default_scan_profiles' do
    it 'returns an array of default scan profiles' do
      profiles = described_class.default_scan_profiles

      expect(profiles).to be_an(Array)
      expect(profiles).to all(be_a(Security::ScanProfile))
    end

    it 'includes all expected scan profiles' do
      profiles = described_class.default_scan_profiles

      expect(profiles.map(&:scan_type)).to match_array(
        %w[secret_detection sast dependency_scanning dependency_scanning_post_processing]
      )
    end
  end

  shared_examples 'a default scan profile' do |scan_type:, name:, description:, trigger_types:|
    it "creates a #{scan_type} scan profile" do
      expect(profile).to be_a(Security::ScanProfile).and have_attributes(scan_type: scan_type)
    end

    it 'sets the correct attributes' do
      expect(profile).to have_attributes(
        name: name,
        gitlab_recommended: true,
        scan_type: scan_type,
        description: description
      )
    end

    it 'configures the correct trigger types' do
      expect(profile.scan_profile_triggers.size).to eq(trigger_types.size)
      expect(profile.scan_profile_triggers.map(&:trigger_type)).to match_array(trigger_types)
    end
  end

  describe '.build_secret_detection_scan_profile' do
    subject(:profile) { described_class.build_secret_detection_scan_profile }

    it_behaves_like 'a default scan profile',
      scan_type: 'secret_detection',
      name: 'Secret Detection (default)',
      description: "Protect your repository from leaked secrets like API keys, tokens, and passwords. " \
        "This profile uses industry-standard rules optimized to minimize false positives. " \
        "When enabled, secrets are detected in real time during git push events and blocked " \
        "before they're committed.",
      trigger_types: %w[git_push_event default_branch_pipeline merge_request_pipeline]
  end

  describe '.build_sast_scan_profile' do
    subject(:profile) { described_class.build_sast_scan_profile }

    it_behaves_like 'a default scan profile',
      scan_type: 'sast',
      name: 'SAST (default)',
      description: "Identify security vulnerabilities in your source code before they reach production. " \
        "This profile scans for issues like SQL injection, cross-site scripting, hardcoded credentials, and " \
        "insecure data handling. It uses GitLab's curated ruleset, continuously updated to detect real issues " \
        "while minimizing false positives.",
      trigger_types: %w[default_branch_pipeline merge_request_pipeline]
  end

  describe '.build_dependency_scanning_scan_profile' do
    subject(:profile) { described_class.build_dependency_scanning_scan_profile }

    it_behaves_like 'a default scan profile',
      scan_type: 'dependency_scanning',
      name: 'Dependency Scanning (default)',
      description: "Identify known vulnerabilities in your project's open source dependencies before they reach " \
        "production. This profile scans all dependencies — including transitive ones — across merge request and " \
        "branch pipelines, so security issues are caught early and compared against your default branch.",
      trigger_types: %w[default_branch_pipeline merge_request_pipeline]
  end

  describe '.build_dependency_scanning_post_processing_profile' do
    subject(:profile) { described_class.build_dependency_scanning_post_processing_profile }

    it_behaves_like 'a default scan profile',
      scan_type: 'dependency_scanning_post_processing',
      name: 'Dependency Scanning Auto-Remediation (default)',
      description: "Automatically resolve known vulnerabilities in your project's open source dependencies. " \
        "This profile opens merge requests that upgrade affected dependencies to secure versions whenever new " \
        "vulnerabilities are detected, so fixes are proposed for you without manual triage.",
      trigger_types: %w[sbom_ingested]
  end
end
