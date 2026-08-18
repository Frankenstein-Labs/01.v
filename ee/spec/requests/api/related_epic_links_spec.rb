# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::RelatedEpicLinks, feature_category: :portfolio_management do
  include ExternalAuthorizationServiceHelpers

  shared_examples 'related epics API' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :private) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:source_group) { create(:group, :public) }
    let_it_be(:target_group) { create(:group, :public) }
    let_it_be(:source_epic) { create(:epic, group: source_group) }
    let_it_be(:target_epic) { create(:epic, group: target_group) }

    before do
      stub_licensed_features(epics: true, related_epics: true)
    end

    shared_examples 'forbidden resource' do |message|
      it 'returns 403' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    shared_examples 'not found resource' do |message|
      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq(message)
      end
    end

    shared_examples 'unauthenticated resource' do
      it 'returns 401' do
        perform_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    shared_examples 'successful response' do |status|
      it "returns #{status}" do
        subject

        expect_link_response(status: status)
      end
    end

    shared_examples 'endpoint with features check' do
      context 'when epics feature is not available' do
        before do
          stub_licensed_features(epics: false, related_epics: true)
        end

        it { is_expected.to eq(403) }
      end

      context 'when related_epics feature is not available' do
        before do
          stub_licensed_features(epics: true, related_epics: false)
        end

        it { is_expected.to eq(403) }
      end
    end

    describe 'GET /groups/:id/related_epic_links' do
      let_it_be(:created_at) { Date.new(2021, 10, 14) }
      let_it_be(:updated_at) { Date.new(2021, 10, 14) }
      let_it_be_with_reload(:group_2) { create(:group, :private) }

      let_it_be(:related_epic_link_1) do
        create(
          :related_epic_link,
          source: epic,
          target: create(:epic, group: group),
          created_at: created_at,
          updated_at: updated_at
        )
      end

      let_it_be(:related_epic_link_2) do
        create(
          :related_epic_link,
          source: epic,
          target: create(:epic, group: group_2),
          created_at: created_at,
          updated_at: updated_at
        )
      end

      def perform_request(user = nil, params = {})
        get api("/groups/#{group.id}/related_epic_links", user), params: params
      end

      subject { perform_request(user) }

      context 'when user has no access to the group' do
        it 'returns 404' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when epics are public' do
        before do
          group.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
        end

        it 'returns related epic links' do
          perform_request(user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.length).to eq(1)
          expect(json_response.pluck("id")).to match_array([related_epic_link_1.id])
          expect(response).to match_response_schema('public_api/v4/related_epic_links', dir: 'ee')
        end
      end

      context 'when user has access to the group' do
        before do
          group.add_guest(user)
        end

        it_behaves_like 'endpoint with features check'

        it_behaves_like 'authorizing granular token permissions', :read_related_epic_link do
          let(:boundary_object) { group }
          let(:request) { get api("/groups/#{group.id}/related_epic_links", personal_access_token: pat) }
        end

        it 'returns only related epics links the user has access to' do
          perform_request(user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.length).to eq(1)
          expect(json_response.pluck("id")).to match_array([related_epic_link_1.id])
          expect(json_response[0]['source_epic']['id']).to eq(related_epic_link_1.source.id)
          expect(json_response[0]['target_epic']['id']).to eq(related_epic_link_1.target.id)
          expect(response).to match_response_schema('public_api/v4/related_epic_links', dir: 'ee')
        end

        context 'when related links reference confidential epics the user cannot read' do
          let_it_be(:confidential_epic) { create(:epic, :confidential, group: group) }
          let_it_be(:confidential_link) { create(:related_epic_link, source: epic, target: confidential_epic) }

          it 'excludes confidential links from the response' do
            perform_request(user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.pluck('id')).not_to include(confidential_link.id)
          end

          context 'for anonymous user' do
            let_it_be_with_reload(:group) { create(:group, :public) }
            let_it_be(:confidential_epic) { create(:epic, :confidential, group: group) }
            let_it_be(:epic) { create(:epic, group: group) }
            let_it_be(:confidential_link) { create(:related_epic_link, source: epic, target: confidential_epic) }

            it 'returns empty response' do
              perform_request

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).to eq([])
            end
          end
        end

        context 'when filtered by updated_before' do
          it 'returns related epic links updated before the given parameter' do
            perform_request(user, { updated_before: '2021-10-15=T00:00:00.000Z' })

            expect(json_response[0]['id']).to eq(related_epic_link_1.id)
          end

          it 'returns no related epic links' do
            perform_request(user, { updated_before: '2021-10-13=T00:00:00.000Z' })

            expect(json_response.length).to eq(0)
          end
        end

        context 'when filtered by updated_after' do
          it 'returns related epic links updated before the given parameter' do
            perform_request(user, { updated_after: '2021-10-14=T00:00:00.000Z' })

            expect(json_response[0]['id']).to eq(related_epic_link_1.id)
          end

          it 'returns no related epic links' do
            perform_request(user, { updated_after: '2021-10-15=T00:00:00.000Z' })

            expect(json_response.length).to eq(0)
          end
        end

        context 'when filtered by created_after' do
          it 'returns related epic links created after the given parameter' do
            perform_request(user, { created_after: '2021-10-14=T00:00:00.000Z' })

            expect(json_response[0]['id']).to eq(related_epic_link_1.id)
          end

          it 'returns no related epic links' do
            perform_request(user, { created_after: '2021-10-15=T00:00:00.000Z' })

            expect(json_response.length).to eq(0)
          end
        end

        context 'when filtered by created_before' do
          it 'returns related epic links created before the given parameter' do
            perform_request(user, { created_before: '2021-10-15=T00:00:00.000Z' })

            expect(json_response[0]['id']).to eq(related_epic_link_1.id)
          end

          it 'returns no related epic links' do
            perform_request(user, { created_before: '2021-10-13=T00:00:00.000Z' })

            expect(json_response.length).to eq(0)
          end
        end

        context 'when epics links are in a sub-group' do
          let_it_be(:sub_group) { create(:group, :private, parent: group) }
          let_it_be(:related_sub_epic_link) { create(:related_epic_link, source: create(:epic, group: sub_group), target: create(:epic, group: sub_group)) }

          it 'returns linked epic from sub-group' do
            perform_request(user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_an Array
            expect(json_response.length).to eq(2)
          end
        end
      end

      context 'when user has access to both groups' do
        before do
          group.add_guest(user)
          group_2.add_guest(user)
        end

        it 'returns related epic links' do
          perform_request(user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.length).to eq(2)
          expect(response).to match_response_schema('public_api/v4/related_epic_links', dir: 'ee')
        end

        it 'returns multiple links without N + 1' do
          perform_request(user)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { perform_request(user) }

          create(:related_epic_link, source: epic, target: create(:epic, group: group))

          expect { perform_request(user) }.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with pagination' do
        let_it_be(:target_epic) { create(:epic, group: group) }
        let_it_be(:related_epic_link_3) { create(:related_epic_link, source: epic, target: target_epic) }

        before do
          group.add_guest(user)
          group_2.add_guest(user)
        end

        it 'returns first page of related epics' do
          perform_request(user, { per_page: 2, page: 1 })

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.length).to eq(2)
          expect(json_response.pluck("id")).to match_array([related_epic_link_1.id, related_epic_link_2.id])
        end

        it 'returns the last page of related epics' do
          perform_request(user, { per_page: 2, page: 2 })

          expect(json_response.length).to eq(1)
          expect(json_response.pluck("id")).to match_array([related_epic_link_3.id])
        end
      end
    end

    describe 'GET /groups/:id/epics/:epic_id/related_epics' do
      def perform_request(user = nil, params = {})
        get api("/groups/#{group.id}/epics/#{epic.iid}/related_epics", user), params: params
      end

      subject { perform_request(user) }

      context 'when user cannot read epics' do
        it 'returns 404' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when user can read epics' do
        let_it_be(:group_2) { create(:group) }
        let_it_be(:related_epic_link_1) { create(:related_epic_link, source: epic, target: create(:epic, group: group)) }
        let_it_be(:related_epic_link_2) { create(:related_epic_link, source: epic, target: create(:epic, group: group_2)) }

        before do
          group.add_guest(user)
        end

        it_behaves_like 'endpoint with features check'

        it_behaves_like 'authorizing granular token permissions', :read_related_epic_link do
          let(:boundary_object) { group }
          let(:request) { get api("/groups/#{group.id}/epics/#{epic.iid}/related_epics", personal_access_token: pat) }
        end

        it 'returns related epics' do
          perform_request(user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.length).to eq(2)
          expect(response).to match_response_schema('public_api/v4/related_epics', dir: 'ee')
          expect(json_response.pluck("related_epic_link_id")).to match_array([related_epic_link_1.id, related_epic_link_2.id])
        end

        it 'returns multiple links without N + 1' do
          perform_request(user)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { perform_request(user) }

          create(:related_epic_link, source: epic, target: create(:epic, group: group))

          expect { perform_request(user) }.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    describe 'POST /groups/:id/epics/:epic_id/related_epics' do
      let(:target_epic_iid) { target_epic.iid }

      subject { perform_request(user, target_group_id: target_group.id, target_epic_iid: target_epic_iid) }

      def perform_request(user = nil, params = {})
        post api("/groups/#{source_group.id}/epics/#{source_epic.iid}/related_epics", user), params: params
      end

      it_behaves_like 'unauthenticated resource'

      context 'when user can not access source epic' do
        # user is not a member of the public source group
        it_behaves_like 'forbidden resource'
      end

      context 'when user can access source epic' do
        before do
          source_group.add_guest(user)
        end

        context 'when user cannot access target epic' do
          context 'when group is private' do
            let(:target_group) { group }

            # user is not a member of the private target group
            it_behaves_like 'not found resource', '404 Group Not Found'
          end

          context 'when group is public' do
            # user is not a member of the public target group
            it_behaves_like 'forbidden resource'
          end
        end

        context 'when user can access target epic group' do
          before do
            target_group.add_guest(user)
          end

          it_behaves_like 'successful response', :created
          it_behaves_like 'endpoint with features check'

          it_behaves_like 'authorizing granular token permissions', :create_related_epic_link do
            let(:boundary_object) { source_group }
            let(:request) { post api("/groups/#{source_group.id}/epics/#{source_epic.iid}/related_epics", personal_access_token: pat), params: { target_group_id: target_group.id, target_epic_iid: target_epic.iid } }
          end

          it 'returns 201 when sending full path of target group' do
            perform_request(user, target_group_id: target_group.full_path, target_epic_iid: target_epic.iid, link_type: 'blocks')

            expect_link_response(link_type: 'blocks')
            expect(json_response['source_epic']['id']).to eq(source_epic.id)
            expect(json_response['target_epic']['id']).to eq(target_epic.id)
          end

          it 'returns 201 status for is_blocked_by link and contains the expected link response' do
            perform_request(user, target_group_id: target_group.full_path, target_epic_iid: target_epic.iid, link_type: 'is_blocked_by')

            # For `is_blocked_by` we swap the source and target and use `block` as type.
            expect_link_response(link_type: 'blocks')
            expect(json_response['source_epic']['id']).to eq(target_epic.id)
            expect(json_response['target_epic']['id']).to eq(source_epic.id)
          end

          context 'when target epic is confidential' do
            let(:target_epic) { create(:epic, :confidential, group: target_group) }

            it_behaves_like 'forbidden resource'
          end

          context 'when target epic is not found' do
            let(:target_epic_iid) { non_existing_record_iid }

            it_behaves_like 'not found resource', '404 Not found'
          end
        end
      end
    end

    describe 'DELETE /groups/:id/epics/:epic_id/related_epics' do
      let_it_be(:related_epic_link) { create(:related_epic_link, source: source_epic, target: target_epic) }

      subject { perform_request(user) }

      def perform_request(user = nil, link_id = related_epic_link.id)
        delete api("/groups/#{source_group.id}/epics/#{source_epic.iid}/related_epics/#{link_id}", user)
      end

      it_behaves_like 'unauthenticated resource'

      context 'when user can not access source epic' do
        it_behaves_like 'forbidden resource'
      end

      context 'when user can access source epic' do
        before do
          source_group.add_guest(user)
          target_group.add_guest(user)
        end

        context 'when target group is private' do
          let(:related_epic_link) do
            create(:related_epic_link, source: source_epic, target: create(:epic, group: group))
          end

          it_behaves_like 'not found resource', 'No Related Epic Link found'
        end

        context 'when user can access target group' do
          it_behaves_like 'successful response', :ok
          it_behaves_like 'endpoint with features check'

          it_behaves_like 'authorizing granular token permissions', :delete_related_epic_link do
            let(:boundary_object) { source_group }
            let(:request) { delete api("/groups/#{source_group.id}/epics/#{source_epic.iid}/related_epics/#{related_epic_link.id}", personal_access_token: pat) }
          end

          context 'when related_epic_link_id belongs to a different epic' do
            let_it_be(:other_epic) { create(:epic, group: target_group) }
            let_it_be(:other_epic_link) { create(:related_epic_link, source: other_epic, target: target_epic) }

            subject do
              perform_request(user, other_epic_link.id)
            end

            it_behaves_like 'not found resource', '404 Not found'
          end
        end
      end
    end

    def expect_link_response(link_type: 'relates_to', status: :created)
      expect(response).to have_gitlab_http_status(status)
      expect(response).to match_response_schema('public_api/v4/related_epic_link')
      expect(json_response['link_type']).to eq(link_type)
    end
  end

  it_behaves_like 'related epics API'

  describe 'N+1 query performance' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:other_group) { create(:group, :private) }
    let_it_be(:epic) { create(:epic, group: group) }

    before do
      stub_licensed_features(epics: true, related_epics: true)
      group.add_guest(user)
      other_group.add_guest(user)
    end

    it 'does not have N+1 queries when adding more links, including cross-group private links' do
      create(:related_epic_link, source: epic, target: create(:epic, group: group))
      create(:related_epic_link, source: epic, target: create(:epic, group: other_group))

      get api("/groups/#{group.id}/related_epic_links", user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        get api("/groups/#{group.id}/related_epic_links", user)
      end

      create(:related_epic_link, source: epic, target: create(:epic, group: group))
      create(:related_epic_link, source: epic, target: create(:epic, group: other_group))

      expect { get api("/groups/#{group.id}/related_epic_links", user) }
        .not_to exceed_query_limit(control).allow_skip_cache_inconsistency
    end

    it 'does not have N+1 queries when serializing links with labels, author, and parent' do
      parent_epic = create(:epic, group: group)
      child_epic = create(:epic, group: group)
      child_epic.work_item.update!(work_item_parent: parent_epic.work_item)
      child_epic.work_item.labels << create(:group_label, group: group)
      create(:related_epic_link, source: epic, target: child_epic)

      get api("/groups/#{group.id}/related_epic_links", user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        get api("/groups/#{group.id}/related_epic_links", user)
      end

      parent_epic2 = create(:epic, group: group)
      child_epic2 = create(:epic, group: group)
      child_epic2.work_item.update!(work_item_parent: parent_epic2.work_item)
      child_epic2.work_item.labels << create(:group_label, group: group)
      create(:related_epic_link, source: epic, target: child_epic2)

      expect { get api("/groups/#{group.id}/related_epic_links", user) }
        .not_to exceed_query_limit(control).allow_skip_cache_inconsistency
    end
  end

  describe 'permission filtering with confidential epics' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:confidential_epic) { create(:epic, :confidential, group: group) }
    let_it_be(:related_link) { create(:related_epic_link, source: epic, target: confidential_epic) }

    before do
      stub_licensed_features(epics: true, related_epics: true)
      group.add_guest(user)
    end

    it 'excludes links to confidential epics the user cannot read' do
      get api("/groups/#{group.id}/related_epic_links", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_an(Array)
      expect(json_response.pluck('id')).not_to include(related_link.id)
    end
  end
end
