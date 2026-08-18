# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::RemediationDismissalChecker,
  feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  let(:purl_type) { 'gem' }
  let(:vulnerability) do
    instance_double(Vulnerability, sbom_occurrences: [instance_double(Sbom::Occurrence, purl_type: purl_type)])
  end

  subject(:checker) { described_class.new(project: project, vulnerability: vulnerability) }

  def output_with(*name_version_pairs)
    dependencies = name_version_pairs.map do |name, version|
      DependencyManagement::SecurityUpdate::OutputParser::DependencyChange.new(
        name: name, previous_version: '0.0.0', version: version
      )
    end

    DependencyManagement::SecurityUpdate::OutputParser::Result.new(dependencies: dependencies, updated_files: [])
  end

  def dismissed_mr(title, remediation: true)
    prefix = DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX
    branch = remediation ? "#{prefix}/rails-6.x" : 'some-other-branch'

    instance_double(MergeRequest, title: title, source_branch: branch)
  end

  def stub_finder(merge_requests)
    finder = instance_double(DependencyManagement::SecurityUpdate::UserClosedRemediationsFinder)
    allow(DependencyManagement::SecurityUpdate::UserClosedRemediationsFinder)
      .to receive(:new).with(project: project).and_return(finder)
    allow(finder).to receive(:for_vulnerability).with(vulnerability).and_return(merge_requests)
  end

  describe '#dismissed?' do
    context 'when there are no user-closed remediation MRs' do
      before do
        stub_finder([])
      end

      it 'returns false' do
        expect(checker.dismissed?(output_with(['rails', '6.1.5']))).to be(false)
      end
    end

    context 'when a same-finding MR dismissed a version' do
      before do
        stub_finder([dismissed_mr('Security: Update rails from 6.1.4 to 6.1.5')])
      end

      it 'is dismissed for the same version' do
        expect(checker.dismissed?(output_with(['rails', '6.1.5']))).to be(true)
      end

      it 'is dismissed for a lower version' do
        expect(checker.dismissed?(output_with(['rails', '6.1.4']))).to be(true)
      end

      it 'is not dismissed for a newer version (resurface)' do
        expect(checker.dismissed?(output_with(['rails', '6.1.6']))).to be(false)
      end
    end

    context 'when the closed MR is not on a remediation branch' do
      before do
        stub_finder([dismissed_mr('Security: Update rails from 6.1.4 to 6.1.5', remediation: false)])
      end

      it 'ignores it' do
        expect(checker.dismissed?(output_with(['rails', '6.1.5']))).to be(false)
      end
    end

    context 'with several dismissals for the same dependency' do
      before do
        stub_finder([
          dismissed_mr('Security: Update rails from 6.1.4 to 6.1.5'),
          dismissed_mr('Security: Update rails from 6.1.5 to 6.1.7')
        ])
      end

      it 'uses the highest dismissed version' do
        expect(checker.dismissed?(output_with(['rails', '6.1.7']))).to be(true)
      end
    end

    context 'when a proposed dependency has no matching dismissal' do
      before do
        stub_finder([dismissed_mr('Security: Update rails from 6.1.4 to 6.1.5')])
      end

      it 'is not dismissed (something new to propose)' do
        expect(checker.dismissed?(output_with(['rails', '6.1.5'], ['nokogiri', '1.2.3']))).to be(false)
      end
    end

    context 'with a Maven ecosystem (non-semver ordering)' do
      let(:purl_type) { 'maven' }

      before do
        stub_finder([dismissed_mr('Security: Update foo from 1.0-alpha to 1.0')])
      end

      it 'treats a stable release as newer than its pre-release' do
        expect(checker.dismissed?(output_with(['foo', '1.0']))).to be(true)
      end
    end

    context 'when a version cannot be parsed' do
      before do
        stub_finder([dismissed_mr('Security: Update rails from 6.1.4 to 6.1.5')])
        allow(SemverDialects).to receive(:parse_version).and_raise(SemverDialects::Error.new('unparseable'))
      end

      it 'logs an error and does not suppress' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'DependencyManagement: failed to compare versions for remediation dismissal',
            package_type: 'gem'
          )
        )

        expect(checker.dismissed?(output_with(['rails', '6.1.5']))).to be(false)
      end
    end

    context 'when the versions are not comparable (<=> returns nil)' do
      before do
        stub_finder([dismissed_mr('Security: Update rails from 6.1.4 to 6.1.5')])
        allow_next_instances_of_semver_dialects_result_to_be_incomparable
      end

      def allow_next_instances_of_semver_dialects_result_to_be_incomparable
        incomparable = Class.new { def <=>(_other); end }.new

        allow(SemverDialects).to receive(:parse_version).and_return(incomparable)
      end

      it 'logs an error and does not suppress (does not raise NoMethodError)' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'DependencyManagement: failed to compare versions for remediation dismissal',
            package_type: 'gem'
          )
        )

        expect(checker.dismissed?(output_with(['rails', '6.1.5']))).to be(false)
      end
    end
  end
end
