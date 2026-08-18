# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProvisionGroupSecretsManagerWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:worker) { described_class.new }

  before do
    stub_feature_flags(secrets_manager_paid_experience: false)
  end

  describe '#perform' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    let_it_be_with_reload(:secrets_manager) { create(:group_secrets_manager, group: group) }

    it 'executes a service' do
      expect(SecretsManagement::GroupSecretsManager)
        .to receive(:find_by_id).with(secrets_manager.id).and_return(secrets_manager)

      expect(User).to receive(:find_by_id).with(user.id).and_return(user)

      service = instance_double(SecretsManagement::GroupSecretsManagers::ProvisionService)
      expect(SecretsManagement::GroupSecretsManagers::ProvisionService)
        .to receive(:new).with(secrets_manager, user).and_return(service)

      expect(service).to receive(:execute)

      worker.perform(user.id, secrets_manager.id)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [user.id, secrets_manager.id] }

      it 'enables the secret engine for the group' do
        expect { perform_idempotent_work }.not_to raise_error

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(secrets_manager.full_group_namespace_path,
          secrets_manager.ci_secrets_mount_path)
      end
    end
  end
end
