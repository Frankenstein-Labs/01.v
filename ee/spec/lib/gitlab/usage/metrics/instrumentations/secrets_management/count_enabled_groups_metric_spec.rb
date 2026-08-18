# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::SecretsManagement::CountEnabledGroupsMetric,
  feature_category: :secrets_management do
  before do
    create(:group_secrets_manager, status: ::SecretsManagement::GroupSecretsManager::STATUSES[:active])
    create(:group_secrets_manager, status: ::SecretsManagement::GroupSecretsManager::STATUSES[:active])
    create(:group_secrets_manager, status: ::SecretsManagement::GroupSecretsManager::STATUSES[:provisioning])
  end

  context 'with all time frame' do
    let(:expected_value) { 2 }
    let(:expected_query) do
      'SELECT COUNT("group_secrets_managers"."id") FROM "group_secrets_managers" ' \
        'WHERE "group_secrets_managers"."status" = 1'
    end

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' }
  end
end
