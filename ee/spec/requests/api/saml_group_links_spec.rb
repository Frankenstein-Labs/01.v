# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::SamlGroupLinks, :api, feature_category: :system_access do
  include ApiHelpers

  let_it_be(:owner) { create(:user) }
  let_it_be(:user) { create(:user) }
  let(:current_user) { nil }

  let_it_be(:group_with_saml_group_links) { create(:group) }
  let_it_be(:member_role) do
    create(:member_role, namespace: group_with_saml_group_links, base_access_level: ::Gitlab::Access::GUEST)
  end

  let_it_be(:saml_provider) { create(:saml_provider, group: group_with_saml_group_links, enabled: true) }
  let_it_be(:group_id) { group_with_saml_group_links.id }

  before_all do
    group_with_saml_group_links.saml_group_links.create!(saml_group_name: "saml-group1",
      access_level: ::Gitlab::Access::GUEST)
    group_with_saml_group_links.saml_group_links.create!(saml_group_name: "saml-group2",
      access_level: ::Gitlab::Access::GUEST)
    group_with_saml_group_links.saml_group_links.create!(saml_group_name: "saml-group3",
      access_level: ::Gitlab::Access::GUEST, member_role_id: member_role.id)
    group_with_saml_group_links.add_owner owner
    group_with_saml_group_links.add_member user, Gitlab::Access::DEVELOPER
  end

  shared_examples 'has expected results' do
    it "returns SAML group links" do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to(
        match([
          { "access_level" => ::Gitlab::Access::GUEST, "name" => "saml-group1", "provider" => nil },
          { "access_level" => ::Gitlab::Access::GUEST, "name" => "saml-group2", "provider" => nil },
          { "access_level" => ::Gitlab::Access::GUEST, "name" => "saml-group3", "provider" => nil }
        ])
      )
    end
  end

  describe "GET /groups/:id/saml_group_links" do
    subject { get api("/groups/#{group_id}/saml_group_links", current_user) }

    context "when license feature is available" do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      context "when unauthorized" do
        it "returns unauthorized error" do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when a less privileged user" do
        let(:current_user) { user }

        it "returns unauthorized error" do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when owner of the group" do
        let(:current_user) { owner }

        it_behaves_like 'has expected results'

        context "when group does not have any associated saml_group_links" do
          let_it_be(:group_with_no_saml_links) { create(:group) }
          let_it_be(:saml_provider) do
            create(:saml_provider, group: group_with_no_saml_links, enabled: true)
          end

          let_it_be(:group_id) { group_with_no_saml_links.id }

          before do
            group_with_no_saml_links.add_owner owner
          end

          it "returns empty array as response" do
            subject

            aggregate_failures "testing response" do
              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).to(match([]))
            end
          end
        end

        context 'with URL-encoded path of the group' do
          let(:group_id) { group_with_saml_group_links.full_path }

          it_behaves_like 'has expected results'
        end

        context 'when group has provider-scoped SAML group links' do
          let(:current_user) { owner }

          let_it_be(:group) { create(:group) }
          let(:group_id) { group.id }

          before do
            group.add_owner(owner)

            create(:saml_provider, group: group, enabled: true)

            group.saml_group_links.create!(
              saml_group_name: "provider-group1", access_level: ::Gitlab::Access::GUEST, provider: "saml_provider_1"
            )
            group.saml_group_links.create!(
              saml_group_name: "provider-group2", access_level: ::Gitlab::Access::DEVELOPER, provider: "saml_provider_2"
            )
          end

          it "returns SAML group links with provider information" do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to(
              match([
                {
                  "access_level" => ::Gitlab::Access::GUEST,
                  "name" => "provider-group1",
                  "provider" => "saml_provider_1"
                },
                {
                  "access_level" => ::Gitlab::Access::DEVELOPER,
                  "name" => "provider-group2",
                  "provider" => "saml_provider_2"
                }
              ])
            )
          end
        end
      end
    end

    context "when license feature is not available" do
      let(:current_user) { owner }

      it "returns unauthorized error" do
        subject

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_saml_group_link do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      let(:user) { owner }
      let(:boundary_object) { group_with_saml_group_links }
      let(:request) { get api("/groups/#{group_id}/saml_group_links", personal_access_token: pat) }
    end
  end

  describe "POST /groups/:id/saml_group_links" do
    let_it_be(:params) { { saml_group_name: "Test group", access_level: ::Gitlab::Access::GUEST } }

    subject { post api("/groups/#{group_id}/saml_group_links", current_user), params: params }

    context "when licensed feature is available" do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      context "when unauthorized" do
        it "returns unauthorized error" do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when a less privileged user" do
        let(:current_user) { user }

        it "does not allow less privileged user to add SAML group link" do
          expect do
            subject
          end.not_to change { group_with_saml_group_links.saml_group_links.count }

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when owner of the group and group is saml enabled" do
        let(:current_user) { owner }

        it "returns ok and add saml group link" do
          expect do
            subject
          end.to change { group_with_saml_group_links.saml_group_links.count }.by(1)

          aggregate_failures "testing response" do
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['name']).to eq('Test group')
            expect(json_response['access_level']).to eq(::Gitlab::Access::GUEST)
            expect(json_response['provider']).to be_nil
          end
        end

        context 'with minimal access level' do
          let_it_be(:params) { { saml_group_name: "Test group", access_level: ::Gitlab::Access::MINIMAL_ACCESS } }

          it 'creates a saml group link with minimal access level' do
            expect { subject }.not_to change { group_with_saml_group_links.saml_group_links.count }
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('Access level is invalid')
          end

          context 'with minimal access role licensed feature enabled' do
            before do
              stub_licensed_features(minimal_access_role: true, saml_group_sync: true)
            end

            it 'creates a saml group link with minimal access level' do
              expect { subject }.to change { group_with_saml_group_links.saml_group_links.count }.by(1)

              expect(json_response['access_level']).to eq(::Gitlab::Access::MINIMAL_ACCESS)
            end
          end
        end

        context 'when providing a provider parameter' do
          let(:params) { super().merge(provider: 'saml_provider_1') }

          it "adds saml group link with provider" do
            expect do
              subject
            end.to change { group_with_saml_group_links.saml_group_links.count }.by(1)

            aggregate_failures "testing response" do
              expect(response).to have_gitlab_http_status(:created)
              expect(json_response['name']).to eq('Test group')
              expect(json_response['access_level']).to eq(::Gitlab::Access::GUEST)
              expect(json_response['provider']).to eq('saml_provider_1')
            end
          end
        end

        context 'when providing a member_role_id', :aggregate_failures, feature_category: :permissions do
          let(:params) { super().merge(member_role_id: member_role.id) }

          context 'when custom roles are not enabled' do
            it 'adds the saml group link without the provided `member_role_id`' do
              subject
              expect(json_response.keys).not_to include(:member_role_id)
            end
          end

          context 'when custom roles are enabled' do
            before do
              stub_licensed_features(group_saml: true, saml_group_sync: true, custom_roles: true)
            end

            it 'adds the saml group link with the provided `member_role_id`' do
              subject
              expect(json_response['member_role_id']).to eq(member_role.id)
            end
          end
        end

        context "when params are missing" do
          let(:params) { { saml_group_name: "Test group" } }

          it "returns a 400 error when params are missing" do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context "when params are invalid" do
          let(:params) { { saml_group_name: "Test group", access_level: 11 } }

          it "returns a 400 error when params are invalid" do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when provider parameter is too long' do
          let(:params) { super().merge(provider: 'a' * 256) }

          it "returns a 400 error when provider is too long" do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when creating duplicate group links with different providers' do
          before do
            group_with_saml_group_links.saml_group_links.create!(
              saml_group_name: 'Test group', access_level: ::Gitlab::Access::GUEST, provider: 'provider1'
            )
          end

          let(:params) { super().merge(provider: 'provider2') }

          it "allows creating a link with same group name but different provider" do
            expect do
              subject
            end.to change { group_with_saml_group_links.saml_group_links.count }.by(1)

            aggregate_failures "testing response" do
              expect(response).to have_gitlab_http_status(:created)
              expect(json_response['name']).to eq('Test group')
              expect(json_response['access_level']).to eq(::Gitlab::Access::GUEST)
              expect(json_response['provider']).to eq('provider2')
            end
          end
        end

        context 'when creating duplicate group links with same provider' do
          before do
            group_with_saml_group_links.saml_group_links.create!(
              saml_group_name: 'Test group', access_level: ::Gitlab::Access::GUEST, provider: 'provider1'
            )
          end

          let(:params) { super().merge(provider: 'provider1') }

          it "returns a 400 error for duplicate group name and provider" do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('Saml group name has already been taken')
          end
        end

        context 'when creating duplicate group links with nil provider' do
          before do
            group_with_saml_group_links.saml_group_links.create!(
              saml_group_name: 'Test group', access_level: ::Gitlab::Access::GUEST, provider: nil
            )
          end

          it "returns a 400 error for duplicate group name with nil provider" do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('Saml group name has already been taken')
          end
        end

        context 'when creating link with same group name but one has nil provider' do
          before do
            group_with_saml_group_links.saml_group_links.create!(
              saml_group_name: 'Test group', access_level: ::Gitlab::Access::GUEST, provider: nil
            )
          end

          let(:params) { super().merge(provider: 'provider1') }

          it "allows creating a link with same group name when existing has nil provider" do
            expect do
              subject
            end.to change { group_with_saml_group_links.saml_group_links.count }.by(1)

            aggregate_failures "testing response" do
              expect(response).to have_gitlab_http_status(:created)
              expect(json_response['name']).to eq('Test group')
              expect(json_response['access_level']).to eq(::Gitlab::Access::GUEST)
              expect(json_response['provider']).to eq('provider1')
            end
          end
        end

        context 'when providing empty string as provider' do
          let(:params) { super().merge(provider: '') }

          it "normalizes empty string provider to nil" do
            expect do
              subject
            end.to change { group_with_saml_group_links.saml_group_links.count }.by(1)

            aggregate_failures "testing response" do
              expect(response).to have_gitlab_http_status(:created)
              expect(json_response['name']).to eq('Test group')
              expect(json_response['access_level']).to eq(::Gitlab::Access::GUEST)
              expect(json_response['provider']).to be_nil
            end

            created_link = group_with_saml_group_links.saml_group_links.last
            expect(created_link.provider).to be_nil
          end
        end
      end
    end

    context "when licensed feature is not available" do
      let(:current_user) { owner }

      it "returns unauthorized error" do
        subject

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_saml_group_link do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      let(:user) { owner }
      let(:boundary_object) { group_with_saml_group_links }
      let(:request) { post api("/groups/#{group_id}/saml_group_links", personal_access_token: pat), params: params }
    end
  end

  describe "GET /groups/:id/saml_group_links/:saml_group_name" do
    let_it_be(:saml_group_name) { "saml-group1" }

    subject { get api("/groups/#{group_id}/saml_group_links/#{saml_group_name}", current_user) }

    context "when licensed feature is available" do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      context "when unauthorized" do
        it "returns unauthorized error" do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when owner of the group" do
        let(:current_user) { owner }

        it "gets saml group link" do
          subject

          aggregate_failures "testing response" do
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['name']).to eq('saml-group1')
            expect(json_response['access_level']).to eq(::Gitlab::Access::GUEST)
            expect(json_response['provider']).to be_nil
          end
        end

        context "when invalid group name is passed" do
          let(:saml_group_name) { "saml-group1356" }

          it "returns 404 if SAML group can not used for a SAML group link" do
            subject

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context "when getting a provider-scoped SAML group link" do
          let(:current_user) { owner }

          let_it_be(:group_with_provider_link) { create(:group) }
          let_it_be(:saml_provider_for_get) do
            create(:saml_provider, group: group_with_provider_link, enabled: true)
          end

          let_it_be(:group_id) { group_with_provider_link.id }
          let_it_be(:saml_group_name) { "provider-scoped-group" }

          before do
            group_with_provider_link.saml_group_links.create!(saml_group_name: "provider-scoped-group",
              access_level: ::Gitlab::Access::MAINTAINER, provider: "test_provider")
            group_with_provider_link.add_owner(owner)
          end

          it "gets saml group link with provider information" do
            subject

            aggregate_failures "testing response" do
              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response['name']).to eq('provider-scoped-group')
              expect(json_response['access_level']).to eq(::Gitlab::Access::MAINTAINER)
              expect(json_response['provider']).to eq('test_provider')
            end
          end
        end

        context "when multiple links exist with same group name but different providers" do
          let(:current_user) { owner }

          let_it_be(:group_with_multiple_links) { create(:group) }
          let_it_be(:saml_provider_for_get) do
            create(:saml_provider, group: group_with_multiple_links, enabled: true)
          end

          let_it_be(:group_id) { group_with_multiple_links.id }
          let_it_be(:saml_group_name) { "shared-group-name" }

          before do
            group_with_multiple_links.saml_group_links.create!(
              saml_group_name: "shared-group-name",
              access_level: ::Gitlab::Access::GUEST,
              provider: "provider1"
            )
            group_with_multiple_links.saml_group_links.create!(
              saml_group_name: "shared-group-name",
              access_level: ::Gitlab::Access::DEVELOPER,
              provider: "provider2"
            )
            group_with_multiple_links.saml_group_links.create!(
              saml_group_name: "shared-group-name",
              access_level: ::Gitlab::Access::MAINTAINER,
              provider: nil
            )
            group_with_multiple_links.add_owner(owner)
          end

          it "returns error when multiple links exist without provider parameter" do
            subject

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include(
              'Multiple group links found with the same name. Please specify a provider parameter to disambiguate.'
            )
          end

          context "when provider parameter is specified" do
            subject do
              get api("/groups/#{group_id}/saml_group_links/#{saml_group_name}?provider=provider2", current_user)
            end

            it "gets the specific link for the provider" do
              subject

              aggregate_failures "testing response" do
                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['name']).to eq('shared-group-name')
                expect(json_response['access_level']).to eq(::Gitlab::Access::DEVELOPER)
                expect(json_response['provider']).to eq('provider2')
              end
            end
          end

          context "when provider parameter is empty string" do
            subject { get api("/groups/#{group_id}/saml_group_links/#{saml_group_name}?provider=", current_user) }

            it "gets the link with nil provider" do
              subject

              aggregate_failures "testing response" do
                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['name']).to eq('shared-group-name')
                expect(json_response['access_level']).to eq(::Gitlab::Access::MAINTAINER)
                expect(json_response['provider']).to be_nil
              end
            end
          end

          context "when provider parameter is whitespace-only" do
            subject do
              get api("/groups/#{group_id}/saml_group_links/#{saml_group_name}?provider=%20%20%20", current_user)
            end

            it "gets the link with nil provider" do
              subject

              aggregate_failures "testing response" do
                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['name']).to eq('shared-group-name')
                expect(json_response['access_level']).to eq(::Gitlab::Access::MAINTAINER)
                expect(json_response['provider']).to be_nil
              end
            end
          end
        end

        context "when group link contains a period" do
          let_it_be(:saml_group_name) { "saml-group-with.period" }

          before do
            group_with_saml_group_links.saml_group_links.create!(saml_group_name: saml_group_name,
              access_level: ::Gitlab::Access::GUEST)
          end

          it "returns the saml group link" do
            subject

            aggregate_failures "testing response" do
              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response['name']).to eq(saml_group_name)
              expect(json_response['access_level']).to eq(::Gitlab::Access::GUEST)
              expect(json_response['provider']).to be_nil
            end
          end
        end
      end
    end

    context "when licensed feature is not available" do
      let(:current_user) { owner }

      it "returns authentication error" do
        subject

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_saml_group_link do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      let(:user) { owner }
      let(:boundary_object) { group_with_saml_group_links }
      let(:request) { get api("/groups/#{group_id}/saml_group_links/#{saml_group_name}", personal_access_token: pat) }
    end
  end

  describe "DELETE /groups/:id/saml_group_links/:saml_group_name" do
    let_it_be(:saml_group_name) { "saml-group1" }

    subject { delete api("/groups/#{group_id}/saml_group_links/#{saml_group_name}", current_user) }

    context "when licensed feature is available" do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      context "when unauthorized" do
        it "returns unauthorized error" do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when a less privileged user" do
        let(:current_user) { user }

        it "does not remove the SAML group link" do
          expect do
            subject
          end.not_to change { group_with_saml_group_links.saml_group_links.count }

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when owner of the group" do
        let(:current_user) { owner }

        it "removes saml group link" do
          expect do
            subject

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { group_with_saml_group_links.saml_group_links.count }.by(-1)
        end

        context "when invalid group name is passed" do
          let(:saml_group_name) { "saml-group1356" }

          it "returns 404 if SAML group can not used for a SAML group link" do
            expect do
              subject
            end.not_to change { group_with_saml_group_links.saml_group_links.count }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context "when multiple links exist with same group name but different providers" do
          let(:current_user) { owner }

          let_it_be(:group_with_multiple_delete_links) { create(:group) }
          let_it_be(:saml_provider_for_delete) do
            create(:saml_provider, group: group_with_multiple_delete_links, enabled: true)
          end

          let_it_be(:group_id) { group_with_multiple_delete_links.id }
          let_it_be(:saml_group_name) { "delete-shared-group-name" }

          before do
            group_with_multiple_delete_links.saml_group_links.create!(
              saml_group_name: "delete-shared-group-name",
              access_level: ::Gitlab::Access::GUEST,
              provider: "provider1"
            )
            group_with_multiple_delete_links.saml_group_links.create!(
              saml_group_name: "delete-shared-group-name",
              access_level: ::Gitlab::Access::DEVELOPER,
              provider: "provider2"
            )
            group_with_multiple_delete_links.saml_group_links.create!(
              saml_group_name: "delete-shared-group-name",
              access_level: ::Gitlab::Access::MAINTAINER,
              provider: nil
            )
            group_with_multiple_delete_links.add_owner(owner)
          end

          it "returns error when multiple links exist without provider parameter" do
            expect do
              subject
            end.not_to change { group_with_multiple_delete_links.saml_group_links.count }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include(
              'Multiple group links found with the same name. Please specify a provider parameter to disambiguate.'
            )
          end

          context "when provider parameter is specified" do
            subject do
              delete api("/groups/#{group_id}/saml_group_links/#{saml_group_name}?provider=provider2", current_user)
            end

            it "deletes the specific link for the provider" do
              expect do
                subject

                expect(response).to have_gitlab_http_status(:no_content)
              end.to change { group_with_multiple_delete_links.saml_group_links.count }.by(-1)

              remaining_links = group_with_multiple_delete_links.saml_group_links.where(
                saml_group_name: saml_group_name)
              expect(remaining_links.pluck(:provider)).to match_array(['provider1', nil])
            end
          end

          context "when provider parameter is empty string" do
            subject { delete api("/groups/#{group_id}/saml_group_links/#{saml_group_name}?provider=", current_user) }

            it "deletes the link with nil provider" do
              expect do
                subject

                expect(response).to have_gitlab_http_status(:no_content)
              end.to change { group_with_multiple_delete_links.saml_group_links.count }.by(-1)

              remaining_links = group_with_multiple_delete_links.saml_group_links.where(
                saml_group_name: saml_group_name)
              expect(remaining_links.pluck(:provider)).to match_array(%w[provider1 provider2])
            end
          end

          context "when provider parameter is whitespace-only" do
            subject do
              delete api("/groups/#{group_id}/saml_group_links/#{saml_group_name}?provider=%20%20%20", current_user)
            end

            it "deletes the link with nil provider" do
              expect do
                subject

                expect(response).to have_gitlab_http_status(:no_content)
              end.to change { group_with_multiple_delete_links.saml_group_links.count }.by(-1)

              remaining_links = group_with_multiple_delete_links.saml_group_links.where(
                saml_group_name: saml_group_name)
              expect(remaining_links.pluck(:provider)).to match_array(%w[provider1 provider2])
            end
          end
        end

        context "when group link contains a period" do
          let_it_be(:saml_group_name) { "saml-group-with.period" }

          before do
            group_with_saml_group_links.saml_group_links.create!(saml_group_name: saml_group_name,
              access_level: ::Gitlab::Access::GUEST)
          end

          it "removes saml group link" do
            expect do
              subject

              expect(response).to have_gitlab_http_status(:no_content)
            end.to change { group_with_saml_group_links.saml_group_links.count }.by(-1)
          end
        end
      end
    end

    context "when licensed feature is not available" do
      let(:current_user) { owner }

      it "returns authentication error" do
        subject

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :delete_saml_group_link do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
      end

      let(:user) { owner }
      let(:boundary_object) { group_with_saml_group_links }
      let(:request) do
        delete api("/groups/#{group_id}/saml_group_links/#{saml_group_name}", personal_access_token: pat)
      end
    end
  end
end
