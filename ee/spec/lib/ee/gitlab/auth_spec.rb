# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth, :use_clean_rails_memory_store_caching, feature_category: :system_access do
  let_it_be(:project) { create(:project) }

  let(:auth_failure) { { actor: nil, project: nil, type: nil, authentication_abilities: nil } }
  let(:gl_auth) { described_class }

  describe '.unavailable_ai_features_scopes' do
    subject(:unavailable_scopes) { described_class.send(:unavailable_ai_features_scopes) }

    context 'when Duo is disabled' do
      before do
        stub_application_setting(duo_features_enabled: false)
      end

      it 'includes AI_FEATURES_SCOPES' do
        expect(unavailable_scopes).to include(*described_class::AI_FEATURES_SCOPES)
      end
    end

    context 'when Duo is enabled' do
      before do
        stub_application_setting(duo_features_enabled: true)
      end

      it 'does not include AI_FEATURES_SCOPES' do
        expect(unavailable_scopes).not_to include(*described_class::AI_FEATURES_SCOPES)
      end
    end
  end

  describe '.find_for_git_client' do
    let(:request) { instance_double(ActionDispatch::Request, ip: 'ip', path: path) }
    let(:path) { '/some_path/example' }

    context 'when using personal access token as password' do
      shared_examples 'successfully authenticates' do
        it 'successfully authenticates' do
          expect(
            gl_auth.find_for_git_client(
              personal_access_token.user.username,
              personal_access_token.token,
              project: project,
              request: request
            )
          ).to have_attributes(
            actor: personal_access_token.user,
            project: nil,
            type: :personal_access_token,
            authentication_abilities: described_class.full_authentication_abilities
          )
        end
      end

      shared_examples 'fails to authenticate' do
        it 'fails to authenticate' do
          expect(
            gl_auth.find_for_git_client(
              personal_access_token.user.username,
              personal_access_token.token,
              project: project,
              request: request
            )
          ).to have_attributes(auth_failure)
        end
      end

      context 'when personal access tokens are disabled on instance level' do
        before do
          stub_licensed_features(disable_personal_access_tokens: true)
          stub_application_setting(disable_personal_access_tokens: true)
        end

        context 'when using personal access token' do
          let_it_be(:personal_access_token) { create(:personal_access_token, scopes: ['api']) }

          context 'when project is nil' do
            let(:project) { nil }

            include_examples 'fails to authenticate'
          end
        end

        context 'when using impersonation token' do
          let_it_be(:personal_access_token) { create(:personal_access_token, :impersonation, scopes: ['api']) }

          context 'when project is nil' do
            let(:project) { nil }

            include_examples 'fails to authenticate'
          end
        end

        context 'when using a resource access token' do
          let_it_be(:project_bot_user) { create(:user, :project_bot) }
          let_it_be(:personal_access_token) { create(:personal_access_token, user: project_bot_user) }

          context 'when the user is a member of the project' do
            before_all do
              project.add_maintainer(project_bot_user)
            end

            include_examples 'fails to authenticate'
          end
        end
      end

      context 'when personal access tokens are disabled by enterprise group' do
        let_it_be(:enterprise_group) do
          create(:group, namespace_settings: create(:namespace_settings, disable_personal_access_tokens: true))
        end

        let_it_be(:enterprise_user_of_the_group) { create(:enterprise_user, enterprise_group: enterprise_group) }
        let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

        let!(:personal_access_token) { create(:personal_access_token, user: user) }

        before do
          stub_saas_features(disable_personal_access_tokens: true)
          stub_licensed_features(disable_personal_access_tokens: true)
        end

        context 'for non-enterprise users of the group' do
          let(:user) { enterprise_user_of_another_group }

          include_examples 'successfully authenticates'
        end

        context 'for enterprise users of the group' do
          let(:user) { enterprise_user_of_the_group }

          include_examples 'fails to authenticate'
        end
      end

      context "when using a service account's personal access token" do
        let_it_be(:service_account) { create(:user, :service_account) }
        let_it_be(:personal_access_token) { create(:personal_access_token, user: service_account) }

        context 'when the service account is a member of the project' do
          before_all do
            project.add_maintainer(service_account)
          end

          include_examples 'successfully authenticates'
        end

        context 'when the service account is not a member of the project' do
          include_examples 'fails to authenticate'
        end

        context 'when project is nil' do
          let(:project) { nil }

          include_examples 'successfully authenticates'
        end
      end
    end

    context 'when using build token as password' do
      subject(:auth_result) { gl_auth.find_for_git_client(username, build.token, project: project, request: request) }

      let(:username) { 'gitlab-ci-token' }

      context 'for running build' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let(:build) { create(:ci_build, :running, project: project) }

        context 'when the build author is the service account' do
          let_it_be(:service_account) { create(:user, :service_account) }

          before do
            build.update!(user: service_account)
          end

          it 'recognises project level service_account access token' do
            project.add_maintainer(build.user)

            expect(auth_result).to have_attributes(
              actor: build.user,
              project: build.project,
              type: :build,
              authentication_abilities: described_class.build_authentication_abilities
            )
          end

          it 'recognises group level service_account access token' do
            group.add_maintainer(build.user)

            expect(auth_result).to have_attributes(
              actor: build.user,
              project: build.project,
              type: :build,
              authentication_abilities: described_class.build_authentication_abilities
            )
          end
        end
      end
    end
  end
end
