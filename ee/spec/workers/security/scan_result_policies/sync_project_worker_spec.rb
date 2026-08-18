# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncProjectWorker, feature_category: :security_policy_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [configuration.project.id] }
  end
end
