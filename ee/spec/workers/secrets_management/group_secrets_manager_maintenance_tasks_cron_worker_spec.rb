# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagerMaintenanceTasksCronWorker, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:task_factory) { :group_secrets_manager_maintenance_task }
  let(:provision_worker_class) { SecretsManagement::ProvisionGroupSecretsManagerTaskWorker }
  let(:deprovision_worker_class) { SecretsManagement::DeprovisionGroupSecretsManagerWorker }
  let(:extra_attrs) { { user: user, group: group } }

  it_behaves_like 'a secrets manager maintenance tasks cron worker'
  it_behaves_like 'an idempotent worker'
end
