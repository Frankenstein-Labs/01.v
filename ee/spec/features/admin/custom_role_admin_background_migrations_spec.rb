# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Admin > Admin sees background migrations", feature_category: :database do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:admin_member_role, :read_admin_monitoring, user: user) }

  let_it_be(:active_migration) { create(:batched_background_migration, :active, table_name: 'active') }
  let_it_be(:paused_migration) do
    create(:batched_background_migration, :paused, table_name: 'paused', job_class_name: 'CopyData')
  end

  let_it_be(:failed_migration) do
    create(:batched_background_migration, :failed, table_name: 'failed', total_tuple_count: 100,
      job_class_name: 'MigrateColumns')
  end

  let_it_be(:finished_migration) do
    create(:batched_background_migration, :finished, table_name: 'finished', job_class_name: 'CreateTable')
  end

  let_it_be(:failed_job) do
    create(:batched_background_migration_job, :failed, batched_migration: failed_migration, batch_size: 10,
      min_value: 6, max_value: 15, attempts: 3)
  end

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
    enable_admin_mode!(user)
  end

  it 'can navigate to background migrations and click on a specific migration', :js do
    visit admin_background_migrations_path

    within_testid('super-sidebar') do
      expect(page).to have_css('a[aria-current="page"]', text: 'Background migrations')
    end

    within '#content-body' do
      tab = find_link active_migration.job_class_name
      tab.click

      expect(page).to have_current_path admin_background_migration_path(active_migration)
    end
  end

  it 'can view failed jobs' do
    visit admin_background_migration_path(failed_migration)

    within '#content-body' do
      expect(page).to have_content('Failed jobs')
      expect(page).to have_content('Id')
      expect(page).to have_content('Started at')
      expect(page).to have_content('Finished at')
      expect(page).to have_content('Batch size')
    end
  end

  it 'can view queued migrations but can not pause and resume them' do
    visit admin_background_migrations_path

    within '#content-body' do
      expect(page).to have_selector('tbody tr', count: 2)

      expect(page).to have_content(active_migration.job_class_name)
      expect(page).to have_content(active_migration.table_name)
      expect(page).to have_content('0.00%')
      expect(page).to have_content('Paused')
      expect(page).to have_content('Active')

      expect(page).not_to have_link(href: pause_admin_background_migration_path(active_migration))
      expect(page).not_to have_link(href: resume_admin_background_migration_path(paused_migration))
    end
  end

  it 'can view failed migrations but can not retry them' do
    visit admin_background_migrations_path

    within '#content-body' do
      tab = find_link 'Failed'
      tab.click

      expect(page).to have_selector('tbody tr', count: 1)

      expect(page).to have_content(failed_migration.job_class_name)
      expect(page).to have_content('0.00%')

      expect(page).not_to have_link(href: retry_admin_background_migration_path(failed_migration))
    end
  end
end
