# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SecretsController, feature_category: :secrets_management do
  let_it_be(:developer) { create(:user) }
  let_it_be(:reporter) { create(:user, :with_namespace) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:planner) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:secrets_manager) { build(:group_secrets_manager, group: group) }

  shared_examples 'group secrets manager page' do
    it 'renders the group secrets index template' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('groups/secrets/index')
    end
  end

  shared_examples 'page not found' do
    it 'returns a "not found" response' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  # Stub the effective-capabilities service to return the given read value.
  # Used to isolate controller tests from live OpenBao calls.
  def stub_read_capability(read:)
    allow_next_instance_of(
      SecretsManagement::UserPermissions::GroupEffectiveCapabilitiesService
    ) do |svc|
      allow(svc).to receive(:execute).and_return(
        { 'read_metadata' => read, 'create' => false, 'update' => false, 'delete' => false }
      )
    end
  end

  describe 'GET /:namespace/:group/-/secrets' do
    subject(:request) { get group_secrets_url(group), params: { group_id: group.to_param } }

    before_all do
      secrets_manager.activate!
      group.add_developer(developer)
      group.add_reporter(reporter)
      group.add_guest(guest)
      group.add_planner(planner)
    end

    before do
      # SM availability requires (FF AND enrollment); the entitlement-aware
      # policy also requires an entitled namespace. Enroll + entitle by default
      # so positive-path tests are reachable. Negative-path tests override the
      # FF, license, or enrollment as needed.
      stub_feature_flags(group_secrets_manager: group)
      enroll_instance_in_secrets_manager
    end

    context 'when all conditions are met' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_read_capability(read: true)
        sign_in(reporter)
      end

      it_behaves_like 'group secrets manager page'

      it 'pushes :secrets_manager_paid_experience scoped to the root ancestor group' do
        subgroup = create(:group, parent: group)
        create(:group_secrets_manager, group: subgroup).activate!

        stub_feature_flags(group_secrets_manager: [group, subgroup], secrets_manager_paid_experience: group)
        subgroup.add_reporter(reporter)

        get group_secrets_url(subgroup), params: { group_id: subgroup.to_param }

        expect(response.body).to have_pushed_frontend_feature_flags(secretsManagerPaidExperience: true)
      end
    end

    context 'when user has a role higher than reporter' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_read_capability(read: true)
        sign_in(developer)
      end

      it_behaves_like 'group secrets manager page'
    end

    it_behaves_like 'dismisses the secrets manager nav badge on view' do
      let(:secrets_container) { group }

      # check_read_capability! now gates the page, so grant read to render it.
      before do
        stub_read_capability(read: true)
      end
    end

    context 'when user does not have read_secret permission' do
      before do
        stub_licensed_features(native_secrets_management: true)
      end

      context 'with guest role' do
        before do
          sign_in(guest)
        end

        it_behaves_like 'page not found'
      end

      context 'with planner role' do
        before do
          sign_in(planner)
        end

        it_behaves_like 'page not found'
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(group_secrets_manager: false)
        sign_in(reporter)
      end

      it_behaves_like 'page not found'
    end

    context 'when not enrolled' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: false)
        stub_licensed_features(native_secrets_management: true)
        stub_application_setting(secrets_manager_instance_enrolled: false)
        sign_in(reporter)
      end

      it_behaves_like 'page not found'
    end

    context 'when feature license is disabled' do
      before do
        stub_licensed_features(native_secrets_management: false)
        sign_in(reporter)
      end

      it_behaves_like 'page not found'
    end

    context 'when the paid experience is disabled' do
      # Exercises the legacy "provisioned and active" gate (the flag defaults to enabled in tests).
      context 'when secrets manager is not provisioned' do
        let_it_be(:group_without_sm) { create(:group) }

        subject(:request) { get group_secrets_url(group_without_sm), params: { group_id: group_without_sm.to_param } }

        before_all do
          group_without_sm.add_reporter(reporter)
        end

        before do
          stub_feature_flags(group_secrets_manager: group_without_sm, secrets_manager_paid_experience: false)
          stub_licensed_features(native_secrets_management: true)
          sign_in(reporter)
        end

        it_behaves_like 'page not found'
      end

      context 'when secrets manager is not active' do
        let_it_be(:group_provisioning) { create(:group) }
        let_it_be(:provisioning_sm) { create(:group_secrets_manager, group: group_provisioning) }

        subject(:request) do
          get group_secrets_url(group_provisioning), params: { group_id: group_provisioning.to_param }
        end

        before_all do
          group_provisioning.add_reporter(reporter)
        end

        before do
          stub_feature_flags(group_secrets_manager: group_provisioning, secrets_manager_paid_experience: false)
          stub_licensed_features(native_secrets_management: true)
          sign_in(reporter)
        end

        it_behaves_like 'page not found'
      end
    end

    context 'when the paid experience is enabled' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_read_capability(read: true)
        sign_in(reporter)
      end

      {
        trial_eligible: :ok,
        trial: :ok,
        paid: :ok,
        offline_paid: :ok,
        blocked: :ok, # read-only
        ineligible: :not_found
      }.each do |state, http_status|
        context "when the entitlement state is #{state}" do
          before do
            stub_secrets_manager_entitlement(state: state)
          end

          it "responds with #{http_status}" do
            request

            expect(response).to have_gitlab_http_status(http_status)
          end
        end
      end

      context 'when the secrets manager is not provisioned but the namespace is entitled' do
        let_it_be(:unprovisioned_group) { create(:group) }

        subject(:request) do
          get group_secrets_url(unprovisioned_group), params: { group_id: unprovisioned_group.to_param }
        end

        before_all do
          unprovisioned_group.add_reporter(reporter)
        end

        before do
          stub_feature_flags(group_secrets_manager: unprovisioned_group)
          stub_secrets_manager_entitlement(state: :trial)
        end

        it_behaves_like 'group secrets manager page'
      end

      # While provisioning is in flight the user auth mount does not yet exist
      # in OpenBao, so `check_read_capability!` skips the check and the page
      # renders so the user can observe progress.
      context 'when the secrets manager is provisioning' do
        let_it_be(:provisioning_group) { create(:group) }
        let_it_be(:provisioning_sm) { create(:group_secrets_manager, group: provisioning_group) }

        subject(:request) do
          get group_secrets_url(provisioning_group), params: { group_id: provisioning_group.to_param }
        end

        before_all do
          provisioning_group.add_reporter(reporter)
        end

        before do
          stub_feature_flags(group_secrets_manager: provisioning_group)
          stub_secrets_manager_entitlement(state: :trial)
        end

        it_behaves_like 'group secrets manager page'
      end
    end

    # Covers both no read grant and OpenBao unreachable: the service fails
    # closed to read: false, so the controller renders 404 either way. The
    # unreachable-resolves-to-false behavior is covered in the service specs.
    context 'when the user has no effective OpenBao READ capability' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_read_capability(read: false)
        sign_in(reporter)
      end

      it_behaves_like 'page not found'
    end
  end
end
