# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FeatureLibrary::CatalogBuilder, feature_category: :activation do
  let_it_be(:user) { build(:user) }
  let_it_be(:project) { build(:project, :repository, developers: user) }
  let_it_be(:group) { build(:group, developers: user) }

  subject(:catalog) { described_class.new(panel: panel, user: user, resource: resource).execute }

  shared_examples 'a feature catalog' do
    it 'returns entries built from sidebar menu items that opt into the Feature Library' do
      expect(catalog).to be_an(Array)
      expect(catalog).to be_present
      expect(catalog).to all(include(:id, :description))
    end

    it 'only includes items that carry a description' do
      expect(catalog).to all(satisfy { |entry| entry[:description].present? })
    end

    it 'deduplicates by id' do
      ids = catalog.map { |entry| entry[:id] }

      expect(ids).to eq(ids.uniq)
    end
  end

  context 'with a project panel' do
    let(:resource) { project }
    let(:panel) { 'project' }

    it_behaves_like 'a feature catalog'
  end

  context 'with a group panel' do
    let(:resource) { group }
    let(:panel) { 'group' }

    it_behaves_like 'a feature catalog'
  end

  context 'with an unsupported panel' do
    let(:resource) { project }
    let(:panel) { 'admin' }

    it { is_expected.to eq([]) }
  end

  context 'without a container' do
    let(:resource) { nil }
    let(:panel) { 'project' }

    it { is_expected.to eq([]) }
  end

  context 'when building the panel raises' do
    let(:resource) { project }
    let(:panel) { 'project' }

    before do
      allow(Sidebars::Projects::SuperSidebarPanel).to receive(:new).and_raise(StandardError)
    end

    it 'tracks the error and degrades to []', :aggregate_failures do
      expect(Gitlab::ErrorTracking).to receive(:track_exception)
      expect(catalog).to eq([])
    end
  end

  context 'with a project that has an active Jira integration' do
    let_it_be(:jira_user) { create(:user) }
    let_it_be(:jira_project) do
      create(:project, :repository, has_external_issue_tracker: true, developers: jira_user)
    end

    let_it_be(:jira_integration) do
      create(:jira_integration, project: jira_project, project_key: 'GL', issues_enabled: true)
    end

    let(:user) { jira_user }
    let(:resource) { jira_project }
    let(:panel) { 'project' }

    before do
      stub_licensed_features(jira_issues_integration: true)
    end

    it 'does not raise and returns a non-empty catalog', :aggregate_failures do
      expect(Gitlab::ErrorTracking).not_to receive(:track_exception)
      expect(catalog).to be_present
    end

    it 'includes the Jira issue list feature' do
      expect(catalog).to include(
        a_hash_including(id: :jira_issue_list, description: 'Manage Jira issues')
      )
    end

    context 'when the jira_issues_integration licensed feature is unavailable' do
      before do
        stub_licensed_features(jira_issues_integration: false)
      end

      it 'does not raise and excludes the Jira issue list feature', :aggregate_failures do
        expect(Gitlab::ErrorTracking).not_to receive(:track_exception)
        expect(catalog).to be_present
        expect(catalog).not_to include(a_hash_including(id: :jira_issue_list))
      end
    end
  end
end
