# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::UnassignRedundantPolicyConfigurationsWorker, :sidekiq_inline, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:user) { create(:user) }

    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:subgroup_a) { create(:group, parent: top_level_group) }
    let_it_be(:subgroup_b) { create(:group, parent: subgroup_a) }

    let_it_be(:project) { create(:project, group: subgroup_a) }

    let!(:policy_configuration_a) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: top_level_group.id)
    end

    let!(:policy_configuration_b) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: subgroup_b.id,
        security_policy_management_project_id: policy_project_id)
    end

    let!(:policy_configuration_c) do
      create(
        :security_orchestration_policy_configuration,
        project: project,
        security_policy_management_project_id: policy_project_id)
    end

    let!(:other_policy_configuration) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: subgroup_a.id)
    end

    let(:policy_project_id) { policy_configuration_a.security_policy_management_project_id }
    let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

    subject(:execute) { described_class.new.perform(top_level_group.id, policy_project_id, user.id) }

    before_all do
      create(:project_member, user: security_policy_bot, project: project)
    end

    it 'delegates the unassign to Security::Orchestration::UnassignService' do
      [subgroup_b, project].each do |container|
        expect_next_instance_of(::Security::Orchestration::UnassignService,
          container: container,
          current_user: user) do |service|
          expect(service).to receive(:execute).with(delete_bot: false).once.and_call_original
        end
      end

      execute
    end
  end

  describe 'deduplication' do
    let(:group_id) { 1 }
    let(:policy_project_id) { 2 }
    let(:user_id_a) { 3 }
    let(:user_id_b) { 4 }

    let(:job_a) { { 'class' => described_class.name, 'args' => [group_id, policy_project_id, user_id_a] } }
    let(:job_b) { { 'class' => described_class.name, 'args' => [group_id, policy_project_id, user_id_b] } }

    let(:duplicate_job_a) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_a, 'test') }
    let(:duplicate_job_b) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_b, 'test') }

    specify do
      expect(duplicate_job_a.send(:idempotency_key) == duplicate_job_b.send(:idempotency_key)).to be(true)
    end
  end
end
