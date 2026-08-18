# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretRotationReminderBatchWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  include EmailHelpers
  include NotificationHelpers

  let(:service_class) { SecretsManagement::GroupSecretRotationBatchReminderService }

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:resource) { group }
  let(:mail_name) { 'group_secret_rotation_reminder_email' }
  let(:rotation_infos) { SecretsManagement::GroupSecretRotationInfo.all }

  def provision_secrets_manager(sm, user)
    provision_group_secrets_manager(sm, user)
  end

  def create_pending_secrets
    %w[GROUP_SECRET_1 GROUP_SECRET_2 GROUP_SECRET_3].each do |name|
      create_group_secret(
        user: owner,
        group: group,
        name: name,
        value: 'value',
        protected: false,
        environment: '*',
        rotation_interval_days: 30
      ).tap do |secret|
        secret.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      end
    end
  end

  it_behaves_like 'a secret rotation reminder batch worker'
end
