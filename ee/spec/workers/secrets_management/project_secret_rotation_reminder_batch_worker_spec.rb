# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretRotationReminderBatchWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  include EmailHelpers
  include NotificationHelpers

  let(:service_class) { SecretsManagement::ProjectSecretRotationBatchReminderService }

  let_it_be(:project) { create(:project) }
  let_it_be(:owner) { project.owner }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:resource) { project }
  let(:mail_name) { 'project_secret_rotation_reminder_email' }
  let(:rotation_infos) { SecretsManagement::ProjectSecretRotationInfo.all }

  def provision_secrets_manager(sm, user)
    provision_project_secrets_manager(sm, user)
  end

  def create_pending_secrets
    %w[SECRET_1 SECRET_2 SECRET_3].each do |name|
      create_project_secret(
        user: owner,
        project: project,
        name: name,
        value: 'value',
        branch: '*',
        environment: '*',
        rotation_interval_days: 30
      ).tap do |secret|
        secret.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      end
    end
  end

  it_behaves_like 'a secret rotation reminder batch worker'
end
