# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Govern::Policies, :api, :aggregate_failures,
  feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
    stub_application_setting(policy_store_experiment_enabled: true)
  end

  shared_examples 'a policy store endpoint that maps forbidden to 403' do |service_class|
    context 'when the service reports forbidden' do
      before do
        allow_next_instance_of(service_class) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'You shall not pass', reason: :forbidden)
          )
        end
      end

      it 'returns 403 rather than tracking an unmapped reason' do
        expect(::Gitlab::ErrorTracking).not_to receive(:track_exception)

        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  shared_examples 'a policy store catalogue endpoint' do
    let(:current_user) { user }

    subject(:perform_request) { get api(path, current_user) }

    it 'returns the catalogue' do
      perform_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to eq(expected_catalogue)
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(security_policies_v2: false)
      end

      it 'returns 404, so the flag works as a kill switch on its own' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the experiment is disabled for the instance' do
      before do
        stub_application_setting(policy_store_experiment_enabled: false)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the license is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'returns 403' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      let(:current_user) { nil }

      it 'still returns the catalogue, because it is not user-specific' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq(expected_catalogue)
      end
    end

    context 'when the token is invalid' do
      it 'ignores the credentials rather than returning 401' do
        get api(path), headers: { 'PRIVATE-TOKEN' => 'not-a-real-token' }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'GET /security/policy_store/triggers' do
    it_behaves_like 'a policy store catalogue endpoint' do
      let(:path) { '/security/policy_store/triggers' }
      let(:expected_catalogue) do
        [
          { 'id' => 'deployment_requested', 'name' => 'Deployment' }
        ]
      end
    end
  end

  describe 'GET /security/policy_store/actions' do
    it_behaves_like 'a policy store catalogue endpoint' do
      let(:path) { '/security/policy_store/actions' }
      let(:expected_catalogue) do
        [
          { 'id' => 'block', 'name' => 'Block' },
          { 'id' => 'require_approval', 'name' => 'Require approval' }
        ]
      end
    end
  end

  describe 'GET /security/policy_store/rules' do
    it_behaves_like 'a policy store catalogue endpoint' do
      let(:path) { '/security/policy_store/rules' }
      let(:expected_catalogue) do
        [
          { 'id' => 'custom', 'name' => 'Custom' },
          { 'id' => 'calendar', 'name' => 'Calendar' },
          { 'id' => 'environment', 'name' => 'Environment' }
        ]
      end
    end
  end

  describe 'the organization-scoped routes', :policy_store do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:private_organization) { create(:organization, :private) }
    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:owner) { create(:user) }
    let_it_be(:member) { create(:user) }

    let(:current_user) { owner }
    let(:target_organization_id) { organization.id }

    let!(:policy) do
      create_policy(
        organization_id: organization.id,
        name: 'Block deployments on critical findings',
        trigger_type: 'deployment_requested'
      )
    end

    subject(:perform_request) { get api(path, current_user) }

    before_all do
      create(:organization_user, :owner, organization: organization, user: owner)
      create(:organization_user, organization: organization, user: member, access_level: :default)
    end

    shared_examples 'an organization-scoped policy store endpoint' do
      context 'when the user is an organization member without the owner role' do
        let(:current_user) { member }

        it 'returns 403' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the user does not belong to the organization' do
        let(:current_user) { user }

        it 'returns 403, since the organization itself is public and readable' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the organization is private and the user does not belong to it' do
        let(:current_user) { user }
        let(:target_organization_id) { private_organization.id }

        it 'returns 404 naming the organization, the same as one that does not exist' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Organization Not Found')
        end
      end

      context 'when the organization does not exist' do
        let(:target_organization_id) { non_existing_record_id }

        it 'returns 404 naming the organization' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Organization Not Found')
        end
      end

      context 'when unauthenticated' do
        let(:current_user) { nil }

        it 'returns 401, unlike the catalogue routes' do
          perform_request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(security_policies_v2: false)
        end

        it 'returns 404 without naming a resource, so the gate reveals nothing about the route' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Not Found')
        end
      end

      context 'when the experiment is disabled for the instance' do
        before do
          stub_application_setting(policy_store_experiment_enabled: false)
        end

        it 'returns 404 without naming a resource, since it is a separate gate from the flag' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Not Found')
        end
      end

      context 'when the license is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'returns 403' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    describe 'GET /organizations/:id/security/policy_store' do
      let(:path) { "/organizations/#{target_organization_id}/security/policy_store" }

      it 'returns the policies of the organization' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to contain_exactly(
          a_hash_including(
            'id' => policy.id,
            'organization_id' => organization.id,
            'name' => 'Block deployments on critical findings',
            'trigger_type' => 'deployment_requested',
            'version' => 1,
            'mode' => 'enforce',
            'lifecycle_state' => 'active'
          )
        )
      end

      it 'matches the policies schema' do
        perform_request

        expect(response).to match_response_schema('public_api/v4/govern_policies', dir: 'ee')
      end

      context 'with a trigger_type' do
        let!(:merge_request_policy) do
          create_policy(
            organization_id: organization.id,
            name: 'Merge request policy',
            trigger_type: 'merge_request'
          )
        end

        let(:path) do
          "/organizations/#{target_organization_id}/security/policy_store?trigger_type=deployment_requested"
        end

        it 'returns only the policies for that trigger' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to contain_exactly(policy.id)
        end

        context 'when the trigger is not in the catalogue' do
          let(:path) do
            "/organizations/#{target_organization_id}/security/policy_store?trigger_type=merge_request"
          end

          it 'returns 400, rather than an empty collection, since the route constrains the value' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'when another organization owns a policy' do
        let!(:other_organization_policy) do
          create_policy(
            organization_id: other_organization.id,
            name: 'Other organization policy',
            trigger_type: 'deployment_requested'
          )
        end

        it 'omits it, so a policy id alone does not cross organizations' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to contain_exactly(policy.id)
        end
      end

      context 'when the organization has no policies' do
        let_it_be(:empty_organization) { create(:organization) }

        let(:target_organization_id) { empty_organization.id }

        before_all do
          create(:organization_user, :owner, organization: empty_organization, user: owner)
        end

        it 'returns an empty collection' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq([])
        end
      end

      context 'when the service reports the experiment inactive' do
        before do
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::PolicyStore::ListService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'nope', reason: :experiment_not_active)
            )
          end
        end

        it 'returns 404 rather than presenting an empty payload' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the service reports invalid input' do
        before do
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::PolicyStore::ListService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Missing required attributes: name', reason: :invalid)
            )
          end
        end

        it 'returns 400 and forwards the message, since it is written for the caller' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Missing required attributes: name')
        end

        it 'does not track it, so a mapped reason cannot page anyone' do
          expect(::Gitlab::ErrorTracking).not_to receive(:track_exception)

          perform_request
        end
      end

      it_behaves_like 'a policy store endpoint that maps forbidden to 403',
        ::Security::SecurityOrchestrationPolicies::PolicyStore::ListService

      context 'when the service fails for a reason the endpoint does not map' do
        before do
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::PolicyStore::ListService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'PG::ConnectionBad: could not connect to host', reason: :unexpected)
            )
          end
        end

        it 'returns 500 and a generic message, since the reason is a bug on our side' do
          perform_request

          expect(response).to have_gitlab_http_status(:internal_server_error)
          expect(json_response['message']).to eq('Could not complete the policy store request')
          expect(json_response['message']).not_to include('PG::ConnectionBad')
        end

        it 'tracks the reason as the title, so the tracked issue names the fix' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
            having_attributes(
              class: ::API::Govern::Policies::UnmappedReasonError,
              message: 'Unmapped policy store reason: unexpected'
            ),
            service_message: 'PG::ConnectionBad: could not connect to host'
          )

          perform_request
        end
      end

      it_behaves_like 'an organization-scoped policy store endpoint'

      it_behaves_like 'authorizing granular token permissions', :read_govern_policy do
        let(:user) { owner }
        let(:boundary_object) { :instance }
        let(:request) { get api(path, personal_access_token: pat) }
      end
    end

    describe 'GET /organizations/:id/security/policy_store/:policy_id' do
      let(:target_policy_id) { policy.id }
      let(:path) { "/organizations/#{target_organization_id}/security/policy_store/#{target_policy_id}" }

      it 'returns the policy' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => policy.id,
          'organization_id' => organization.id,
          'name' => 'Block deployments on critical findings',
          'trigger_type' => 'deployment_requested',
          'version' => 1,
          'mode' => 'enforce',
          'lifecycle_state' => 'active'
        )
      end

      it 'matches the policy schema' do
        perform_request

        expect(response).to match_response_schema('public_api/v4/govern_policy', dir: 'ee')
      end

      context 'when the policy does not exist' do
        let(:target_policy_id) { non_existing_record_id }

        it 'returns 404 naming the policy, not the organization it looked in' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Policy Not Found')
        end
      end

      context 'when the policy belongs to another organization' do
        let(:target_policy_id) do
          create_policy(
            organization_id: other_organization.id,
            name: 'Other organization policy',
            trigger_type: 'deployment_requested'
          ).id
        end

        it 'returns the same 404 as a missing policy, so an id cannot be probed across organizations' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Policy Not Found')
        end
      end

      it_behaves_like 'an organization-scoped policy store endpoint'

      it_behaves_like 'authorizing granular token permissions', :read_govern_policy do
        let(:user) { owner }
        let(:boundary_object) { :instance }
        let(:request) { get api(path, personal_access_token: pat) }
      end
    end

    describe 'POST /organizations/:id/security/policy_store' do
      let(:path) { "/organizations/#{target_organization_id}/security/policy_store" }

      let(:policy_params) do
        {
          name: 'Require approval on critical findings',
          trigger_type: 'deployment_requested',
          rules: [{ type: 'custom', value: 'package governance' }]
        }
      end

      subject(:perform_request) { post api(path, current_user), params: policy_params }

      it 'creates the policy and returns it' do
        expect { perform_request }
          .to change { Gitlab::PolicyStore.list(organization_id: organization.id).size }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include(
          'organization_id' => organization.id,
          'name' => 'Require approval on critical findings',
          'trigger_type' => 'deployment_requested',
          'version' => 1,
          'mode' => 'enforce',
          'lifecycle_state' => 'active'
        )
        # Declaring the entry shape means declared_params rebuilds each rule, so assert the
        # stored rule still carries both keys rather than only its count.
        expect(json_response['rules']).to eq([{ 'type' => 'custom', 'value' => 'package governance' }])
      end

      it 'matches the policy schema' do
        perform_request

        expect(response).to match_response_schema('public_api/v4/govern_policy', dir: 'ee')
      end

      it_behaves_like 'a policy store endpoint that maps forbidden to 403',
        ::Security::SecurityOrchestrationPolicies::PolicyStore::CreateService

      context 'when the optional attributes are given rather than defaulted' do
        let(:policy_params) do
          super().merge(description: 'Only on critical findings', mode: 'audit', lifecycle_state: 'disabled')
        end

        it 'stores them instead of falling back to the defaults' do
          perform_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to include(
            'description' => 'Only on critical findings',
            'mode' => 'audit',
            'lifecycle_state' => 'disabled'
          )
        end
      end

      context 'when an enumerated attribute is outside the values it allows' do
        { mode: 'not_a_mode', lifecycle_state: 'not_a_state' }.each do |attribute, invalid_value|
          it "returns 400 for #{attribute}" do
            post api(path, current_user), params: policy_params.merge(attribute => invalid_value)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq("#{attribute} does not have a valid value")
          end
        end
      end

      context 'when a free-form string is longer than the store accepts' do
        ::Gitlab::PolicyStore::Ports::PolicyRepository::TEXT_LIMITS.each do |attribute, limit|
          it "returns 400 for #{attribute}, so the payload is refused before the store parses it" do
            expect { post api(path, current_user), params: policy_params.merge(attribute => 'a' * (limit + 1)) }
              .not_to change { Gitlab::PolicyStore.list(organization_id: organization.id).size }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to include(attribute.to_s, "must be less than #{limit} characters")
          end

          it "accepts #{attribute} at exactly #{limit} characters" do
            post api(path, current_user), params: policy_params.merge(attribute => 'a' * limit)

            expect(response).to have_gitlab_http_status(:created)
          end
        end
      end

      context 'with a policy scope' do
        let(:policy_params) do
          super().merge(policy_scope: { compliance_frameworks: [{ id: 5 }] })
        end

        it 'compiles the scope into the returned program' do
          post api(path, current_user), params: policy_params.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['scope_rego']).to include('framework_id in {5}')
        end
      end

      context 'when the trigger is not one the catalogue offers' do
        let(:policy_params) { super().merge(trigger_type: 'not_a_trigger') }

        it 'returns 400' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('trigger_type does not have a valid value')
        end
      end

      context 'when a required attribute is missing' do
        let(:policy_params) { super().except(:name) }

        it 'returns 400 naming the attribute' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('name')
        end
      end

      # Both cases need a JSON body. Form encoding drops an empty array entirely and has no
      # way to send null, so neither value can reach the endpoint that way.
      context 'when rules is empty in a JSON body' do
        it 'returns 400, since a policy with no rules can never match' do
          post api(path, current_user), params: policy_params.merge(rules: []).to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('rules')
        end
      end

      context 'when rules is null in a JSON body' do
        it 'returns 400 rather than raising, since a declared Array still arrives nil' do
          post api(path, current_user), params: policy_params.merge(rules: nil).to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('rules')
        end
      end

      context 'when rules is a scalar in a JSON body' do
        [1.5, true, 'not-an-array'].each do |scalar|
          it "returns 400 rather than raising for #{scalar.inspect}" do
            post api(path, current_user), params: policy_params.merge(rules: scalar).to_json,
              headers: { 'Content-Type' => 'application/json' }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('rules is invalid')
          end
        end
      end

      context 'when a rule carries a Hash value rather than Rego source' do
        let(:policy_params) do
          super().merge(rules: [{ type: 'environment', value: { names: %w[production] } }])
        end

        it 'stores the hash, since only a custom rule carries a string' do
          post api(path, current_user), params: policy_params.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['rules']).to eq([{ 'type' => 'environment',
                                                  'value' => { 'names' => ['production'] } }])
        end
      end

      context 'when an action carries a configuration hash' do
        let(:policy_params) do
          super().merge(actions: [{ type: 'require_approval', value: { approvals_required: 2 } }])
        end

        it 'stores the hash, since an action value is only ever a hash' do
          post api(path, current_user), params: policy_params.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['actions']).to eq([{ 'type' => 'require_approval',
                                                    'value' => { 'approvals_required' => 2 } }])
        end
      end

      context 'when an action value is a string rather than a hash' do
        let(:policy_params) { super().merge(actions: [{ type: 'block', value: 'not-a-hash' }]) }

        it 'returns 400' do
          post api(path, current_user), params: policy_params.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('value')
        end
      end

      context 'when actions is null or empty in a JSON body' do
        [nil, []].each do |value|
          it "creates the policy with no actions for #{value.inspect}" do
            post api(path, current_user), params: policy_params.merge(actions: value).to_json,
              headers: { 'Content-Type' => 'application/json' }

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['actions']).to eq([])
          end
        end
      end

      context 'when a rule type is not one the catalogue offers' do
        let(:policy_params) { super().merge(rules: [{ type: 'not_a_rule', value: 'package governance' }]) }

        it 'returns 400 without reaching the store' do
          expect(Gitlab::PolicyStore).not_to receive(:create)

          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('does not have a valid value')
        end
      end

      context 'when an action type is not one the catalogue offers' do
        let(:policy_params) { super().merge(actions: [{ type: 'not_an_action' }]) }

        it 'returns 400 without reaching the store' do
          expect(Gitlab::PolicyStore).not_to receive(:create)

          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('does not have a valid value')
        end
      end

      context 'when both a policy scope and Rego are given' do
        let(:policy_params) do
          super().merge(
            policy_scope: { compliance_frameworks: [{ id: 5 }] },
            scope_rego: "package gitlab.scope\n\napplies := true\n"
          )
        end

        it 'returns 400 with the service message, so the two cannot disagree' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Only one of policy_scope or scope_rego can be provided')
        end
      end

      context 'when a policy scope compiles past the store size limit' do
        let(:limit) { Gitlab::PolicyStore::Ports::PolicyRepository::TEXT_LIMITS[:scope_rego] }

        let(:policy_params) do
          projects = Array.new(limit) { |index| { id: index + 1 } }

          super().merge(policy_scope: { projects: { including: projects } })
        end

        # A JSON body rather than the form encoding the sibling examples use, because this
        # many ids exceeds what Rack will parse from a query string.
        it 'returns 400, since the limit is checked after the scope is compiled' do
          expect do
            post api(path, current_user), params: policy_params.to_json,
              headers: { 'Content-Type' => 'application/json' }
          end.not_to change { Gitlab::PolicyStore.list(organization_id: organization.id).size }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include("scope_rego exceeds maximum length of #{limit}")
        end
      end

      it_behaves_like 'an organization-scoped policy store endpoint'

      it_behaves_like 'authorizing granular token permissions', :create_govern_policy,
        expected_success_status: :created do
        let(:user) { owner }
        let(:boundary_object) { :instance }
        let(:request) { post api(path, personal_access_token: pat), params: policy_params }
      end
    end

    describe 'PATCH /organizations/:id/security/policy_store/:policy_id' do
      let(:target_policy) { policy }
      let(:path) { "/organizations/#{target_organization_id}/security/policy_store/#{target_policy.id}" }
      let(:policy_params) { { name: 'Renamed policy' } }

      subject(:perform_request) { patch api(path, current_user), params: policy_params }

      it 'applies the change and returns the policy' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => policy.id,
          'name' => 'Renamed policy',
          'version' => 2
        )
      end

      it 'persists the change' do
        perform_request

        get api(path, current_user)

        expect(json_response['name']).to eq('Renamed policy')
      end

      it 'accepts a JSON body as well as a form-encoded one' do
        patch api(path, current_user), params: { name: 'JSON rename' }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['name']).to eq('JSON rename')
      end

      it_behaves_like 'a policy store endpoint that maps forbidden to 403',
        ::Security::SecurityOrchestrationPolicies::PolicyStore::UpdateService

      context 'when the mode and lifecycle state change' do
        let(:policy_params) { { mode: 'audit', lifecycle_state: 'disabled' } }

        it 'takes the policy off the store defaults' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('mode' => 'audit', 'lifecycle_state' => 'disabled')
        end
      end

      context 'when the actions change' do
        let!(:target_policy) do
          create_policy(
            organization_id: organization.id,
            name: 'Blocking policy',
            trigger_type: 'deployment_requested',
            actions: [{ 'type' => 'block' }]
          )
        end

        it 'replaces them rather than merging into the stored ones' do
          patch api(path, current_user),
            params: { actions: [{ type: 'require_approval', value: { approvals_required: 2 } }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['actions'])
            .to eq([{ 'type' => 'require_approval', 'value' => { 'approvals_required' => 2 } }])
        end
      end

      context 'when no changeable attribute is given' do
        let(:policy_params) { {} }

        it 'returns 400 rather than bumping the version for nothing' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when a blank scope_rego retires an authored program' do
        let!(:target_policy) do
          create_policy(
            organization_id: organization.id,
            name: 'Authored scope',
            trigger_type: 'deployment_requested',
            scope_rego: "package gitlab.scope\n\n# hand written"
          )
        end

        it 'recompiles when the blank arrives form-encoded as an empty string' do
          patch api(path, current_user), params: { scope_rego: '' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['scope_rego']).not_to include('# hand written')
          expect(json_response['scope_rego']).to include('applies to all projects')
        end

        it 'recompiles when the blank arrives as JSON null' do
          patch api(path, current_user), params: { scope_rego: nil }.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['scope_rego']).not_to include('# hand written')
          expect(json_response['scope_rego']).to include('applies to all projects')
        end
      end

      context 'when the rules are emptied' do
        let!(:target_policy) do
          create_policy(
            organization_id: organization.id,
            name: 'Ruled policy',
            trigger_type: 'deployment_requested',
            rules: [{ 'type' => 'custom', 'value' => 'package governance' }]
          )
        end

        it 'stores the empty array, which is what a policy created without rules holds' do
          patch api(path, current_user), params: { rules: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['rules']).to eq([])
        end
      end

      context 'when an empty policy scope un-scopes the policy' do
        let!(:target_policy) do
          create_policy(
            organization_id: organization.id,
            name: 'Scoped policy',
            trigger_type: 'deployment_requested',
            policy_scope: { 'compliance_frameworks' => [{ 'id' => 5 }] }
          )
        end

        it 'clears the scope, which only a JSON body can express' do
          patch api(path, current_user), params: { policy_scope: {} }.to_json,
            headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['scope_rego']).to include('applies to all projects')
          expect(json_response['scope_rego']).not_to include('framework_id')
        end
      end

      context 'when the policy does not exist' do
        let(:path) do
          "/organizations/#{target_organization_id}/security/policy_store/#{non_existing_record_id}"
        end

        it 'returns 404 naming the policy' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Policy Not Found')
        end
      end

      context 'when the policy belongs to another organization' do
        let!(:target_policy) do
          create_policy(
            organization_id: other_organization.id,
            name: 'Other organization policy',
            trigger_type: 'deployment_requested'
          )
        end

        it 'returns the same 404 as a missing policy and leaves it unchanged' do
          expect { perform_request }
            .not_to change { Gitlab::PolicyStore.find(target_policy.id).name }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Policy Not Found')
        end
      end

      {
        { trigger_type: 'not_a_trigger' } => 'trigger_type',
        { mode: 'not_a_mode' } => 'mode',
        { lifecycle_state: 'not_a_lifecycle_state' } => 'lifecycle_state',
        { rules: [{ type: 'not_a_rule' }] } => 'rules[0][type]',
        { actions: [{ type: 'not_an_action' }] } => 'actions[0][type]'
      }.each do |invalid_params, rejected_parameter|
        context "when #{rejected_parameter} is not one the catalogue offers" do
          it 'returns 400, since the route is the only thing that constrains it' do
            patch api(path, current_user), params: invalid_params.to_json,
              headers: { 'Content-Type' => 'application/json' }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq("#{rejected_parameter} does not have a valid value")
          end
        end
      end

      context 'when a free-form string is longer than the store accepts' do
        ::Gitlab::PolicyStore::Ports::PolicyRepository::TEXT_LIMITS.each do |attribute, limit|
          it "returns 400 for #{attribute}, so the payload is refused before the store parses it" do
            patch api(path, current_user), params: { attribute => 'a' * (limit + 1) }.to_json,
              headers: { 'Content-Type' => 'application/json' }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to include(attribute.to_s, "must be less than #{limit} characters")
          end

          it "accepts #{attribute} at exactly #{limit} characters" do
            patch api(path, current_user), params: { attribute => 'a' * limit }.to_json,
              headers: { 'Content-Type' => 'application/json' }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end

      context 'when both a policy scope and Rego are given' do
        let(:policy_params) do
          {
            policy_scope: { compliance_frameworks: [{ id: 5 }] },
            scope_rego: "package gitlab.scope\n\napplies := true\n"
          }
        end

        it 'returns 400 with the service message' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Only one of policy_scope or scope_rego can be provided')
        end
      end

      context 'when the new name is taken by another policy in the organization' do
        before do
          create_policy(
            organization_id: organization.id,
            name: 'Renamed policy',
            trigger_type: 'deployment_requested'
          )
        end

        it 'returns 400 with the store message' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Name has already been taken')
        end
      end

      it_behaves_like 'an organization-scoped policy store endpoint'

      it_behaves_like 'authorizing granular token permissions', :update_govern_policy do
        let(:user) { owner }
        let(:boundary_object) { :instance }
        let(:request) { patch api(path, personal_access_token: pat), params: policy_params }
      end
    end

    describe 'DELETE /organizations/:id/security/policy_store/:policy_id' do
      let(:target_policy_id) { policy.id }
      let(:path) { "/organizations/#{target_organization_id}/security/policy_store/#{target_policy_id}" }

      subject(:perform_request) { delete api(path, current_user) }

      it 'deletes the policy and returns no content' do
        expect { perform_request }
          .to change { Gitlab::PolicyStore.list(organization_id: organization.id).size }.by(-1)

        expect(response).to have_gitlab_http_status(:no_content)
        expect(response.body).to be_empty
      end

      context 'when the policy does not exist' do
        let(:target_policy_id) { non_existing_record_id }

        it 'returns 404 naming the policy' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Policy Not Found')
        end
      end

      # let! rather than let: the policy has to exist before the change matcher takes its
      # baseline, otherwise creating it inside the block reads as the delete having failed.
      context 'when the policy belongs to another organization' do
        let!(:target_policy_id) do
          create_policy(
            organization_id: other_organization.id,
            name: 'Other organization policy',
            trigger_type: 'deployment_requested'
          ).id
        end

        it 'returns the same 404 as a missing policy and leaves it in the store' do
          expect { perform_request }
            .not_to change { Gitlab::PolicyStore.list(organization_id: other_organization.id).size }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Policy Not Found')
        end
      end

      it_behaves_like 'an organization-scoped policy store endpoint'

      it_behaves_like 'authorizing granular token permissions', :delete_govern_policy,
        expected_success_status: :no_content do
        let(:user) { owner }
        let(:boundary_object) { :instance }
        let(:request) { delete api(path, personal_access_token: pat) }
      end
    end
  end
end
