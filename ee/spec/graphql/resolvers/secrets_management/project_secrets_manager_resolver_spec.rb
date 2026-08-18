# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecretsManagement::ProjectSecretsManagerResolver, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  before do
    stub_licensed_features(native_secrets_management: true)
    allow(::SecretsManagement::Availability).to receive(:enabled_for_project?).with(project).and_return(true)
  end

  subject(:result) do
    resolve(
      described_class,
      args: { project_path: project.full_path },
      ctx: { current_user: user }
    )
  end

  context 'when a secrets manager exists for the project' do
    let_it_be(:secrets_manager) { create(:project_secrets_manager, :active, project: project) }

    it 'returns the secrets manager record' do
      expect(result).to eq(secrets_manager)
    end
  end

  # The post-DELETE trigger on `project_secrets_managers` (added in MR-5)
  # lets the SM row be deleted while a deprovision task is still pending.
  # The resolver returns a phantom (unpersisted) SM in that case so the
  # caller sees DEPROVISIONING status from `effective_status` instead of
  # "no secrets manager".
  context 'when the SM row is gone but a deprovision task is pending' do
    before do
      create(:project_secrets_manager_maintenance_task, :deprovision, project: project)
    end

    it 'returns a phantom SM tied to the project', :aggregate_failures do
      expect(result).to be_present
      expect(result).to be_a(SecretsManagement::ProjectSecretsManager)
      expect(result.persisted?).to be(false)
      expect(result.project).to eq(project)
    end

    it 'phantom SM reports DEPROVISIONING via effective_status' do
      expect(result.effective_status).to eq(SecretsManagement::ProjectSecretsManager::STATUSES[:deprovisioning])
    end
  end

  context 'when there is neither an SM nor a pending deprovision task' do
    it 'returns nil' do
      expect(result).to be_nil
    end
  end

  context 'when only a provision task is pending (not a deprovision task)' do
    before do
      create(:project_secrets_manager_maintenance_task, :provision, project: project)
    end

    it 'returns nil (provision tasks do not trigger the phantom)' do
      expect(result).to be_nil
    end
  end
end
