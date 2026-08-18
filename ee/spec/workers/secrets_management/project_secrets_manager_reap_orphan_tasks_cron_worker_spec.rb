# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagerReapOrphanTasksCronWorker,
  feature_category: :secrets_management do
  let(:worker) { described_class.new }
  let(:deprovision_service_class) { SecretsManagement::ProjectSecretsManagers::DeprovisionService }

  def build_parent
    create(:project)
  end

  def build_task(parent:, action:, retry_count:, last_processed_at:)
    create(
      :project_secrets_manager_maintenance_task,
      project: parent,
      action: action,
      retry_count: retry_count,
      last_processed_at: last_processed_at
    )
  end

  it_behaves_like 'a secrets manager reap orphan tasks cron worker'
  it_behaves_like 'an idempotent worker'
end
