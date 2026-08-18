# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do # rubocop:disable RSpec/SpecFilePathFormat -- Per-feature specs for this service live in this directory
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:bot_user) { create(:user, :project_bot) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: bot_user) }

  let(:ref) { 'master' }
  let(:current_user) { bot_user }
  let(:service) { described_class.new(project, current_user, ref: ref) }

  subject(:execute) { service.execute(:push) }

  before_all do
    project.add_developer(bot_user)
  end

  before do
    stub_ci_pipeline_yaml_file(YAML.dump({ rspec: { script: 'rspec' } }))
    create(:protected_branch, project: project, name: ref)
    stub_licensed_features(security_orchestration_policies: true)
    create(:security_policy, :approval_policy, linked_projects: [project],
      bypass_access_token_ids: [personal_access_token.id])
  end

  context 'when the push was allowed via an approval policy bypass' do
    it 'persists the bypass decision on the pipeline metadata' do
      expect(execute).to be_success

      pipeline = execute.payload.reload
      expect(pipeline.pipeline_metadata.security_policy_protected_branch_bypassed).to be(true)
    end

    context 'when the record_security_policy_protected_branch_bypass feature flag is disabled' do
      before do
        stub_feature_flags(record_security_policy_protected_branch_bypass: false)
      end

      it 'creates the pipeline without recording the bypass' do
        expect(execute).to be_success

        expect(execute.payload.reload.pipeline_metadata).to be_nil
      end
    end
  end

  context 'when the actor can push to the protected branch without a bypass' do
    let(:current_user) { project.first_owner }

    it 'does not record a bypass decision that was never needed' do
      expect(execute).to be_success

      expect(execute.payload.reload.pipeline_metadata).to be_nil
    end
  end
end
