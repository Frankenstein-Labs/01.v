# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['UserDuoStatus'], feature_category: :workflow_catalog do
  include GraphqlHelpers

  it { expect(described_class.graphql_name).to eq('UserDuoStatus') }

  it 'has specific fields' do
    expect(described_class).to have_graphql_fields(
      :disabled,
      :disabled_reason,
      :flow_trigger_events
    )
  end

  describe '#disabled' do
    let_it_be(:current_user) { create(:user) }

    context 'when object is a regular user' do
      let_it_be(:regular_user) { create(:user) }

      it 'returns false' do
        result = resolve_field(:disabled, regular_user, current_user: current_user)
        expect(result).to be false
      end
    end

    context 'when object is a service account without composite identity enforced' do
      let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: false) }

      it 'returns false' do
        result = resolve_field(:disabled, service_account, current_user: current_user)
        expect(result).to be false
      end
    end

    context 'when object is a service account with composite identity enforced' do
      let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

      context 'when quota check succeeds' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'returns false' do
          result = resolve_field(:disabled, service_account, current_user: current_user)
          expect(result).to be false
        end
      end

      context 'when quota check fails with usage_quota_exceeded' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Usage quota exceeded', reason: :usage_quota_exceeded)
            )
          end
        end

        it 'returns true' do
          result = resolve_field(:disabled, service_account, current_user: current_user)
          expect(result).to be true
        end
      end

      context 'when quota check fails with user_missing' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'User is required', reason: :user_missing)
            )
          end
        end

        it 'returns true' do
          result = resolve_field(:disabled, service_account, current_user: current_user)
          expect(result).to be true
        end
      end

      context 'when quota check fails with namespace_missing' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Namespace is required', reason: :namespace_missing)
            )
          end
        end

        it 'returns true' do
          result = resolve_field(:disabled, service_account, current_user: current_user)
          expect(result).to be true
        end
      end
    end
  end

  describe '#disabled_reason' do
    let_it_be(:current_user) { create(:user) }

    context 'when object is a regular user' do
      let_it_be(:regular_user) { create(:user) }

      it 'returns empty string' do
        result = resolve_field(:disabled_reason, regular_user, current_user: current_user)
        expect(result).to eq('')
      end
    end

    context 'when object is a service account without composite identity enforced' do
      let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: false) }

      it 'returns empty string' do
        result = resolve_field(:disabled_reason, service_account, current_user: current_user)
        expect(result).to eq('')
      end
    end

    context 'when object is a service account with composite identity enforced' do
      let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

      context 'when quota check succeeds' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'returns empty string' do
          result = resolve_field(:disabled_reason, service_account, current_user: current_user)
          expect(result).to eq('')
        end
      end

      context 'when quota check fails with usage_quota_exceeded' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Usage quota exceeded', reason: :usage_quota_exceeded)
            )
          end
        end

        it 'returns unavailable no credits message' do
          result = resolve_field(:disabled_reason, service_account, current_user: current_user)
          expect(result).to eq("Unavailable - no credits")
        end
      end

      context 'when quota check fails with user_missing' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'User is required', reason: :user_missing)
            )
          end
        end

        it 'returns unavailable invalid user message' do
          result = resolve_field(:disabled_reason, service_account, current_user: current_user)
          expect(result).to eq("Unavailable - invalid user")
        end
      end

      context 'when quota check fails with namespace_missing' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Namespace is required', reason: :namespace_missing)
            )
          end
        end

        it 'returns unavailable missing default namespace message' do
          result = resolve_field(:disabled_reason, service_account, current_user: current_user)
          expect(result).to eq("Unavailable - missing default namespace")
        end
      end

      context 'when quota check fails with an unknown reason' do
        before do
          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Something went wrong', reason: :some_unknown_reason)
            )
          end
        end

        it 'returns unavailable unknown reason message' do
          result = resolve_field(:disabled_reason, service_account, current_user: current_user)
          expect(result).to eq("Unavailable - unknown reason")
        end
      end
    end
  end
end
