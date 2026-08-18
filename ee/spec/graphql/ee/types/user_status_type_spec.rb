# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::UserStatusType, feature_category: :duo_agent_platform do
  specify { expect(described_class.graphql_name).to eq('UserStatus') }

  include GraphqlHelpers

  describe 'fields' do
    let_it_be(:user) { create(:user) }
    let_it_be(:user_status) { create(:user_status, user: user) }

    let(:object) { user_status }
    let(:current_user) { user }

    before do
      allow(described_class).to receive(:authorized?).and_return(true)
    end

    it 'exposes the expected fields' do
      expected_fields = %i[
        emoji
        message
        message_html
        availability
        clear_status_at
        disabled_for_duo_usage
        disabled_for_duo_usage_reason
      ]

      expect(described_class).to have_graphql_fields(*expected_fields)
    end

    describe '#disabled_for_duo_usage' do
      context 'when user is a regular user' do
        it 'returns false' do
          result = resolve_field(:disabled_for_duo_usage, object, current_user: current_user)
          expect(result).to be false
        end
      end

      context 'when user is a service account without composite identity enforced' do
        let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: false) }
        let_it_be(:service_account_status) { create(:user_status, user: service_account) }

        let(:object) { service_account_status }

        it 'returns false' do
          result = resolve_field(:disabled_for_duo_usage, object, current_user: current_user)
          expect(result).to be false
        end
      end

      context 'when user is a service account with composite identity enforced' do
        let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
        let_it_be(:service_account_status) { create(:user_status, user: service_account) }

        let(:object) { service_account_status }

        context 'when quota check succeeds' do
          before do
            allow_next_instance_of(::Ai::UsageQuotaService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.success)
            end
          end

          it 'returns false' do
            result = resolve_field(:disabled_for_duo_usage, object, current_user: current_user)
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
            result = resolve_field(:disabled_for_duo_usage, object, current_user: current_user)
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
            result = resolve_field(:disabled_for_duo_usage, object, current_user: current_user)
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
            result = resolve_field(:disabled_for_duo_usage, object, current_user: current_user)
            expect(result).to be true
          end
        end
      end
    end

    describe '#disabled_for_duo_usage_reason' do
      context 'when user is a regular user' do
        it 'returns empty string' do
          result = resolve_field(:disabled_for_duo_usage_reason, object, current_user: current_user)
          expect(result).to eq('')
        end
      end

      context 'when user is a service account without composite identity enforced' do
        let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: false) }
        let_it_be(:service_account_status) { create(:user_status, user: service_account) }

        let(:object) { service_account_status }

        it 'returns empty string' do
          result = resolve_field(:disabled_for_duo_usage_reason, object, current_user: current_user)
          expect(result).to eq('')
        end
      end

      context 'when user is a service account with composite identity enforced' do
        let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
        let_it_be(:service_account_status) { create(:user_status, user: service_account) }

        let(:object) { service_account_status }

        context 'when quota check fails with usage_quota_exceeded' do
          before do
            allow_next_instance_of(::Ai::UsageQuotaService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(message: 'Usage quota exceeded', reason: :usage_quota_exceeded)
              )
            end
          end

          it 'returns unavailable no credits message' do
            result = resolve_field(:disabled_for_duo_usage_reason, object, current_user: current_user)
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
            result = resolve_field(:disabled_for_duo_usage_reason, object, current_user: current_user)
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
            result = resolve_field(:disabled_for_duo_usage_reason, object, current_user: current_user)
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
            result = resolve_field(:disabled_for_duo_usage_reason, object, current_user: current_user)
            expect(result).to eq("Unavailable - unknown reason")
          end
        end

        context 'when quota check succeeds' do
          before do
            allow_next_instance_of(::Ai::UsageQuotaService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.success)
            end
          end

          it 'returns empty string' do
            result = resolve_field(:disabled_for_duo_usage_reason, object, current_user: current_user)
            expect(result).to eq('')
          end
        end
      end
    end
  end
end
