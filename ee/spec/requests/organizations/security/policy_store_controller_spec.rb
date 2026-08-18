# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Security::PolicyStoreController, feature_category: :security_policy_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
    stub_application_setting(policy_store_experiment_enabled: true)
  end

  it 'declares the security_policy_management feature category' do
    expect(described_class.feature_category_for_action('index')).to eq(:security_policy_management)
  end

  shared_examples 'a policy store page' do |mount_id = '#js-policy-store'|
    context 'when the user is not signed in' do
      it_behaves_like 'organization - redirects to sign in page'
    end

    context 'when the user is signed in' do
      before do
        sign_in(user)
      end

      context 'with no association to the organization' do
        it_behaves_like 'organization - not found response'
      end

      context 'as a non-owner member of the organization' do
        before_all do
          create(:organization_user, organization: organization, user: user)
        end

        it_behaves_like 'organization - not found response'
      end

      context 'as an owner of the organization' do
        before_all do
          create(:organization_user, :owner, organization: organization, user: user)
        end

        it_behaves_like 'organization - successful response'

        it 'renders the element the policy store mounts into' do
          gitlab_request

          expect(response.body).to have_css(mount_id)
        end

        context 'when the security_policies_v2 feature flag is disabled' do
          before do
            stub_feature_flags(security_policies_v2: false)
          end

          it_behaves_like 'organization - not found response'
        end

        context 'when the policy store experiment instance setting is disabled' do
          before do
            stub_application_setting(policy_store_experiment_enabled: false)
          end

          it_behaves_like 'organization - not found response'
        end

        context 'when the security_orchestration_policies licensed feature is unavailable' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it_behaves_like 'organization - not found response'
        end
      end

      context 'as an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        it_behaves_like 'organization - successful response'
      end
    end
  end

  shared_examples 'a read-authorized page' do |mount_id = '#js-policy-store'|
    it_behaves_like 'a policy store page', mount_id

    context 'as an owner who cannot read policies' do
      before_all do
        create(:organization_user, :owner, organization: organization, user: user)
      end

      before do
        sign_in(user)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(user, :read_govern_policy, organization).and_return(false)
      end

      it_behaves_like 'organization - not found response'
    end
  end

  context 'when the organization does not exist' do
    subject(:gitlab_request) { get security_policy_store_organization_path('non-existent-organization') }

    before do
      sign_in(user)
    end

    it_behaves_like 'organization - not found response'
  end

  describe 'GET #index' do
    subject(:gitlab_request) { get security_policy_store_organization_path(organization) }

    it_behaves_like 'a read-authorized page'
  end

  describe 'GET #show' do
    subject(:gitlab_request) { get security_policy_store_policy_organization_path(organization, '1') }

    it_behaves_like 'a read-authorized page', '#js-policy-store-detail'
  end

  shared_examples 'a policy editor page' do |required_ability|
    it_behaves_like 'a policy store page'

    context "as an owner who lacks #{required_ability}" do
      before_all do
        create(:organization_user, :owner, organization: organization, user: user)
      end

      before do
        sign_in(user)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(user, required_ability, organization).and_return(false)
      end

      it_behaves_like 'organization - not found response'
    end
  end

  describe 'GET #new' do
    subject(:gitlab_request) { get new_security_policy_store_organization_path(organization) }

    it_behaves_like 'a policy editor page', :create_govern_policy
  end

  describe 'GET #edit' do
    subject(:gitlab_request) { get edit_security_policy_store_organization_path(organization, '1') }

    it_behaves_like 'a policy editor page', :update_govern_policy
  end
end
