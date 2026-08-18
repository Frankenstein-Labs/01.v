# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::CreateService, feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax

  shared_examples_for 'an unsuccessfully created token' do
    it { expect(create_token.success?).to be false }
    it { expect(create_token.message).to eq('Not permitted to create') }
    it { expect(token).to be_nil }
  end

  shared_examples_for "a properly handled expires_at" do
    context 'when expiration policy is licensed' do
      before do
        stub_licensed_features(personal_access_token_expiration_policy: true)
      end

      context 'when instance level expiration date is set' do
        before do
          stub_ee_application_setting(
            max_personal_access_token_lifetime_from_now: instance_level_pat_expiration_date
          )
        end

        it { expect(token.expires_at).to eq instance_level_pat_expiration_date }
      end

      context 'when group level expiration is set' do
        let(:group) do
          build(:group_with_managed_accounts, max_personal_access_token_lifetime: group_level_pat_expiration_policy)
        end

        context 'when user is group managed' do
          let(:target_user) { create(:user, managing_group: group) }

          it { expect(token.expires_at).to eq group_level_max_expiration_date }
        end

        context 'when user is not group managed' do
          it 'sets expires_at to default value' do
            expect(token.expires_at)
            .to eq max_personal_access_token_lifetime
          end
        end
      end

      context 'when neither instance level nor group level expiration is set' do
        it "sets expires_at to default value" do
          expect(token.expires_at)
          .to eq max_personal_access_token_lifetime
        end
      end
    end

    context 'when expiration policy is not licensed' do
      it "sets expires_at to default value" do
        expect(token.expires_at)
        .to eq max_personal_access_token_lifetime
      end
    end
  end

  describe '#execute' do
    subject(:create_token) { service.execute }

    let_it_be(:organization) { create(:organization) }
    let_it_be(:base_user) { create(:user) }

    let(:target_user) { base_user }
    let(:current_user) { target_user }

    let(:service) do
      described_class.new(current_user: current_user, target_user: target_user,
        organization_id: organization.id,
        params: params, concatenate_errors: false)
    end

    let(:valid_params) do
      { name: 'Test token', impersonation: false, scopes: [:api], expires_at: Date.today + 1.month }
    end

    let(:token) { create_token.payload[:personal_access_token] }

    let(:max_personal_access_token_lifetime) do
      if ::Feature.enabled?(:buffered_token_expiration_limit) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Group setting but checked at user
        PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS_BUFFERED.days.from_now.to_date
      else
        PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS.days.from_now.to_date
      end
    end

    context 'when expires_at is nil', :enable_admin_mode do
      let_it_be(:admin_user) { create(:admin) }

      let(:params) { valid_params.merge(expires_at: nil) }
      let(:current_user) { admin_user }
      let(:instance_level_pat_expiration_date) { 30.days.from_now.to_date }
      let(:group_level_pat_expiration_policy) { 20 }
      let(:group_level_max_expiration_date) { Date.current + group_level_pat_expiration_policy }

      context "when buffered_token_expiration_limit is disabled" do
        before do
          stub_feature_flags(buffered_token_expiration_limit: false)
        end

        it_behaves_like "a properly handled expires_at"
      end

      context "when buffered_token_expiration_limit is enabled" do
        it_behaves_like "a properly handled expires_at"
      end
    end

    context 'when target user is a service account', :freeze_time do
      let(:target_user) { create(:user, :service_account) }

      context 'for instance level' do
        let(:params) { valid_params }

        context 'when the current user is an admin' do
          let_it_be(:admin_user) { create(:admin) }

          let(:current_user) { admin_user }

          it_behaves_like 'an unsuccessfully created token'

          context 'when admin mode enabled', :enable_admin_mode do
            it 'creates a token successfully' do
              expect(create_token.success?).to be true
              expect(token.user_type).to eq('service_account')
              expect(token.group).to be_nil
            end

            context 'when expires_at is nil' do
              let(:params) { valid_params.merge(expires_at: nil) }

              around do |example|
                travel_to(Date.new(2024, 8, 24))
                example.run
                travel_back
              end

              where(:require_token_expiry, :buffered_token_expiration_limit,
                :require_token_expiry_for_service_accounts, :expires_at) do
                true | false | true | Date.new(2025, 8, 24) # 1 year from now
                true | false | false | nil
                false | false | true | Date.new(2025, 8, 24) # 1 year from now
                false | false | false | nil
                true | true | true | Date.new(2025, 9, 28) # 1 year from now
                true | true | false | nil
                false | true | true | Date.new(2025, 9, 28) # 1 year from now
                false | true | false | nil
              end
              with_them do
                before do
                  allow(::Authn::ServiceAccounts).to receive(:free_tier?).and_return(false)
                  stub_application_setting(require_personal_access_token_expiry: require_token_expiry)
                  stub_feature_flags(buffered_token_expiration_limit: buffered_token_expiration_limit)
                  stub_ee_application_setting(
                    service_access_tokens_expiration_enforced: require_token_expiry_for_service_accounts)
                end

                it 'optionally sets token expiry based on settings' do
                  expect(token.expires_at).to eq(expires_at)
                end
              end
            end
          end
        end
      end

      context 'for a group' do
        let_it_be_with_reload(:group) { create(:group) }
        let_it_be(:group_owner) { create(:user) }
        let_it_be(:other_group) { create(:group) }

        let(:params) { valid_params.merge(group: group) }
        let(:current_user) { group_owner }

        before_all do
          group.add_owner(group_owner)
        end

        context 'when current user is a group owner' do
          context 'when provisioned by group' do
            before do
              target_user.update!(provisioned_by_group_id: group.id)
            end

            it 'creates a token successfully' do
              expect(create_token.success?).to be true
              expect(token.user_type).to eq('service_account')
              expect(token.group).to eq(group)
            end

            context 'when expires_at is nil' do
              let(:params) { valid_params.merge(group: group, expires_at: nil) }

              context 'when saas', :saas, :enable_admin_mode do
                where(:require_token_expiry, :buffered_token_expiration_limit,
                  :require_token_expiry_for_service_accounts, :expires_at) do
                  true | false | true |
                    PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS.days.from_now.to_date
                  true | false | false | nil
                  false | false | true |
                    PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS.days.from_now.to_date
                  false | false | false | nil
                  true | true | true |
                    PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS_BUFFERED.days.from_now.to_date
                  true | true | false | nil
                  false | true | true |
                    PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS_BUFFERED.days.from_now.to_date
                  false | true | false | nil
                end
                with_them do
                  before do
                    allow(::Authn::ServiceAccounts).to receive(:free_tier_namespace?).and_return(false)
                    stub_application_setting(require_personal_access_token_expiry: require_token_expiry)
                    stub_feature_flags(buffered_token_expiration_limit: buffered_token_expiration_limit)
                    group.namespace_settings.update!(
                      service_access_tokens_expiration_enforced: require_token_expiry_for_service_accounts)
                  end

                  it 'optionally sets token expiry based on settings' do
                    expect(token.expires_at).to eq(expires_at)
                  end
                end
              end

              context 'when not saas' do
                it "does not set expires_at to be nil" do
                  expect(create_token.payload[:personal_access_token].expires_at)
                  .to eq max_personal_access_token_lifetime
                end
              end
            end

            context 'when provisioned by sub-group (legacy data)' do
              let_it_be(:parent_group) { create(:group) }
              let_it_be(:sub_group) { create(:group, parent: parent_group) }

              let(:group) { sub_group }

              before_all do
                parent_group.add_owner(group_owner)
              end

              before do
                target_user.update!(provisioned_by_group_id: sub_group.id)
              end

              it 'creates token with root group id' do
                expect(create_token.success?).to be true
                expect(token.group).to eq(parent_group)
              end
            end
          end

          context 'when not provisioned by group' do
            it_behaves_like 'an unsuccessfully created token'
          end

          context 'when provisioned by a different group' do
            before do
              target_user.update!(provisioned_by_group_id: other_group.id)
            end

            it_behaves_like 'an unsuccessfully created token'
          end
        end

        context 'when current user is not a group owner' do
          let_it_be(:guest_user) { create(:user) }

          let(:current_user) { guest_user }

          before_all do
            group.add_guest(guest_user)
          end

          it_behaves_like 'an unsuccessfully created token'
        end

        context 'when service account is provisioned by a different group than the one in params' do
          before do
            target_user.update!(provisioned_by_group_id: other_group.id)
          end

          it 'does not permit token creation due to group ID mismatch' do
            expect(create_token.success?).to be false
            expect(create_token.message).to eq('Not permitted to create')
            expect(token).to be_nil
          end
        end
      end

      context 'for a project' do
        let_it_be(:project) { create(:project) }
        let_it_be(:project_owner) { create(:user) }
        let_it_be(:project_maintainer) { create(:user) }
        let_it_be(:project_developer) { create(:user) }
        let_it_be(:other_project) { create(:project) }

        let(:params) { valid_params.merge(project: project) }
        let(:current_user) { project_owner }

        before_all do
          project.add_owner(project_owner)
          project.add_maintainer(project_maintainer)
          project.add_developer(project_developer)
        end

        context 'when current user is a project owner' do
          context 'when provisioned by project' do
            before do
              target_user.update!(provisioned_by_project_id: project.id)
            end

            it 'creates a token successfully' do
              expect(create_token.success?).to be true
              expect(token.user_type).to eq('service_account')
            end
          end

          context 'when not provisioned by project' do
            it_behaves_like 'an unsuccessfully created token'
          end

          context 'when provisioned by a different project' do
            before do
              target_user.update!(provisioned_by_project_id: other_project.id)
            end

            it_behaves_like 'an unsuccessfully created token'
          end
        end

        context 'when current user is a project maintainer' do
          let(:current_user) { project_maintainer }

          before do
            target_user.update!(provisioned_by_project_id: project.id)
          end

          it 'creates a token successfully' do
            expect(create_token.success?).to be true
            expect(token.user_type).to eq('service_account')
          end

          context 'when provisioned by a different project' do
            before do
              target_user.update!(provisioned_by_project_id: other_project.id)
            end

            it_behaves_like 'an unsuccessfully created token'
          end
        end

        context 'when current user is not a project owner or maintainer' do
          let(:current_user) { project_developer }

          before do
            target_user.update!(provisioned_by_project_id: project.id)
          end

          it_behaves_like 'an unsuccessfully created token'
        end

        context 'when service account is provisioned by a different project than the one in params' do
          before do
            target_user.update!(provisioned_by_project_id: other_project.id)
          end

          it 'does not permit token creation due to project ID mismatch' do
            expect(create_token.success?).to be false
            expect(create_token.message).to eq('Not permitted to create')
            expect(token).to be_nil
          end
        end
      end
    end

    context 'when personal access tokens are disabled by enterprise group' do
      let_it_be(:enterprise_group) do
        create(:group, namespace_settings: create(:namespace_settings, disable_personal_access_tokens: true))
      end

      let_it_be(:enterprise_user_of_the_group) { create(:enterprise_user, enterprise_group: enterprise_group) }
      let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

      let(:params) { valid_params }

      before do
        stub_saas_features(disable_personal_access_tokens: true)
        stub_licensed_features(disable_personal_access_tokens: true)
      end

      context 'for non-enterprise users of the group' do
        let(:current_user) { enterprise_user_of_another_group }
        let(:target_user) { enterprise_user_of_another_group }

        it 'creates a token successfully' do
          expect(create_token.success?).to be true
        end
      end

      context 'for enterprise users of the group' do
        let(:current_user) { enterprise_user_of_the_group }
        let(:target_user) { enterprise_user_of_the_group }

        it_behaves_like 'an unsuccessfully created token'
      end
    end

    context 'for group_id' do
      let(:params) { valid_params }

      context 'when the user is an enterprise user' do
        let_it_be(:enterprise_target_user) { create(:enterprise_user) }

        let(:target_user) { enterprise_target_user }
        let(:current_user) { enterprise_target_user }

        it "creates personal access token record with group_id set to the user's enterprise_group_id" do
          expect(enterprise_target_user.enterprise_group_id).not_to be_nil

          expect(create_token.success?).to be true
          expect(token.group_id).to eq(enterprise_target_user.enterprise_group_id)
        end
      end

      context 'when the user is a regular user' do
        let_it_be(:regular_user) { create(:user) }

        let(:target_user) { regular_user }
        let(:current_user) { regular_user }

        it "creates personal access token record with group_id set to nil" do
          expect(create_token.success?).to be true
          expect(token.group_id).to be_nil
        end
      end
    end
  end
end
