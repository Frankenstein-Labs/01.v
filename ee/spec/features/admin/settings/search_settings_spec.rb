# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates search settings', :js, :elastic_delete_by_query, :with_current_organization,
  :request_store, :enable_admin_mode, feature_category: :global_search do
  include Features::SettingsHelpers
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:default_organization) { create(:organization) }

  let(:elastic_search_license) { true }

  let(:task) do
    create(:elastic_reindexing_task).tap do |task|
      allow(task).to receive_messages(in_progress?: false, error_message: nil, state: "indexing_paused")
    end
  end

  let(:subtask) do
    create(:elastic_reindexing_subtask, documents_count: 0, documents_count_target: 0, reindexing_task: task)
  end

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Organizations::Organization).to receive(:default_organization).and_return(default_organization)
    stub_licensed_features(elastic_search: elastic_search_license)
    allow(::Search::Elastic::ReindexingTask).to receive(:last).and_return(task)
    visit search_admin_application_settings_path
  end

  it 'changes advanced search settings', :aggregate_failures do
    within_testid('elasticsearch-settings') do
      click_unchecked_field s_('AdminSettings|Turn on indexing for advanced search')
      click_unchecked_field s_('AdminSettings|Search with advanced search')

      fill_field_with_new_value 'application_setting_elasticsearch_shards[gitlab-test]', '120'
      fill_field_with_new_value 'application_setting_elasticsearch_replicas[gitlab-test]', '2'
      fill_field_with_new_value 'application_setting_elasticsearch_shards[gitlab-test-notes]', '20'
      fill_field_with_new_value 'application_setting_elasticsearch_replicas[gitlab-test-notes]', '4'
      fill_field_with_new_value 'application_setting_elasticsearch_shards[gitlab-test-merge_requests]', '15'
      fill_field_with_new_value 'application_setting_elasticsearch_replicas[gitlab-test-merge_requests]', '5'
      fill_field_with_new_value 'application_setting_elasticsearch_shards[gitlab-test-commits]', '25'
      fill_field_with_new_value 'application_setting_elasticsearch_replicas[gitlab-test-commits]', '6'

      fill_field_with_new_value _('Maximum file size indexed (KiB)'), '5000'
      fill_field_with_new_value _('Maximum field length'), '100000'
      fill_field_with_new_value _('Maximum bulk request size (MiB)'), '17'
      fill_field_with_new_value _('Bulk request concurrency'), '23'
      fill_field_with_new_value _('Client request timeout'), '30'

      expect_save_settings

      expect_field_checked s_('AdminSettings|Turn on indexing for advanced search')
      expect_field_checked s_('AdminSettings|Search with advanced search')

      expect_field_value 'application_setting_elasticsearch_shards[gitlab-test]', '120'
      expect_field_value 'application_setting_elasticsearch_replicas[gitlab-test]', '2'
      expect_field_value 'application_setting_elasticsearch_shards[gitlab-test-notes]', '20'
      expect_field_value 'application_setting_elasticsearch_replicas[gitlab-test-notes]', '4'
      expect_field_value 'application_setting_elasticsearch_shards[gitlab-test-merge_requests]', '15'
      expect_field_value 'application_setting_elasticsearch_replicas[gitlab-test-merge_requests]', '5'
      expect_field_value 'application_setting_elasticsearch_shards[gitlab-test-commits]', '25'
      expect_field_value 'application_setting_elasticsearch_replicas[gitlab-test-commits]', '6'

      expect_field_value _('Maximum file size indexed (KiB)'), '5000'
      expect_field_value _('Maximum field length'), '100000'
      expect_field_value _('Maximum bulk request size (MiB)'), '17'
      expect_field_value _('Bulk request concurrency'), '23'
      expect_field_value _('Client request timeout'), '30'
    end
  end

  it 'allows limiting projects and namespaces to index', :aggregate_failures do
    project = create(:project)
    namespace = create(:namespace)

    within_testid('elasticsearch-settings') do
      expect(page).not_to have_content('Namespaces to index')
      expect(page).not_to have_content('Projects to index')

      click_unchecked_field s_('AdminSettings|Limit the amount of namespace and project data to index')

      expect(page).to have_content('Namespaces to index')
      expect(page).to have_content('Projects to index')

      click_button 'Select namespaces to index'
      find('.gl-listbox-search-input').set(namespace.path)
      expect_listbox_item namespace.full_path
      select_listbox_item namespace.full_path

      click_button 'Select projects to index'
      find('.gl-listbox-search-input').set(project.path)
      expect_listbox_item project.name_with_namespace
      select_listbox_item project.name_with_namespace

      expect_save_settings
    end

    expect(ElasticsearchIndexedNamespace.exists?(namespace_id: namespace.id)).to be_truthy
    expect(ElasticsearchIndexedProject.exists?(project_id: project.id)).to be_truthy
  end

  it 'allows removing all namespaces and projects', :aggregate_failures do
    stub_ee_application_setting(elasticsearch_limit_indexing: true)

    namespace = create(:elasticsearch_indexed_namespace).namespace
    project = create(:elasticsearch_indexed_project).project

    expect(ElasticsearchIndexedNamespace.count).to be > 0
    expect(ElasticsearchIndexedProject.count).to be > 0

    visit search_admin_application_settings_path

    within_testid('elasticsearch-settings') do
      expect(page).to have_content('Namespaces to index')
      expect(page).to have_content('Projects to index')
      expect(page).to have_content(namespace.full_path)
      expect(page).to have_content(project.full_path)

      find('.js-limit-namespaces button[data-testid="remove-index-entity"]').click
      find('.js-limit-projects button[data-testid="remove-index-entity"]').click

      expect(page).not_to have_content(namespace.full_path)
      expect(page).not_to have_content(project.full_path)

      expect_save_settings
    end

    expect(ElasticsearchIndexedNamespace.count).to eq(0)
    expect(ElasticsearchIndexedProject.count).to eq(0)
  end

  it 'zero-downtime reindexing shows popup' do
    within_testid('elasticsearch-reindexing-settings') do
      expect(page).to have_content 'Trigger cluster reindexing'
      click_button 'Trigger cluster reindexing'
    end

    accept_gl_confirm('Are you sure you want to reindex?')
  end

  context 'when not licensed' do
    let(:elastic_search_license) { false }

    before do
      visit search_admin_application_settings_path
    end

    it 'cannot access the page' do
      expect(page).not_to have_content("Advanced Search with Elasticsearch")
    end
  end
end
