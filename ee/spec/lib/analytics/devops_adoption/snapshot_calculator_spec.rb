# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::DevopsAdoption::SnapshotCalculator, feature_category: :devops_reports do
  let_it_be(:group1) { create(:group) }
  let_it_be(:enabled_namespace) { create(:devops_adoption_enabled_namespace, namespace: group1) }
  let_it_be(:subgroup) { create(:group, parent: group1) }
  let_it_be(:project) { create(:project, :repository, group: group1) }
  let_it_be(:subproject) { create(:project, :repository, group: subgroup) }
  let_it_be(:range_end) { Time.zone.parse('2020-12-01').end_of_month }

  let(:service) { described_class.new(enabled_namespace: enabled_namespace, range_end: range_end) }

  subject(:data) { service.calculate }

  describe 'end_time' do
    it 'equals to range_end' do
      expect(data[:end_time]).to be_like_time range_end
    end
  end

  describe 'issue_opened' do
    subject { data[:issue_opened] }

    let_it_be(:old_issue) { create(:issue, project: subproject, created_at: 1.year.ago(range_end)) }

    context 'with an issue opened within month' do
      let_it_be(:fresh_issue) { create(:issue, project: project, created_at: 3.weeks.ago(range_end)) }

      it { is_expected.to be true }
    end

    it { is_expected.to be false }
  end

  describe 'merge_request_opened' do
    subject { data[:merge_request_opened] }

    let_it_be(:old_merge_request) { create(:merge_request, source_project: subproject, created_at: 1.year.ago(range_end)) }

    context 'with a merge request opened within month' do
      let_it_be(:fresh_merge_request) { create(:merge_request, source_project: project, created_at: 3.weeks.ago(range_end)) }

      it { is_expected.to be true }
    end

    it { is_expected.to be false }
  end

  describe 'merge_request_approved' do
    subject { data[:merge_request_approved] }

    let_it_be(:old_merge_request) { create(:merge_request, source_project: subproject, created_at: 1.year.ago(range_end)) }
    let_it_be(:old_approval) { create(:approval, merge_request: old_merge_request, created_at: 6.months.ago(range_end)) }

    context 'with a merge request approved within month' do
      let_it_be(:fresh_approval) { create(:approval, merge_request: old_merge_request, created_at: 3.weeks.ago(range_end)) }

      it { is_expected.to be true }
    end

    it { is_expected.to be false }
  end

  describe 'runner_configured' do
    subject { data[:runner_configured] }

    let_it_be(:paused_runner) { create(:ci_runner, :project, :paused, projects: [project]) }

    context 'with active runner present' do
      let_it_be(:active_runner) { create(:ci_runner, :project, projects: [subproject]) }

      it { is_expected.to be true }
    end

    it { is_expected.to be false }
  end

  describe 'pipeline_succeeded' do
    subject { data[:pipeline_succeeded] }

    let_it_be(:failed_pipeline) { create(:ci_pipeline, :failed, project: project, updated_at: 1.day.ago(range_end)) }
    let_it_be(:old_pipeline) { create(:ci_pipeline, :success, project: project, updated_at: 100.days.ago(range_end)) }

    context 'with successful pipeline within month' do
      let_it_be(:fresh_pipeline) { create(:ci_pipeline, :success, project: project, updated_at: 1.week.ago(range_end)) }

      it { is_expected.to be true }
    end

    it { is_expected.to be false }
  end

  describe 'deploy_succeeded' do
    subject { data[:deploy_succeeded] }

    let!(:deployment) { create(:deployment, :success, updated_at: deployed_at) }
    let(:deployed_at) { 100.days.ago(range_end) }

    let(:enabled_namespace) { create(:devops_adoption_enabled_namespace, namespace: group) }
    let!(:group) do
      create(:group).tap do |g|
        g.projects << deployment.project
      end
    end

    it { is_expected.to be false }

    context 'with successful deployment within month' do
      let(:deployed_at) { 1.day.ago(range_end) }

      it { is_expected.to be true }
    end
  end

  describe 'total_projects_count' do
    subject { data[:total_projects_count] }

    it { is_expected.to eq 2 }
  end

  describe 'code_owners_used_count' do
    subject { data[:code_owners_used_count] }

    it 'returns 1 for code_owners_used_count' do
      allow(subproject).to receive(:default_branch).and_return('with-codeowners')
      allow(service).to receive(:snapshot_projects).and_return([project, subproject])

      is_expected.to eq 1
    end

    context 'when there is no default branch' do
      before do
        allow_any_instance_of(Project).to receive(:default_branch).and_return(nil) # rubocop:disable RSpec/AnyInstanceOf -- it was disabled long time ago
      end

      it 'returns 0 count' do
        expect(subject).to eq 0
      end
    end
  end

  shared_examples 'calculates artifact type count' do |type|
    before do
      create(:ee_ci_job_artifact, type, project: project, created_at: 1.year.before(range_end))
      create(:ee_ci_job_artifact, type, project: project, created_at: 1.day.before(range_end))
      create(:ee_ci_job_artifact, type, project: subproject, created_at: 1.week.before(range_end))
      create(:ee_ci_job_artifact, type, created_at: 1.week.before(range_end))
    end

    it "returns number of projects with at least 1 #{type} CI artifact created in given period" do
      expect(subject).to eq 2
    end
  end

  describe 'sast_enabled_count' do
    subject { data[:sast_enabled_count] }

    include_examples 'calculates artifact type count', :sast
  end

  describe 'dast_enabled_count' do
    subject { data[:dast_enabled_count] }

    include_examples 'calculates artifact type count', :dast
  end

  describe 'dependency_scanning_enabled_count' do
    subject { data[:dependency_scanning_enabled_count] }

    include_examples 'calculates artifact type count', :dependency_scanning
  end

  describe 'coverage_fuzzing_enabled_count' do
    subject { data[:coverage_fuzzing_enabled_count] }

    include_examples 'calculates artifact type count', :coverage_fuzzing
  end

  describe 'vulnerability_management_used_count' do
    subject { data[:vulnerability_management_used_count] }

    it 'returns number of projects with at least 1 vulnerability acted upon' do
      create :vulnerability, :resolved, project: project, created_at: 1.week.before(range_end)
      create :vulnerability, :resolved, project: subproject, created_at: 1.year.before(range_end)
      create :vulnerability, :detected, project: subproject, created_at: 1.week.before(range_end)
      create :vulnerability, :resolved, created_at: 1.week.before(range_end)

      expect(subject).to eq 1
    end
  end

  context 'when snapshot already exists' do
    subject(:data) { described_class.new(enabled_namespace: enabled_namespace, range_end: range_end, snapshot: snapshot).calculate }

    let_it_be(:snapshot) { create :devops_adoption_snapshot, namespace: enabled_namespace.namespace, issue_opened: true, merge_request_opened: false, total_projects_count: 1 }

    context 'for boolean metrics' do
      let_it_be(:fresh_merge_request) { create(:merge_request, source_project: project, created_at: 3.weeks.ago(range_end)) }

      it 'calculates metrics which are not true yet' do
        expect(data[:merge_request_opened]).to be true
      end

      it "doesn't change metrics which are true already" do
        expect(data[:issue_opened]).to be true
      end
    end

    context 'for numeric metrics' do
      it 'always recalculates metric' do
        expect(data[:total_projects_count]).to eq 2
      end
    end
  end
end
