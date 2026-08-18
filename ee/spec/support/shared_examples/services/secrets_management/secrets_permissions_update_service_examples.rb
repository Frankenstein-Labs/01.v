# frozen_string_literal: true

RSpec.shared_examples 'a service for updating secrets permissions' do |resource_type|
  # Note: The including spec must define:
  # - service (the service instance)
  # - resource (the project or group)
  # - user (a user who is a member of the resource)

  describe '#execute' do
    let(:principal_id) { user.id }
    let(:principal_type) { 'User' }
    let(:actions) { %w[write read] }
    let(:expired_at) { 1.week.from_now.to_date.to_s }

    subject(:result) do
      service.execute(
        principal_id: principal_id,
        principal_type: principal_type,
        actions: actions,
        expired_at: expired_at
      )
    end

    context 'when the secrets manager is active' do
      before do
        provision_secrets_manager(secrets_manager, user)
      end

      context 'when the user is part of the resource' do
        it 'updates a secret permission' do
          expect(result).to be_success

          secrets_permission = result.payload[:secrets_permission]
          expect(secrets_permission).to be_present
          expect(secrets_permission.principal_id).to eq(user.id)
          expect(secrets_permission.principal_type).to eq('User')
          expect(secrets_permission.actions).to eq(actions)
          expect(secrets_permission.expired_at).to eq(expired_at)
        end

        it_behaves_like "an operation requiring an exclusive #{resource_type} secret operation lease"
      end

      context 'with the read-only API policy (store_api_policy)' do
        # Note: the including spec must also define `secrets_manager_namespace_path`.
        let(:api_policy_name) do
          secrets_manager.api_policy_name_for_principal(
            principal_type: principal_type,
            principal_id: principal_id
          )
        end

        context 'when read_value is granted' do
          let(:actions) { %w[read write read_value] }

          it 'stores the read-only API policy' do
            expect(result).to be_success
            expect_policy_to_exist(secrets_manager_namespace_path, api_policy_name)
          end
        end

        context 'when read_value is not granted' do
          let(:actions) { %w[read write] }

          it 'does not store an API policy' do
            expect(result).to be_success
            expect_policy_not_to_exist(secrets_manager_namespace_path, api_policy_name)
          end
        end

        context 'when read_value is revoked by a later update' do
          it 'removes the previously stored API policy' do
            service.execute(
              principal_id: principal_id, principal_type: principal_type,
              actions: %w[read write read_value], expired_at: expired_at
            )
            expect_policy_to_exist(secrets_manager_namespace_path, api_policy_name)

            service.execute(
              principal_id: principal_id, principal_type: principal_type,
              actions: %w[read write], expired_at: expired_at
            )
            expect_policy_not_to_exist(secrets_manager_namespace_path, api_policy_name)
          end
        end
      end

      context 'with expiration in the policy payload' do
        def stub_roles_and_test_requests
          stub_role = stub_request(:post, %r{.*/v1/.*/sys/policies/acl/users/roles/.*})
            .to_return(status: 204, body: '', headers: { 'Content-Type' => 'application/json' })

          stub_direct = stub_request(:post, %r{.*/v1/.*/sys/policies/acl/users/direct/.*})
            .to_return(status: 204, body: '', headers: { 'Content-Type' => 'application/json' })

          expect(result).to be_success
          expect(stub_role).to have_been_requested
          expect(stub_direct).to have_been_requested
        end

        context 'when expired_at is present' do
          let(:expired_at) { 7.days.from_now.to_date.to_s }

          it 'sends expiration in OpenBao policy payload for all updated paths' do
            stub_roles_and_test_requests

            assert_requested(:post, %r{.*/v1/.*/sys/policies/acl/users/direct/.*}) do |req|
              body = Gitlab::Json.parse(req.body)
              policy = Gitlab::Json.parse(body.fetch('policy'))
              paths = policy.fetch('path')

              expected_exp = Time.zone.parse(expired_at).utc.beginning_of_day.iso8601

              expect(paths.values).to all(include('expiration' => expected_exp))
            end
          end
        end

        context 'when expired_at is blank' do
          let(:expired_at) { '' }

          it 'does not include expiration in OpenBao policy payload' do
            stub_roles_and_test_requests

            assert_requested(:post, %r{.*/v1/.*/sys/policies/acl/users/direct/.*}) do |req|
              expect(req.body).not_to include('\"expiration\"')
            end
          end
        end
      end

      context 'when the user is not part of the resource' do
        let(:new_user) { create(:user) }
        let(:principal_id) { new_user.id }
        let(:principal_type) { 'User' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq("Principal user is not a member of the #{resource_type}")
        end
      end

      context 'when the principal-type is invalid' do
        let(:principal_type) { 'TestModel' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Principal type must be one of: User, Role, Group, MemberRole')
        end
      end

      context 'when the principal-ID is invalid' do
        let(:principal_id) { 'delete' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Principal user does not exist')
        end
      end

      context 'when there are api errors' do
        context 'when a check-and-set parameter error occurs' do
          let(:err) { 'check-and-set parameter did not match the current version' }

          before do
            stub_request(:post, %r{.*/v1/.*/sys/policies/acl/.*})
              .to_return(
                status: 400,
                body: { errors: [err] }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )
          end

          it 'returns an error response with the error message' do
            result = service.execute(
              principal_id: principal_id,
              principal_type: principal_type,
              actions: actions,
              expired_at: expired_at
            )

            expect(result).to be_error
            expect(result.message).to include("Failed to save secrets_permission")
            expect(result.payload[:secrets_permission].errors[:base])
              .to include("Failed to save secrets_permission: #{err}")
          end
        end
      end
    end

    context 'when the secrets manager is not active' do
      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq("#{resource_type.capitalize} secrets manager is not active.")
      end
    end
  end
end
