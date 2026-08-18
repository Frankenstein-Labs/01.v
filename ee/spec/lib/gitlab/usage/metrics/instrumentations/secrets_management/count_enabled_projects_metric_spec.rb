# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::SecretsManagement::CountEnabledProjectsMetric,
  feature_category: :secrets_management do
  before do
    create(:project_secrets_manager, status: ::SecretsManagement::ProjectSecretsManager::STATUSES[:active])
    create(:project_secrets_manager, status: ::SecretsManagement::ProjectSecretsManager::STATUSES[:active])
    create(:project_secrets_manager, status: ::SecretsManagement::ProjectSecretsManager::STATUSES[:provisioning])
  end

  context 'with all time frame' do
    let(:expected_value) { 2 }
    let(:expected_query) do
      'SELECT COUNT("project_secrets_managers"."id") FROM "project_secrets_managers" ' \
        'WHERE "project_secrets_managers"."status" = 1'
    end

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' }
  end
end
