# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserPolicy, feature_category: :user_management do
  let(:current_user) { create(:user) }
  let(:user) { create(:user) }

  subject { described_class.new(current_user, user) }

  shared_examples 'changing a user' do |ability|
    context 'when a regular user tries to update another regular user' do
      it { is_expected.not_to be_allowed(ability) }
    end

    context 'when a regular user tries to update themselves' do
      let(:current_user) { user }

      it { is_expected.to be_allowed(ability) }
    end

    context 'when an admin user tries to update a regular user' do
      let(:current_user) { create(:user, :admin) }

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(ability) }
      end

      context 'when admin mode disabled' do
        it { is_expected.not_to be_allowed(ability) }
      end
    end

    context 'when an admin user tries to update a ghost user' do
      let(:current_user) { create(:user, :admin) }
      let(:user) { create(:user, :ghost) }

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.not_to be_allowed(ability) }
      end

      context 'when admin mode disabled' do
        it { is_expected.not_to be_allowed(ability) }
      end
    end
  end

  describe "updating a user's name" do
    context 'when `disable_name_update_for_users` feature is available' do
      before do
        stub_licensed_features(disable_name_update_for_users: true)
      end

      context 'when the ability to update their name is not disabled for users' do
        before do
          stub_application_setting(updating_name_disabled_for_users: false)
        end

        it_behaves_like 'changing a user', :update_name
      end

      context 'when the ability to update their name is disabled for users' do
        before do
          stub_application_setting(updating_name_disabled_for_users: true)
        end

        context 'for a regular user' do
          it { is_expected.not_to be_allowed(:update_name) }
        end

        context 'for a ghost user' do
          let(:current_user) { create(:user, :ghost) }

          it { is_expected.not_to be_allowed(:update_name) }
        end

        context 'for an admin user' do
          let(:current_user) { create(:admin) }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:update_name) }
          end

          context 'when admin mode disabled' do
            it { is_expected.not_to be_allowed(:update_name) }
          end

          context 'when admin mode is disabled, and then enabled following sessionless login' do
            def policy
              # method, because we want a fresh cache each time.
              described_class.new(current_user, user)
            end

            it 'changes from prevented to allowed', :request_store do
              expect { Gitlab::Auth::CurrentUserMode.bypass_session!(current_user.id) }
                .to change { policy.allowed?(:update_name) }.from(false).to(true)
            end
          end
        end
      end
    end

    context 'when `disable_name_update_for_users` feature is not available' do
      before do
        stub_licensed_features(disable_name_update_for_users: false)
      end

      it_behaves_like 'changing a user', :update_name
    end
  end

  describe ':destroy_user' do
    context 'when user is not self', :enable_admin_mode do
      let(:current_user) { create(:user, :admin) }

      it { is_expected.to be_allowed(:destroy_user) }
    end

    context 'when user is self' do
      let(:current_user) { user }

      it { is_expected.to be_allowed(:destroy_user) }

      context 'when the user password is automatically set' do
        before do
          current_user.update!(password_automatically_set: true)
        end

        it { is_expected.to be_allowed(:destroy_user) }

        context 'on GitLab.com' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(true)
          end

          it { is_expected.not_to be_allowed(:destroy_user) }
        end
      end
    end

    context 'when deleting an enterprise user', :saas do
      let(:enterprise_group) { create(:group) }
      let(:enterprise_user) { create(:user, enterprise_group: enterprise_group) }

      let(:current_user) { create(:user) }
      let(:user) { enterprise_user }

      before do
        stub_licensed_features(domain_verification: true)
      end

      context 'when current user is Owner of the enterprise group' do
        before do
          enterprise_group.add_owner(current_user)
        end

        it { is_expected.to be_allowed(:destroy_user) }

        context 'when the GitLab instance is not GitLab.com' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(false)
          end

          it { is_expected.not_to be_allowed(:destroy_user) }
        end

        context 'when the domain verification feature is not available' do
          before do
            stub_licensed_features(domain_verification: false)
          end

          it { is_expected.not_to be_allowed(:destroy_user) }
        end

        context 'when the user is not an enterprise user' do
          let(:user) { create(:user) }

          it { is_expected.not_to be_allowed(:destroy_user) }
        end

        context 'when the user is an enterprise user of another enterprise group' do
          let(:user) { create(:enterprise_user) }

          it { is_expected.not_to be_allowed(:destroy_user) }
        end
      end

      context 'when current user is not Owner of the enterprise group' do
        before do
          enterprise_group.add_maintainer(current_user)
        end

        it { is_expected.not_to be_allowed(:destroy_user) }
      end
    end
  end

  describe ':create_personal_access_token' do
    subject { described_class.new(current_user, current_user) }

    context 'when personal access tokens are disabled on instance level' do
      before do
        stub_ee_application_setting(personal_access_tokens_disabled?: true)
      end

      it { is_expected.to be_disallowed(:create_personal_access_token) }
    end

    context 'when personal access tokens are disabled by enterprise group' do
      let_it_be(:enterprise_group) do
        create(:group, namespace_settings: create(:namespace_settings, disable_personal_access_tokens: true))
      end

      let_it_be(:enterprise_user_of_the_group) { create(:enterprise_user, enterprise_group: enterprise_group) }
      let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

      before do
        stub_saas_features(disable_personal_access_tokens: true)
        stub_licensed_features(disable_personal_access_tokens: true)
      end

      context 'for non-enterprise users of the group' do
        let(:current_user) { enterprise_user_of_another_group }

        it { is_expected.to be_allowed(:create_personal_access_token) }
      end

      context 'for enterprise users of the group' do
        let(:current_user) { enterprise_user_of_the_group }

        it { is_expected.to be_disallowed(:create_personal_access_token) }
      end
    end
  end

  describe "making a user profile private" do
    context 'when `disable_private_profiles` feature is available' do
      before do
        stub_licensed_features(disable_private_profiles: true)
      end

      context 'when the ability to make user profile private is not disabled' do
        before do
          stub_application_setting(make_profile_private: true)
        end

        it_behaves_like 'changing a user', :make_profile_private
      end

      context 'when the ability to make user profile private is disabled' do
        before do
          stub_application_setting(make_profile_private: false)
        end

        context 'for a regular user' do
          it { is_expected.not_to be_allowed(:make_profile_private) }
        end

        context 'for an admin user' do
          let(:current_user) { create(:admin) }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:make_profile_private) }
          end

          context 'when admin mode disabled' do
            it { is_expected.not_to be_allowed(:make_profile_private) }
          end
        end
      end
    end

    context 'when `disable_private_profiles` feature is not available' do
      before do
        stub_licensed_features(disable_private_profiles: false)
      end

      it_behaves_like 'changing a user', :make_profile_private
    end
  end

  describe ':read_user_profile' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user_public_profile) { create(:user, private_profile: false) }
    let_it_be(:user_private_profile) { create(:user, private_profile: true) }

    where(:user, :disable_private_profiles?, :make_profile_private?, :allowed?) do
      ref(:user_private_profile) | true  | true  | false
      ref(:user_private_profile) | true  | false | true
      ref(:user_private_profile) | false | true  | false
      ref(:user_private_profile) | false | false | false

      ref(:user_public_profile)  | true  | true  | true
      ref(:user_public_profile)  | true  | false | true
      ref(:user_public_profile)  | false | true  | true
      ref(:user_public_profile)  | false | false | true
    end

    with_them do
      before do
        stub_licensed_features(disable_private_profiles: disable_private_profiles?)
        stub_application_setting(make_profile_private: make_profile_private?)
      end

      it { is_expected.to(allowed? ? be_allowed(:read_user_profile) : be_disallowed(:read_user_profile)) }
    end
  end
end
