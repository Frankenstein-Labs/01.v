# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::InactiveProjectsDeletionCronWorker, feature_category: :groups_and_projects do
  include ProjectHelpers

  describe "#perform", :clean_gitlab_redis_shared_state, :sidekiq_inline do
    subject(:worker) { described_class.new }

    let_it_be(:non_admin_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:new_blank_project) do
      create_project_with_statistics.tap do |project|
        project.update!(last_activity_at: Time.current)
      end
    end

    let_it_be(:inactive_blank_project) do
      create_project_with_statistics.tap do |project|
        project.update!(last_activity_at: 13.months.ago)
      end
    end

    let_it_be(:inactive_large_project) do
      create_project_with_statistics(group, with_data: true, size_multiplier: 2.gigabytes)
        .tap { |project| project.update!(last_activity_at: 2.years.ago) }
    end

    let_it_be(:active_large_project) do
      create_project_with_statistics(group, with_data: true, size_multiplier: 2.gigabytes)
        .tap { |project| project.update!(last_activity_at: 1.month.ago) }
    end

    let_it_be(:admin_bot) { ::Users::Internal.in_organization(new_blank_project.organization).admin_bot }

    let_it_be(:delay) { anything }

    before do
      stub_application_setting(inactive_projects_min_size_mb: 5)
      stub_application_setting(inactive_projects_send_warning_email_after_months: 12)
      stub_application_setting(inactive_projects_delete_after_months: 14)
      stub_application_setting(delete_inactive_projects: true)
    end

    it 'logs audit event' do
      audit_context = {
        name: "inactive_project_scheduled_for_deletion",
        message: "Project is scheduled to be deleted on #{deletion_date} due to inactivity.",
        target: inactive_large_project,
        scope: inactive_large_project,
        author: admin_bot
      }
      expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

      expect { worker.perform }
        .to change { AuditEventReader.count }.by(1)

      expect(AuditEventReader.last.details[:custom_message])
        .to eq("Project is scheduled to be deleted on #{deletion_date} due to inactivity.")
    end
  end
end
