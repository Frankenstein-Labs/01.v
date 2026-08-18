# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::AuditEvents, :aggregate_failures, feature_category: :audit_events do
  describe 'Unique usage tracking', :clean_gitlab_redis_shared_state do
    let_it_be(:current_user) { create(:admin) }
    let_it_be(:group) { create(:group, owner_id: current_user) }
    let_it_be(:project) { create(:project) }

    before do
      project.add_member(current_user, :maintainer)
    end

    context 'after calling all audit_events APIs as a single licensed user', :enable_admin_mode do
      before do
        stub_licensed_features(admin_audit_log: true)
      end

      subject do
        travel_to 8.days.ago do
          get api('/audit_events', current_user)
          get api("/groups/#{group.id}/audit_events", current_user)
          get api("/projects/#{project.id}/audit_events", current_user)
        end
      end

      it 'tracks 3 separate events' do
        expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).exactly(3).times
                                                                                   .with('a_compliance_audit_events_api', values: current_user.id)
        # user activity tracking is also recorded
        expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
                                                                .with('unique_active_user', values: current_user.id)
        subject
      end

      it 'reports one unique event' do
        subject

        expect(Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names: 'a_compliance_audit_events_api', start_date: 2.months.ago, end_date: Date.current)).to eq(1)
      end
    end
  end

  describe 'GET /audit_events' do
    let(:url) { "/audit_events" }

    context 'when authenticated, as a user' do
      let(:user) { create(:user) }

      it_behaves_like '403 response' do
        let(:request) { get api(url, user) }
      end
    end

    context 'when authenticated, as an admin' do
      let_it_be(:admin) { create(:admin) }

      context 'audit events feature is not available' do
        it_behaves_like '403 response' do
          let(:request) { get api(url, admin, admin_mode: true) }
        end
      end

      context 'audit events feature is available' do
        before do
          stub_licensed_features(admin_audit_log: true)
        end

        it_behaves_like 'GET request permissions for admin mode' do
          let(:path) { url }
        end

        it_behaves_like 'authorizing granular token permissions', :read_audit_event do
          let(:boundary_object) { :instance }
          let(:user) { admin }
          let(:request) { get api(url, personal_access_token: pat) }
        end

        let_it_be(:new_project_audit_event2) do
          create(:audit_events_project_audit_event, created_at: Time.zone.parse('2024-01-15 05:00:00'))
        end

        let_it_be(:new_group_audit_event2) do
          create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 06:00:00'))
        end

        let_it_be(:new_project_audit_event1) do
          create(:audit_events_project_audit_event, created_at: Time.zone.parse('2024-01-15 07:00:00'))
        end

        let_it_be(:new_group_audit_event1) do
          create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 08:00:00'))
        end

        let_it_be(:new_user_audit_event) do
          create(:audit_events_user_audit_event, created_at: Time.zone.parse('2024-01-15 09:00:00'))
        end

        let_it_be(:instance_audit_event) do
          create(:audit_events_instance_audit_event, created_at: Time.zone.parse('2024-01-15 10:00:00'))
        end

        context 'parameters' do
          context 'entity_id parameter' do
            context 'requires entity_type parameter to be present' do
              it_behaves_like '400 response' do
                let(:request) { get api(url, admin, admin_mode: true), params: { entity_id: 1 } }
              end
            end
          end
        end

        describe 'basic functionality' do
          it 'returns 200 response' do
            get api(url, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'returns all audit events in descending order by default' do
            get api(url, admin, admin_mode: true)

            expected_order = [
              instance_audit_event.id,
              new_user_audit_event.id,
              new_group_audit_event1.id,
              new_project_audit_event1.id,
              new_group_audit_event2.id,
              new_project_audit_event2.id
            ]

            expect(json_response.pluck('id')).to eq(expected_order)
          end
        end

        describe 'pagination' do
          context 'when using cursor pagination' do
            it 'paginates correctly through all pages' do
              get api(url, admin, admin_mode: true), params: { per_page: 2, pagination: 'keyset' }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(2)
              expected_page1 = [instance_audit_event.id, new_user_audit_event.id]
              expect(json_response.pluck('id')).to eq(expected_page1)

              expect(response.headers['Link']).to be_present
              expect(response.headers['Link']).to include('rel="next"')

              link_header = response.headers['Link']
              cursor_match = link_header.match(/cursor=([^&>]+)/)
              cursor = CGI.unescape(cursor_match[1])

              get api(url, admin, admin_mode: true), params: { cursor: cursor, per_page: 2, pagination: 'keyset' }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(2)
              expected_page2 = [new_group_audit_event1.id, new_project_audit_event1.id]
              expect(json_response.pluck('id')).to eq(expected_page2)

              expect(response.headers['Link']).to be_present
              link_header = response.headers['Link']
              cursor_match = link_header.match(/cursor=([^&>]+)/)
              cursor = CGI.unescape(cursor_match[1])

              get api(url, admin, admin_mode: true), params: { cursor: cursor, per_page: 2, pagination: 'keyset' }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(2)
              expected_page3 = [new_group_audit_event2.id, new_project_audit_event2.id]
              expect(json_response.pluck('id')).to eq(expected_page3)

              expect(response.headers['Link']).to be_nil
            end
          end

          context 'when using offset pagination' do
            describe 'basic functionality' do
              it 'returns all audit events sorted by id descending' do
                get api(url, admin, admin_mode: true), params: { pagination: 'offset' }

                # Offset pagination sorts by id DESC for performance
                all_events = [
                  instance_audit_event,
                  new_user_audit_event,
                  new_group_audit_event1,
                  new_project_audit_event1,
                  new_group_audit_event2,
                  new_project_audit_event2
                ].sort_by { |e| -e.id }

                expect(json_response.pluck('id')).to eq(all_events.map(&:id))
              end

              it 'defaults to offset pagination when pagination param is not provided' do
                get api(url, admin, admin_mode: true)

                expect(response.headers['X-Page']).to eq('1')
                expect(response.headers['X-Per-Page']).to be_present
                expect(response.headers).not_to have_key('X-Total')
                expect(response.headers).not_to have_key('X-Total-Pages')
              end
            end

            describe 'pagination headers' do
              context 'when on first page' do
                it 'includes correct pagination headers' do
                  get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 1, per_page: 2 }

                  expect(response.headers['X-Page']).to eq('1')
                  expect(response.headers['X-Per-Page']).to eq('2')
                  expect(response.headers['X-Next-Page']).to eq('2')
                  expect(response.headers['X-Prev-Page']).to eq("")

                  link_header = response.headers['Link']
                  expect(link_header).to include('rel="next"')
                  expect(link_header).to include('rel="first"')
                  expect(link_header).not_to include('rel="prev"')
                  expect(link_header).not_to include('rel="last"')
                end
              end

              context 'when on middle page' do
                it 'includes correct pagination headers' do
                  get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 2, per_page: 2 }

                  expect(response.headers['X-Page']).to eq('2')
                  expect(response.headers['X-Per-Page']).to eq('2')
                  expect(response.headers['X-Next-Page']).to eq('3')
                  expect(response.headers['X-Prev-Page']).to eq('1')

                  link_header = response.headers['Link']
                  expect(link_header).to include('rel="next"')
                  expect(link_header).to include('rel="prev"')
                  expect(link_header).to include('rel="first"')
                  expect(link_header).not_to include('rel="last"')
                end
              end

              context 'when on last page' do
                it 'includes correct pagination headers' do
                  get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 3, per_page: 2 }

                  expect(response.headers['X-Page']).to eq('3')
                  expect(response.headers['X-Per-Page']).to eq('2')
                  expect(response.headers['X-Next-Page']).to eq('4')
                  expect(response.headers['X-Prev-Page']).to eq('2')

                  link_header = response.headers['Link']
                  expect(link_header).to include('rel="next"')
                  expect(link_header).to include('rel="prev"')
                  expect(link_header).to include('rel="first"')
                  expect(link_header).not_to include('rel="last"')
                end
              end

              context 'when page is beyond available data' do
                it 'returns empty results with correct headers' do
                  get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 10, per_page: 20 }

                  expect(json_response).to be_empty
                  expect(response.headers['X-Page']).to eq('10')
                  expect(response.headers['X-Per-Page']).to eq('20')
                  expect(response.headers['X-Next-Page']).to eq("")
                  expect(response.headers['X-Prev-Page']).to eq('9')
                end
              end

              context 'without total count' do
                it 'does not include total count headers' do
                  get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 1, per_page: 2 }

                  expect(response.headers).not_to have_key('X-Total')
                  expect(response.headers).not_to have_key('X-Total-Pages')

                  link_header = response.headers['Link']
                  expect(link_header).not_to include('rel="last"')
                end
              end
            end

            describe 'pagination functionality' do
              it 'paginates correctly through all pages' do
                all_events = [
                  instance_audit_event,
                  new_user_audit_event,
                  new_group_audit_event1,
                  new_project_audit_event1,
                  new_group_audit_event2,
                  new_project_audit_event2
                ].sort_by { |e| -e.id }

                get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 1, per_page: 2 }
                expect(json_response.pluck('id')).to eq(all_events[0..1].map(&:id))

                get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 2, per_page: 2 }
                expect(json_response.pluck('id')).to eq(all_events[2..3].map(&:id))

                get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 3, per_page: 2 }
                expect(json_response.pluck('id')).to eq(all_events[4..5].map(&:id))

                get api(url, admin, admin_mode: true), params: { pagination: 'offset', page: 4, per_page: 2 }
                expect(json_response).to be_empty
              end

              it 'preserves filter parameters in pagination links' do
                get api(url, admin, admin_mode: true), params: {
                  pagination: 'offset',
                  page: 1,
                  per_page: 1,
                  entity_type: 'Group',
                  created_after: '2024-01-15T05:00:00Z'
                }

                link_header = response.headers['Link']
                expect(link_header).to include('entity_type=Group')
                expect(link_header).to include('pagination=offset')
                expect(link_header).to include('per_page=1')
                expect(link_header).to include('created_after=')
              end
            end

            describe 'filtering with offset pagination' do
              context 'when filtering by entity type' do
                it 'returns only group events with correct pagination' do
                  get api(url, admin, admin_mode: true), params: {
                    pagination: 'offset',
                    entity_type: 'Group',
                    page: 1,
                    per_page: 1
                  }

                  group_events = [new_group_audit_event1, new_group_audit_event2].sort_by { |e| -e.id }

                  expect(json_response.pluck('id')).to eq([group_events[0].id])
                  expect(response.headers['X-Next-Page']).to eq('2')

                  get api(url, admin, admin_mode: true), params: {
                    pagination: 'offset',
                    entity_type: 'Group',
                    page: 2,
                    per_page: 1
                  }

                  expect(json_response.pluck('id')).to eq([group_events[1].id])
                  expect(response.headers['X-Next-Page']).to eq('3')
                  expect(response.headers['X-Prev-Page']).to eq('1')
                end
              end

              context 'when filtering by date range' do
                it 'returns events within date range with pagination' do
                  get api(url, admin, admin_mode: true), params: {
                    pagination: 'offset',
                    created_after: Time.zone.parse('2024-01-15 07:00:00'),
                    created_before: Time.zone.parse('2024-01-15 09:00:00'),
                    page: 1,
                    per_page: 2
                  }

                  filtered_events = [
                    new_user_audit_event,
                    new_group_audit_event1,
                    new_project_audit_event1
                  ].sort_by { |e| -e.id }

                  expect(json_response.pluck('id')).to eq(filtered_events[0..1].map(&:id))
                  expect(response.headers['X-Next-Page']).to eq('2')

                  link_header = response.headers['Link']
                  expect(link_header).to include('created_after=')
                  expect(link_header).to include('created_before=')
                end
              end

              context 'with combined filters' do
                it 'applies all filters correctly with pagination' do
                  get api(url, admin, admin_mode: true), params: {
                    pagination: 'offset',
                    entity_type: 'Project',
                    created_after: Time.zone.parse('2024-01-15 06:00:00'),
                    page: 1,
                    per_page: 1
                  }

                  expect(json_response.size).to eq(1)
                  expect(json_response.first['entity_type']).to eq('Project')

                  link_header = response.headers['Link']
                  expect(link_header).to include('entity_type=Project')
                  expect(link_header).to include('created_after=')
                  expect(link_header).to include('pagination=offset')
                end
              end
            end

            describe 'comparison with keyset pagination' do
              it 'returns same records but in same order' do
                get api(url, admin, admin_mode: true), params: {
                  pagination: 'keyset',
                  per_page: 10
                }
                keyset_ids = json_response.pluck('id')

                get api(url, admin, admin_mode: true), params: {
                  pagination: 'offset',
                  per_page: 10
                }
                offset_ids = json_response.pluck('id')

                expect(offset_ids).to eq(keyset_ids)
              end
            end

            describe 'sort parameter' do
              it 'supports created_asc which sorts by id ASC' do
                get api(url, admin, admin_mode: true), params: {
                  pagination: 'offset',
                  sort: 'created_asc',
                  per_page: 10
                }

                all_events = [
                  instance_audit_event,
                  new_user_audit_event,
                  new_group_audit_event1,
                  new_project_audit_event1,
                  new_group_audit_event2,
                  new_project_audit_event2
                ].sort_by(&:id) # ASC order

                expect(json_response.pluck('id')).to eq(all_events.map(&:id))
              end

              it 'defaults to created_desc which sorts by id DESC' do
                get api(url, admin, admin_mode: true), params: {
                  pagination: 'offset',
                  per_page: 10
                }

                all_events = [
                  instance_audit_event,
                  new_user_audit_event,
                  new_group_audit_event1,
                  new_project_audit_event1,
                  new_group_audit_event2,
                  new_project_audit_event2
                ].sort_by { |e| -e.id } # DESC order

                expect(json_response.pluck('id')).to eq(all_events.map(&:id))
              end
            end
          end
        end

        describe 'filtering' do
          context 'when filtering by entity type' do
            it 'returns only group events' do
              get api(url, admin, admin_mode: true), params: { entity_type: 'Group' }

              expected_group_ids = [new_group_audit_event1.id, new_group_audit_event2.id]
              expect(json_response.pluck('id')).to match_array(expected_group_ids)
              expect(json_response).to all(include('entity_type' => 'Group'))
            end

            it 'returns only project events' do
              get api(url, admin, admin_mode: true), params: { entity_type: 'Project' }

              expected_project_ids = [new_project_audit_event1.id, new_project_audit_event2.id]
              expect(json_response.pluck('id')).to match_array(expected_project_ids)
              expect(json_response).to all(include('entity_type' => 'Project'))
            end

            it 'returns only user events' do
              get api(url, admin, admin_mode: true), params: { entity_type: 'User' }

              expect(json_response.pluck('id')).to contain_exactly(new_user_audit_event.id)
              expect(json_response).to all(include('entity_type' => 'User'))
            end

            it 'returns only instance events' do
              get api(url, admin, admin_mode: true), params: { entity_type: 'Gitlab::Audit::InstanceScope' }

              expect(json_response.pluck('id')).to contain_exactly(instance_audit_event.id)
              expect(json_response).to all(include('entity_type' => 'Gitlab::Audit::InstanceScope'))
            end

            context 'with pagination' do
              it 'paginates filtered results correctly' do
                get api(url, admin, admin_mode: true), params: { entity_type: 'Group', per_page: 1, pagination: 'keyset' }

                expect(json_response.pluck('id')).to eq([new_group_audit_event1.id])
                expect(response.headers['Link']).to be_present

                link_header = response.headers['Link']
                cursor_match = link_header.match(/cursor=([^&>]+)/)
                cursor = CGI.unescape(cursor_match[1])

                get api(url, admin, admin_mode: true), params: { entity_type: 'Group', cursor: cursor, per_page: 1, pagination: 'keyset' }

                expect(json_response.pluck('id')).to eq([new_group_audit_event2.id])
                expect(response.headers['Link']).to be_nil
              end
            end
          end

          context 'when filtering by date range' do
            it 'returns events within date range' do
              get api(url, admin, admin_mode: true), params: {
                created_after: Time.zone.parse('2024-01-15 07:00:00'),
                created_before: Time.zone.parse('2024-01-15 09:00:00')
              }

              expected_date_range_ids = [
                new_user_audit_event.id,
                new_group_audit_event1.id,
                new_project_audit_event1.id
              ]
              expect(json_response.pluck('id')).to match_array(expected_date_range_ids)
            end
          end

          context 'when filtering by author' do
            let_it_be(:author) { create(:user) }
            let_it_be(:authored_event1) do
              create(:audit_events_project_audit_event,
                author_id: author.id,
                created_at: Time.zone.parse('2024-01-15 12:00:00'))
            end

            let_it_be(:authored_event2) do
              create(:audit_events_instance_audit_event,
                author_id: author.id,
                created_at: Time.zone.parse('2024-01-15 11:00:00'))
            end

            it 'returns events by specific author' do
              get api(url, admin, admin_mode: true), params: { author_id: author.id }

              expected_author_ids = [authored_event1.id, authored_event2.id]
              expect(json_response.pluck('id')).to match_array(expected_author_ids)
            end
          end

          context 'when filtering by entity_id' do
            it 'returns events for specific entity' do
              get api(url, admin, admin_mode: true), params: {
                entity_type: 'Group',
                entity_id: new_group_audit_event1.entity_id
              }

              expect(json_response.size).to eq(1)
              expect(json_response.first['id']).to eq(new_group_audit_event1.id)
            end
          end
        end

        describe 'edge cases' do
          it 'returns empty result when no events match filters' do
            get api(url, admin, admin_mode: true), params: {
              entity_type: 'User',
              pagination: 'keyset',
              created_before: Time.zone.parse('2024-01-15 04:00:00')
            }

            expect(json_response).to be_empty
            expect(response.headers['Link']).to be_nil
          end
        end

        describe 'attributes' do
          it 'exposes the right attributes' do
            get api(url, admin, admin_mode: true), params: { entity_type: 'Group' }

            response_item = json_response.first
            details = response_item['details']

            expect(response_item["id"]).to eq(new_group_audit_event1.id)
            expect(response_item["author_id"]).to eq(new_group_audit_event1.user.id)
            expect(response_item["entity_id"]).to eq(new_group_audit_event1.entity_id)
            expect(response_item["entity_type"]).to eq('Group')
            expect(Time.parse(response_item["created_at"])).to be_like_time(new_group_audit_event1.created_at)
            expect(details).to eq new_group_audit_event1.formatted_details.with_indifferent_access
          end
        end
      end
    end
  end

  describe 'GET /audit_events/:id' do
    let_it_be(:user_audit_event) do
      create(:audit_events_user_audit_event, created_at: Date.new(2000, 1, 10))
    end

    let(:url) { "/audit_events/#{user_audit_event.id}" }

    context 'when authenticated, as a user' do
      let(:user) { create(:user) }

      it_behaves_like '403 response' do
        let(:request) { get api(url, user) }
      end
    end

    context 'when authenticated, as an admin' do
      let(:admin) { create(:admin) }

      context 'audit events feature is not available' do
        it_behaves_like '403 response' do
          let(:request) { get api(url, admin, admin_mode: true) }
        end
      end

      context 'audit events feature is available' do
        let_it_be(:new_user_audit_event) { create(:audit_events_user_audit_event) }
        let_it_be(:new_project_audit_event) { create(:audit_events_project_audit_event) }
        let_it_be(:new_group_audit_event) { create(:audit_events_group_audit_event) }
        let_it_be(:new_instance_audit_event) { create(:audit_events_instance_audit_event) }

        before do
          stub_licensed_features(admin_audit_log: true)
        end

        it_behaves_like 'GET request permissions for admin mode' do
          let(:path) { url }
        end

        it_behaves_like 'authorizing granular token permissions', :read_audit_event do
          let(:boundary_object) { :instance }
          let(:user) { admin }
          let(:request) { get api(url, personal_access_token: pat) }
        end

        context 'audit event does not exist' do
          it_behaves_like '404 response' do
            let(:url) { "/audit_events/10001" }
            let(:request) { get api(url, admin, admin_mode: true) }
          end
        end

        describe '#find' do
          context 'when audit event exists' do
            context 'with instance audit event' do
              let(:url) { "/audit_events/#{new_instance_audit_event.id}" }

              it 'returns the correct audit event' do
                get api(url, admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response["id"]).to eq(new_instance_audit_event.id)
                expect(json_response["entity_type"]).to eq('Gitlab::Audit::InstanceScope')
              end
            end

            context 'with user audit event' do
              let(:url) { "/audit_events/#{new_user_audit_event.id}" }

              it 'returns the correct audit event' do
                get api(url, admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response["id"]).to eq(new_user_audit_event.id)
                expect(json_response["entity_type"]).to eq('User')
              end
            end

            context 'with group audit event' do
              let(:url) { "/audit_events/#{new_group_audit_event.id}" }

              it 'returns the correct audit event' do
                get api(url, admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response["id"]).to eq(new_group_audit_event.id)
                expect(json_response["entity_type"]).to eq('Group')
              end
            end

            context 'with project audit event' do
              let(:url) { "/audit_events/#{new_project_audit_event.id}" }

              it 'returns the correct audit event' do
                get api(url, admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response["id"]).to eq(new_project_audit_event.id)
                expect(json_response["entity_type"]).to eq('Project')
              end
            end
          end

          context 'when audit event does not exist' do
            let(:url) { "/audit_events/999999" }

            it 'raises ActiveRecord::RecordNotFound' do
              get api(url, admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end
        end

        describe 'attributes' do
          let(:url) { "/audit_events/#{new_group_audit_event.id}" }

          it 'exposes the right attributes' do
            get api(url, admin, admin_mode: true)
            details = json_response['details']

            expect(json_response["id"]).to eq(new_group_audit_event.id)
            expect(json_response["author_id"]).to eq(new_group_audit_event.user.id)
            expect(json_response["entity_id"]).to eq(new_group_audit_event.entity_id)
            expect(json_response["entity_type"]).to eq('Group')
            expect(Time.parse(json_response["created_at"])).to be_like_time(new_group_audit_event.created_at)
            expect(details).to eq new_group_audit_event.formatted_details.with_indifferent_access
          end
        end
      end
    end
  end
end
