# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretRotationBatchReminderService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include EmailHelpers
  include NotificationHelpers

  let_it_be_with_reload(:project1) { create(:project) }
  let_it_be_with_reload(:project2) { create(:project) }
  let_it_be(:owner1) { project1.owner }
  let_it_be(:owner2) { project2.owner }

  let!(:secrets_manager1) { create(:project_secrets_manager, project: project1) }
  let!(:secrets_manager2) { create(:project_secrets_manager, project: project2) }

  let(:service) { described_class.new }

  before do
    provision_project_secrets_manager(secrets_manager1, owner1)
    provision_project_secrets_manager(secrets_manager2, owner2)
    reset_delivered_emails!
  end

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    let!(:secret_1) do
      create_project_secret(
        user: owner1,
        project: project1,
        name: 'SECRET_1',
        value: 'value1',
        branch: '*',
        environment: '*',
        rotation_interval_days: 30
      )
    end

    let!(:secret_2) do
      create_project_secret(
        user: owner2,
        project: project2,
        name: 'SECRET_2',
        value: 'value2',
        branch: '*',
        environment: '*',
        rotation_interval_days: 20
      )
    end

    let(:resource1) { project1 }
    let(:resource2) { project2 }
    let(:mail_name) { 'project_secret_rotation_reminder_email' }
    let(:rotation_info_class) { SecretsManagement::ProjectSecretRotationInfo }

    it_behaves_like 'a batch reminder service processing secrets', 'project'
  end
end
