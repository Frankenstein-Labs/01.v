# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretRotationBatchReminderService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include EmailHelpers
  include NotificationHelpers

  let_it_be_with_reload(:group1) { create(:group) }
  let_it_be_with_reload(:group2) { create(:group) }
  let_it_be(:owner1) { create(:user, owner_of: group1) }
  let_it_be(:owner2) { create(:user, owner_of: group2) }

  let!(:secrets_manager1) { create(:group_secrets_manager, group: group1) }
  let!(:secrets_manager2) { create(:group_secrets_manager, group: group2) }

  let(:service) { described_class.new }

  before do
    provision_group_secrets_manager(secrets_manager1, owner1)
    provision_group_secrets_manager(secrets_manager2, owner2)
    reset_delivered_emails!
  end

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    let!(:secret_1) do
      create_group_secret(
        user: owner1,
        group: group1,
        name: 'GROUP_SECRET_1',
        value: 'value1',
        protected: false,
        environment: '*',
        rotation_interval_days: 30
      )
    end

    let!(:secret_2) do
      create_group_secret(
        user: owner2,
        group: group2,
        name: 'GROUP_SECRET_2',
        value: 'value2',
        protected: false,
        environment: '*',
        rotation_interval_days: 20
      )
    end

    let(:resource1) { group1 }
    let(:resource2) { group2 }
    let(:mail_name) { 'group_secret_rotation_reminder_email' }
    let(:rotation_info_class) { SecretsManagement::GroupSecretRotationInfo }

    it_behaves_like 'a batch reminder service processing secrets', 'group'
  end
end
