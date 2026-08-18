# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Git HTTP requests', feature_category: :source_code_management do
  include GitHttpHelpers
  include WorkhorseHelpers
  include NamespaceStorageHelpers

  shared_examples_for 'pulls are allowed' do
    specify do
      download(path, **env) do |response|
        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
      end
    end
  end

  shared_examples_for 'pushes are allowed' do
    specify do
      upload(path, **env) do |response|
        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
      end
    end
  end

  describe "User with no identities" do
    let(:user) { create(:user) }
    let(:project) { create(:project, :repository, :private) }
    let(:path) { "#{project.full_path}.git" }

    context "when Kerberos token is provided" do
      let(:env) { { spnego_request_token: 'opaque_request_token' } }

      before do
        allow_any_instance_of(::Repositories::GitHttpController).to receive(:allow_kerberos_auth?).and_return(true)
      end

      context "when authentication fails because of invalid Kerberos token" do
        before do
          allow_any_instance_of(::Repositories::GitHttpController).to receive(:spnego_credentials!).and_return(nil)
        end

        it "responds with status 401 Unauthorized" do
          download(path, **env) do |response|
            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end
      end

      context "when authentication fails because of unknown Kerberos identity" do
        before do
          allow_any_instance_of(::Repositories::GitHttpController).to receive(:spnego_credentials!).and_return("mylogin@FOO.COM")
        end

        it "responds with status 401 Unauthorized" do
          download(path, **env) do |response|
            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end
      end

      context "when authentication succeeds" do
        before do
          allow_any_instance_of(::Repositories::GitHttpController).to receive(:spnego_credentials!).and_return("mylogin@FOO.COM")
          user.identities.create!(provider: "kerberos", extern_uid: "mylogin@FOO.COM")
        end

        context "when the user has access to the project" do
          before do
            project.add_maintainer(user)
          end

          context "when the user is blocked" do
            before do
              user.block
              project.add_maintainer(user)
            end

            it "responds with status 403 Forbidden" do
              download(path, **env) do |response|
                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end
          end

          context "when the user isn't blocked", :redis do
            it "responds with status 200 OK" do
              download(path, **env) do |response|
                expect(response).to have_gitlab_http_status(:ok)
              end
            end

            it 'updates the user last activity' do
              expect(user.last_activity_on).to be_nil

              download(path, **env) do |_response|
                expect(user.reload.last_activity_on).to eql(Date.today)
              end
            end
          end

          it "complies with RFC4559" do
            allow_any_instance_of(::Repositories::GitHttpController).to receive(:spnego_response_token).and_return("opaque_response_token")
            download(path, **env) do |response|
              expect(response.headers['WWW-Authenticate'].split("\n")).to include("Negotiate #{::Base64.strict_encode64('opaque_response_token')}")
            end
          end
        end

        context "when the user doesn't have access to the project" do
          it "responds with status 404 Not Found" do
            download(path, **env) do |response|
              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          it "complies with RFC4559" do
            allow_any_instance_of(::Repositories::GitHttpController).to receive(:spnego_response_token).and_return("opaque_response_token")
            download(path, **env) do |response|
              expect(response.headers['WWW-Authenticate'].split("\n")).to include("Negotiate #{::Base64.strict_encode64('opaque_response_token')}")
            end
          end
        end
      end
    end

    context 'when license is not provided' do
      let(:env) { { user: user.username, password: user.password } }

      before do
        allow(License).to receive(:current).and_return(nil)

        project.add_maintainer(user)
      end

      it_behaves_like 'pulls are allowed'
      it_behaves_like 'pushes are allowed'
    end
  end

  describe 'when SSO is enforced' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }
    let(:project) { create(:project, :repository, :private, group: group) }
    let(:env) { { user: user.username, password: user.password } }
    let(:path) { "#{project.full_path}.git" }

    before do
      project.add_developer(user)
      create(:saml_provider, group: group, enforced_sso: true)
    end

    it_behaves_like 'pulls are allowed'
  end

  context 'when password authentication disabled by enterprise group' do
    let_it_be(:enterprise_group) { create(:group) }
    let_it_be(:saml_provider) { create(:saml_provider, group: enterprise_group, enabled: true, disable_password_authentication_for_enterprise_users: true) }

    let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

    let_it_be(:project) { create(:project, :repository, :private, group: enterprise_group) }

    let(:env) { { user: user.username, password: user.password } }
    let(:path) { "#{project.full_path}.git" }

    before do
      project.add_developer(user)
    end

    it 'responds with status 401 Unauthorized for pull action' do
      download(path, **env) do |response|
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it 'responds with status 401 Unauthorized for push action' do
      upload(path, **env) do |response|
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when username and personal access token are provided' do
      let(:access_token) { create(:personal_access_token, user: user) }
      let(:env) { { user: user.username, password: access_token.token } }

      it_behaves_like 'pulls are allowed'
      it_behaves_like 'pushes are allowed'
    end
  end

  context 'when personal access tokens are disabled by enterprise group' do
    let_it_be(:enterprise_group) { create(:group, namespace_settings: create(:namespace_settings, disable_personal_access_tokens: true)) }
    let_it_be(:project) { create(:project, :repository, :private, group: enterprise_group) }

    let_it_be(:enterprise_user_of_the_group) { create(:enterprise_user, enterprise_group: enterprise_group) }
    let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

    let(:path) { "#{project.full_path}.git" }
    let(:access_token) { create(:personal_access_token, user: user) }
    let(:env) { { user: user.username, password: access_token.token } }

    before do
      stub_saas_features(disable_personal_access_tokens: true)
      stub_licensed_features(disable_personal_access_tokens: true)

      project.add_developer(enterprise_user_of_the_group)
      project.add_developer(enterprise_user_of_another_group)
    end

    context 'for non-enterprise users of the group' do
      context 'when username and personal access token are provided' do
        let(:user) { enterprise_user_of_another_group }

        it_behaves_like 'pulls are allowed'
        it_behaves_like 'pushes are allowed'
      end
    end

    context 'for enterprise users of the group' do
      context 'when username and personal access token are provided' do
        let(:user) { enterprise_user_of_the_group }

        it 'responds with status 401 Unauthorized for pull action' do
          download(path, **env) do |response|
            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end

        it 'responds with status 401 Unauthorized for push action' do
          upload(path, **env) do |response|
            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end
      end
    end
  end

  describe 'when namespace storage limits are enforced', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, :private, group: group) }

    let(:path) { "#{project.full_path}.git" }
    let(:env) { { user: user.username, password: user.password } }

    before_all do
      create(:gitlab_subscription, :ultimate, namespace: group)
      create(:namespace_root_storage_statistics, namespace: group)
      project.add_developer(user)
    end

    before do
      enforce_namespace_storage_limit(group)
      set_enforcement_limit(group, megabytes: 8)
    end

    it_behaves_like 'pushes are allowed'

    context 'when the limit has been exceeded' do
      before do
        set_used_storage(group, megabytes: 14)
      end

      it_behaves_like 'pushes are allowed'
    end
  end
end
