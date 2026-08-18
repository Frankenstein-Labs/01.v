# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Users::ParticipableService, feature_category: :duo_agent_platform do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:service_class) do
    Class.new do
      include EE::Users::ParticipableService

      attr_reader :current_user, :participation_object

      def initialize(current_user, participation_object = nil)
        @current_user = current_user
        @participation_object = participation_object
      end
    end
  end

  let(:service) { service_class.new(current_user, project) }

  describe '#user_disabled_fields' do
    context 'when user is a regular user' do
      let_it_be(:user) { create(:user) }

      it 'returns disabled: false and empty disabled_reason' do
        result = service.user_disabled_fields(user)

        expect(result).to eq({ disabled: false, disabled_reason: '', flow_trigger_events: [] })
      end
    end

    context 'when user is a service account without composite identity enforced' do
      let_it_be(:user) { create(:user, :service_account, composite_identity_enforced: false) }

      it 'returns disabled: false and empty disabled_reason' do
        result = service.user_disabled_fields(user)

        expect(result).to eq({ disabled: false, disabled_reason: '', flow_trigger_events: [] })
      end
    end

    context 'when user is a service account with composite identity enforced' do
      let_it_be(:user) { create(:user, :service_account, composite_identity_enforced: true) }

      context 'when quota check succeeds' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |quota_service|
            allow(quota_service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'returns disabled: false and empty disabled_reason' do
          result = service.user_disabled_fields(user)

          expect(result).to eq({ disabled: false, disabled_reason: '', flow_trigger_events: [] })
        end
      end

      context 'when quota check fails with usage_quota_exceeded' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |quota_service|
            allow(quota_service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Usage quota exceeded', reason: :usage_quota_exceeded)
            )
          end
        end

        it 'returns disabled: true with no credits message and empty flow_trigger_events' do
          result = service.user_disabled_fields(user)

          expect(result).to eq({ disabled: true, disabled_reason: "Unavailable - no credits", flow_trigger_events: [] })
        end
      end

      context 'when quota check fails with user_missing' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |quota_service|
            allow(quota_service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'User is required', reason: :user_missing)
            )
          end
        end

        it 'returns disabled: true with invalid user message and empty flow_trigger_events' do
          result = service.user_disabled_fields(user)

          expect(result).to eq({ disabled: true, disabled_reason: "Unavailable - invalid user",
flow_trigger_events: [] })
        end
      end

      context 'when quota check fails with namespace_missing' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |quota_service|
            allow(quota_service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Namespace is required', reason: :namespace_missing)
            )
          end
        end

        it 'returns disabled: true with missing default namespace message and empty flow_trigger_events' do
          result = service.user_disabled_fields(user)

          expect(result).to eq({ disabled: true, disabled_reason: "Unavailable - missing default namespace",
flow_trigger_events: [] })
        end
      end

      context 'when quota check fails with an unknown reason' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |quota_service|
            allow(quota_service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Something went wrong', reason: :some_unknown_reason)
            )
          end
        end

        it 'returns disabled: true with unknown reason message and empty flow_trigger_events' do
          result = service.user_disabled_fields(user)

          expect(result).to eq({ disabled: true, disabled_reason: "Unavailable - unknown reason",
flow_trigger_events: [] })
        end
      end
    end

    context 'when user has flow triggers on the participation project' do
      let_it_be(:service_account) { create(:service_account) }
      let_it_be(:trigger) do
        create(:ai_flow_trigger, project: project, user: service_account, event_types: [0, 1])
      end

      it 'includes the resolved event type names in flow_trigger_events' do
        result = service.user_disabled_fields(service_account)

        expect(result[:flow_trigger_events]).to contain_exactly(:MENTION, :ASSIGN)
      end
    end
  end
end
