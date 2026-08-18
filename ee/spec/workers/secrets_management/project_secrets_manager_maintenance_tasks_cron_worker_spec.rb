# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagerMaintenanceTasksCronWorker, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:task_factory) { :project_secrets_manager_maintenance_task }
  let(:provision_worker_class) { SecretsManagement::ProvisionProjectSecretsManagerTaskWorker }
  let(:deprovision_worker_class) { SecretsManagement::DeprovisionProjectSecretsManagerWorker }
  let(:extra_attrs) { { user: user, project: project } }

  it_behaves_like 'a secrets manager maintenance tasks cron worker'
  it_behaves_like 'an idempotent worker'
end
