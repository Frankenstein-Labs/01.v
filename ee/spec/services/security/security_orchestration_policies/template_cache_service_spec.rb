# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::TemplateCacheService, "#fetch", feature_category: :security_policy_management do
  let(:scan_type) { "sast" }
  let(:scan_template) { 'default' }

  subject(:fetch) { described_class.new.fetch(scan_type, template: scan_template) }

  Security::SecurityOrchestrationPolicies::CiAction::Template::SCAN_TEMPLATES.each_key do |scan_type|
    context scan_type.to_s do
      it { is_expected.to be_a(Hash).and satisfy(&:any?) }

      context "when fetching latest template" do
        let(:scan_template) { 'latest' }

        it { is_expected.to be_a(Hash).and satisfy(&:any?) }
      end

      if Security::SecurityOrchestrationPolicies::CiAction::Template::SCAN_TYPES_WITH_VERSIONED_TEMPLATES
        .key?(scan_type.to_sym)
        context "when fetching versioned template" do
          let(:scan_template) { 'v1' }

          it { is_expected.to be_a(Hash).and satisfy(&:any?) }
        end
      end
    end
  end

  describe "cache misses" do
    it "instantiates" do
      expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil, name: "Jobs/SAST").and_call_original

      fetch
    end

    context "when cache matches `scan_type` but not `latest`" do
      before do
        described_class.new.fetch(scan_type, template: "default")
      end

      it "instantiates" do
        expect(::TemplateFinder).to receive(:build).and_call_original

        fetch
      end
    end

    context "when fetching latest template" do
      let(:scan_template) { 'latest' }

      it "instantiates" do
        expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil,
          name: "Jobs/SAST.latest").and_call_original

        fetch
      end
    end

    context "when fetching versioned template for versioned scan type" do
      let(:scan_type) { "dependency_scanning" }
      let(:scan_template) { "v2" }

      it "instantiates" do
        expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil,
          name: "Jobs/Dependency-Scanning.v2").and_call_original

        fetch
      end
    end
  end

  describe "cache hits" do
    before do
      fetch
    end

    it "does not instantiate" do
      expect(::TemplateFinder).not_to receive(:build)

      fetch
    end

    context "when cache key includes version" do
      let(:scan_type) { "sast" }
      let(:scan_template) { "v1" }

      before do
        described_class.new.fetch(scan_type, template: scan_template)
      end

      it "does not instantiate" do
        expect(::TemplateFinder).not_to receive(:build)

        fetch
      end
    end
  end
end
