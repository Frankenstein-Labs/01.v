# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::OrchestrationConfigurationRemoveBotForNamespaceWorker, feature_category: :security_policy_management do
  let(:management_worker) { Security::OrchestrationConfigurationRemoveBotWorker }

  it_behaves_like 'bot management worker examples'

  describe 'delete_configuration' do
    context 'with valid project_id' do
      let_it_be_with_reload(:namespace) { create(:group, :with_security_orchestration_policy_configuration) }
      let(:namespace_id) { namespace.id }

      context 'when current user is provided' do
        let_it_be(:current_user) { create(:user) }
        let(:current_user_id) { current_user.id }

        let(:policy_configuration) { namespace.security_orchestration_policy_configuration }

        it 'enqueues for deletion' do
          expect(Security::DeleteOrchestrationConfigurationWorker).to receive(:perform_async).with(
            policy_configuration.id, current_user_id, policy_configuration.security_policy_management_project.id)

          described_class.new.perform(namespace_id, current_user_id)
        end
      end
    end
  end
end
