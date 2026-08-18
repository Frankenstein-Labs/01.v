# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::OrchestrationConfigurationCreateBotForNamespaceWorker, feature_category: :security_policy_management do
  let(:management_worker) { Security::OrchestrationConfigurationCreateBotWorker }

  it_behaves_like 'bot management worker examples'
end
