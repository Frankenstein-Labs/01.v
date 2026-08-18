# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::CombinedAuditEventFinder, feature_category: :audit_events do
  let(:finder) { described_class.new(params: params) }
  let(:params) { { per_page: 20 } }

  let(:base_time) { Time.zone.parse('2024-01-15 12:00:00') }

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:author) { create(:user) }

  let_it_be(:instance_event1) do
    create(:audit_events_instance_audit_event, created_at: Time.zone.parse('2024-01-15 06:00:00'), author_id: author.id)
  end

  let_it_be(:user_event1) do
    create(:audit_events_user_audit_event, created_at: Time.zone.parse('2024-01-15 07:00:00'), user_id: user.id)
  end

  let_it_be(:group_event1) do
    create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 08:00:00'), group_id: group.id)
  end

  let_it_be(:project_event1) do
    create(:audit_events_project_audit_event, created_at: Time.zone.parse('2024-01-15 09:00:00'),
      project_id: project.id)
  end

  let_it_be(:group_event2) do
    create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 10:00:00'), group_id: group.id)
  end

  let_it_be(:project_event2) do
    create(:audit_events_project_audit_event,
      created_at: Time.zone.parse('2024-01-15 11:00:00'),
      project_id: project.id,
      author_id: author.id)
  end

  describe '#find' do
    subject(:find) { finder.find(id) }

    context 'when audit event exists' do
      context 'with instance audit event' do
        let(:id) { instance_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(instance_event1)
          expect(find).to be_a(AuditEvents::InstanceAuditEvent)
        end
      end

      context 'with user audit event' do
        let(:id) { user_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(user_event1)
          expect(find).to be_a(AuditEvents::UserAuditEvent)
        end
      end

      context 'with group audit event' do
        let(:id) { group_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(group_event1)
          expect(find).to be_a(AuditEvents::GroupAuditEvent)
        end
      end

      context 'with project audit event' do
        let(:id) { project_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(project_event1)
          expect(find).to be_a(AuditEvents::ProjectAuditEvent)
        end
      end
    end

    context 'when audit event does not exist' do
      let(:id) { non_existing_record_id }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { find }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#execute' do
    subject(:execute) { finder.execute }

    context 'when using keyset pagination' do
      let(:params) { { per_page: 20, pagination: 'keyset' } }

      context 'when testing basic functionality' do
        it 'returns all audit events in descending order by created_at' do
          result = execute

          expect(result[:records]).to eq([
            project_event2,
            group_event2,
            project_event1,
            group_event1,
            user_event1,
            instance_event1
          ])
        end

        it 'returns keyset pagination metadata' do
          result = execute

          expect(result).to have_key(:records)
          expect(result).to have_key(:cursor_for_next_page)
          expect(result[:records]).to be_an(Array)
        end
      end

      context 'when SimpleOrderBuilder returns failure' do
        before do
          allow(Gitlab::Pagination::Keyset::SimpleOrderBuilder)
            .to receive(:build)
                  .and_return([nil, false])
        end

        it 'raises an error' do
          expect { execute }
            .to raise_error(RuntimeError, 'Failed to build keyset ordering')
        end
      end

      context 'when using pagination' do
        let(:params) { { per_page: 1, pagination: 'keyset' } }

        it 'paginates correctly through all pages' do
          page1 = described_class.new(params: params).execute
          expect(page1[:records]).to eq([project_event2])
          expect(page1[:cursor_for_next_page]).to be_present

          page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
          expect(page2[:records]).to eq([group_event2])
          expect(page2[:cursor_for_next_page]).to be_present

          page3 = described_class.new(params: params.merge(cursor: page2[:cursor_for_next_page])).execute
          expect(page3[:records]).to eq([project_event1])
          expect(page3[:cursor_for_next_page]).to be_present

          page4 = described_class.new(params: params.merge(cursor: page3[:cursor_for_next_page])).execute
          expect(page4[:records]).to eq([group_event1])
          expect(page4[:cursor_for_next_page]).to be_present

          page5 = described_class.new(params: params.merge(cursor: page4[:cursor_for_next_page])).execute
          expect(page5[:records]).to eq([user_event1])
          expect(page5[:cursor_for_next_page]).to be_present

          page6 = described_class.new(params: params.merge(cursor: page5[:cursor_for_next_page])).execute
          expect(page6[:records]).to eq([instance_event1])
          expect(page6[:cursor_for_next_page]).to be_nil
        end
      end

      context 'when filtering records' do
        context 'when filtering by entity type' do
          let(:params) { { entity_type: 'Group', per_page: 20, pagination: 'keyset' } }

          it 'returns only group events in descending order' do
            result = execute

            expect(result[:records]).to eq([group_event2, group_event1])
            expect(result[:records]).to all(be_a(AuditEvents::GroupAuditEvent))
          end

          context 'with pagination' do
            let(:params) { { entity_type: 'Group', per_page: 1, pagination: 'keyset' } }

            it 'paginates filtered results correctly' do
              page1 = execute
              expect(page1[:records]).to eq([group_event2])
              expect(page1[:cursor_for_next_page]).to be_present

              page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
              expect(page2[:records]).to eq([group_event1])
              expect(page2[:cursor_for_next_page]).to be_nil
            end
          end

          context 'with project entity type' do
            let(:params) { { entity_type: 'Project', per_page: 20, pagination: 'keyset' } }

            it 'returns only project events' do
              result = execute

              expect(result[:records]).to eq([project_event2, project_event1])
              expect(result[:records]).to all(be_a(AuditEvents::ProjectAuditEvent))
            end
          end

          context 'with user entity type' do
            let(:params) { { entity_type: 'User', per_page: 20, pagination: 'keyset' } }

            it 'returns only user events' do
              result = execute

              expect(result[:records]).to eq([user_event1])
              expect(result[:records]).to all(be_a(AuditEvents::UserAuditEvent))
            end
          end

          context 'with instance entity type' do
            let(:params) { { entity_type: 'Gitlab::Audit::InstanceScope', per_page: 20, pagination: 'keyset' } }

            it 'returns only instance events' do
              result = execute

              expect(result[:records]).to eq([instance_event1])
              expect(result[:records]).to all(be_a(AuditEvents::InstanceAuditEvent))
            end
          end
        end

        context 'when filtering by entity_id' do
          context 'with valid entity_type and entity_id' do
            context 'for Group entity' do
              let(:params) { { entity_type: 'Group', entity_id: group.id, per_page: 20, pagination: 'keyset' } }

              it 'returns only events for the specific group' do
                result = execute

                expect(result[:records]).to eq([group_event2, group_event1])
                expect(result[:records]).to all(have_attributes(group_id: group.id))
              end
            end

            context 'for Project entity' do
              let(:params) { { entity_type: 'Project', entity_id: project.id, per_page: 20, pagination: 'keyset' } }

              it 'returns only events for the specific project' do
                result = execute

                expect(result[:records]).to eq([project_event2, project_event1])
                expect(result[:records]).to all(have_attributes(project_id: project.id))
              end
            end

            context 'for User entity' do
              let(:params) { { entity_type: 'User', entity_id: user.id, per_page: 20, pagination: 'keyset' } }

              it 'returns only events for the specific user' do
                result = execute

                expect(result[:records]).to eq([user_event1])
                expect(result[:records]).to all(have_attributes(user_id: user.id))
              end
            end

            context 'when entity_id does not exist' do
              let(:params) do
                { entity_type: 'Group', entity_id: non_existing_record_id, per_page: 20, pagination: 'keyset' }
              end

              it 'returns empty results' do
                result = execute

                expect(result[:records]).to be_empty
                expect(result[:cursor_for_next_page]).to be_nil
              end
            end
          end

          context 'when entity_id is provided without entity_type' do
            let(:params) { { entity_id: group.id, per_page: 20, pagination: 'keyset' } }

            it 'ignores entity_id and returns all events' do
              result = execute

              expect(result[:records]).to eq([
                project_event2,
                group_event2,
                project_event1,
                group_event1,
                user_event1,
                instance_event1
              ])
            end
          end
        end

        context 'when filtering by date range' do
          let(:params) do
            { created_after: Time.zone.parse('2024-01-15 09:00:00'),
              created_before: Time.zone.parse('2024-01-15 11:00:00'), per_page: 20, pagination: 'keyset' }
          end

          it 'returns events within date range in descending order' do
            result = execute

            expect(result[:records]).to eq([project_event2, group_event2, project_event1])
          end
        end

        context 'when filtering by author' do
          let(:params) { { author_id: author.id, per_page: 20, pagination: 'keyset' } }

          it 'returns events by specific author in descending order' do
            result = execute

            expect(result[:records]).to eq([project_event2, instance_event1])
          end
        end
      end

      context 'when using combined filters with pagination' do
        let_it_be(:another_group) { create(:group) }
        let_it_be(:another_project) { create(:project) }

        let_it_be(:another_group_event1) do
          create(:audit_events_group_audit_event,
            created_at: Time.zone.parse('2024-01-15 09:30:00'),
            group_id: another_group.id)
        end

        let_it_be(:another_group_event2) do
          create(:audit_events_group_audit_event,
            created_at: Time.zone.parse('2024-01-15 10:30:00'),
            group_id: another_group.id)
        end

        let_it_be(:another_project_event) do
          create(:audit_events_project_audit_event,
            created_at: Time.zone.parse('2024-01-15 09:45:00'),
            project_id: another_project.id,
            author_id: author.id)
        end

        context 'with entity_type and entity_id' do
          let(:params) { { entity_type: 'Group', entity_id: group.id, per_page: 1, pagination: 'keyset' } }

          it 'applies both entity type and entity_id filters with pagination correctly' do
            page1 = execute
            expect(page1[:records]).to eq([group_event2])
            expect(page1[:records].first.group_id).to eq(group.id)
            expect(page1[:cursor_for_next_page]).to be_present

            page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
            expect(page2[:records]).to eq([group_event1])
            expect(page2[:records].first.group_id).to eq(group.id)
            expect(page2[:cursor_for_next_page]).to be_nil

            all_pages = [page1[:records], page2[:records]].flatten
            expect(all_pages).not_to include(another_group_event1, another_group_event2)
          end
        end

        context 'with date range, entity type, and entity_id' do
          let(:params) do
            {
              entity_type: 'Project',
              entity_id: project.id,
              created_after: Time.zone.parse('2024-01-15 09:00:00'),
              per_page: 1,
              pagination: 'keyset'
            }
          end

          it 'applies all three filters correctly' do
            page1 = execute
            expect(page1[:records]).to eq([project_event2])
            expect(page1[:records].first.project_id).to eq(project.id)
            expect(page1[:cursor_for_next_page]).to be_present

            page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
            expect(page2[:records]).to eq([project_event1])
            expect(page2[:records].first.project_id).to eq(project.id)
            expect(page2[:cursor_for_next_page]).to be_nil

            expect(page1[:records]).not_to include(another_project_event)
            expect(page2[:records]).not_to include(another_project_event)
          end
        end

        context 'with author_id, entity_type, and entity_id' do
          let(:params) do
            {
              entity_type: 'Project',
              entity_id: project.id,
              author_id: author.id,
              per_page: 1,
              pagination: 'keyset'
            }
          end

          it 'filters by all criteria including author' do
            result = execute
            expect(result[:records]).to eq([project_event2])
            expect(result[:records].first).to have_attributes(
              project_id: project.id,
              author_id: author.id
            )
            expect(result[:cursor_for_next_page]).to be_nil

            expect(result[:records]).not_to include(project_event1)
          end
        end

        context 'with entity_id for non-existent entity' do
          let(:params) do
            {
              entity_type: 'Group',
              entity_id: non_existing_record_id,
              per_page: 2,
              pagination: 'keyset'
            }
          end

          it 'returns empty result when entity_id does not match any records' do
            result = execute

            expect(result[:records]).to be_empty
            expect(result[:cursor_for_next_page]).to be_nil
          end
        end

        context 'with all filters combined' do
          let(:params) do
            {
              entity_type: 'Group',
              entity_id: another_group.id,
              created_after: Time.zone.parse('2024-01-15 09:00:00'),
              created_before: Time.zone.parse('2024-01-15 10:00:00'),
              per_page: 1,
              pagination: 'keyset'
            }
          end

          it 'correctly applies all filters with pagination' do
            page1 = execute
            expect(page1[:records]).to eq([another_group_event1])
            expect(page1[:records].first.group_id).to eq(another_group.id)
            expect(page1[:cursor_for_next_page]).to be_nil

            expect(page1[:records]).not_to include(another_group_event2)
          end
        end

        it 'returns empty result when no events match all combined filters' do
          result = described_class.new(params: {
            entity_type: 'User',
            entity_id: user.id,
            created_before: Time.zone.parse('2024-01-15 06:00:00'),
            per_page: 2,
            pagination: 'keyset'
          }).execute

          expect(result[:records]).to be_empty
          expect(result[:cursor_for_next_page]).to be_nil
        end
      end
    end

    context 'when using offset pagination' do
      let(:params) { { page: 1, per_page: 20, pagination: 'offset' } }

      context 'when testing basic functionality' do
        it 'returns all audit events in descending order by ID' do
          result = execute

          expected_order = [
            project_event2,
            group_event2,
            project_event1,
            group_event1,
            user_event1,
            instance_event1
          ].sort_by(&:id).reverse

          expect(result[:records]).to eq(expected_order)
        end

        it 'returns offset pagination metadata' do
          result = execute

          expect(result).to have_key(:records)
          expect(result).to have_key(:page)
          expect(result).to have_key(:per_page)
          expect(result).to have_key(:has_next_page)
          expect(result).not_to have_key(:total_count)
          expect(result).not_to have_key(:total_pages)
          expect(result[:records]).to be_an(Array)
          expect(result[:page]).to eq(1)
          expect(result[:per_page]).to eq(20)
        end

        it 'returns has_next_page as false when all records fit on one page' do
          result = execute

          expect(result[:has_next_page]).to be false
        end
      end

      context 'when SimpleOrderBuilder returns failure' do
        before do
          allow(Gitlab::Pagination::Keyset::SimpleOrderBuilder)
            .to receive(:build)
                  .and_return([nil, false])
        end

        it 'raises an error' do
          expect { execute }
            .to raise_error(RuntimeError, 'Failed to build keyset ordering')
        end
      end

      context 'when using pagination' do
        let(:params) { { page: 1, per_page: 1, pagination: 'offset' } }

        it 'paginates correctly through all pages' do
          all_events = [
            project_event2,
            group_event2,
            project_event1,
            group_event1,
            user_event1,
            instance_event1
          ].sort_by(&:id).reverse

          page1 = described_class.new(params: params).execute
          expect(page1[:records]).to eq([all_events[0]])
          expect(page1[:page]).to eq(1)

          page2 = described_class.new(params: params.merge(page: 2)).execute
          expect(page2[:records]).to eq([all_events[1]])
          expect(page2[:page]).to eq(2)

          page3 = described_class.new(params: params.merge(page: 3)).execute
          expect(page3[:records]).to eq([all_events[2]])
          expect(page3[:page]).to eq(3)

          page4 = described_class.new(params: params.merge(page: 4)).execute
          expect(page4[:records]).to eq([all_events[3]])
          expect(page4[:page]).to eq(4)

          page5 = described_class.new(params: params.merge(page: 5)).execute
          expect(page5[:records]).to eq([all_events[4]])
          expect(page5[:page]).to eq(5)

          page6 = described_class.new(params: params.merge(page: 6)).execute
          expect(page6[:records]).to eq([all_events[5]])
          expect(page6[:page]).to eq(6)

          page7 = described_class.new(params: params.merge(page: 7)).execute
          expect(page7[:records]).to be_empty
          expect(page7[:page]).to eq(7)
        end

        it 'returns has_next_page true when more records exist' do
          page1 = described_class.new(params: params).execute
          expect(page1[:has_next_page]).to be true
        end

        it 'returns has_next_page false on the last page' do
          page6 = described_class.new(params: params.merge(page: 6)).execute
          expect(page6[:has_next_page]).to be false
        end

        it 'returns has_next_page false when beyond the last page' do
          page7 = described_class.new(params: params.merge(page: 7)).execute
          expect(page7[:has_next_page]).to be false
        end
      end

      context 'when using sort parameter' do
        context 'with created_desc (default)' do
          let(:params) { { page: 1, per_page: 20, pagination: 'offset', sort: 'created_desc' } }

          it 'returns events in descending order by ID' do
            result = execute

            expected_order = [
              project_event2,
              group_event2,
              project_event1,
              group_event1,
              user_event1,
              instance_event1
            ].sort_by(&:id).reverse

            expect(result[:records]).to eq(expected_order)
          end
        end

        context 'with created_asc' do
          let(:params) { { page: 1, per_page: 20, pagination: 'offset', sort: 'created_asc' } }

          it 'returns events in ascending order by ID' do
            result = execute

            expected_order = [
              project_event2,
              group_event2,
              project_event1,
              group_event1,
              user_event1,
              instance_event1
            ].sort_by(&:id)

            expect(result[:records]).to eq(expected_order)
          end
        end
      end

      context 'when filtering records' do
        context 'when filtering by entity type' do
          let(:params) { { entity_type: 'Group', page: 1, per_page: 20, pagination: 'offset' } }

          it 'returns only group events' do
            result = execute

            expected_order = [group_event2, group_event1].sort_by(&:id).reverse
            expect(result[:records]).to eq(expected_order)
            expect(result[:records]).to all(be_a(AuditEvents::GroupAuditEvent))
          end

          context 'with pagination' do
            let(:params) { { entity_type: 'Group', page: 1, per_page: 1, pagination: 'offset' } }

            it 'paginates filtered results correctly' do
              expected_order = [group_event2, group_event1].sort_by(&:id).reverse

              page1 = execute
              expect(page1[:records]).to eq([expected_order[0]])

              page2 = described_class.new(params: params.merge(page: 2)).execute
              expect(page2[:records]).to eq([expected_order[1]])
              expect(page2[:page]).to eq(2)
            end
          end

          context 'with project entity type' do
            let(:params) { { entity_type: 'Project', page: 1, per_page: 20, pagination: 'offset' } }

            it 'returns only project events' do
              result = execute

              expected_order = [project_event2, project_event1].sort_by(&:id).reverse
              expect(result[:records]).to eq(expected_order)
              expect(result[:records]).to all(be_a(AuditEvents::ProjectAuditEvent))
            end
          end

          context 'with user entity type' do
            let(:params) { { entity_type: 'User', page: 1, per_page: 20, pagination: 'offset' } }

            it 'returns only user events' do
              result = execute

              expect(result[:records]).to eq([user_event1])
              expect(result[:records]).to all(be_a(AuditEvents::UserAuditEvent))
            end
          end

          context 'with instance entity type' do
            let(:params) do
              { entity_type: 'Gitlab::Audit::InstanceScope', page: 1, per_page: 20, pagination: 'offset' }
            end

            it 'returns only instance events' do
              result = execute

              expect(result[:records]).to eq([instance_event1])
              expect(result[:records]).to all(be_a(AuditEvents::InstanceAuditEvent))
            end
          end
        end

        context 'when filtering by entity_id' do
          context 'with valid entity_type and entity_id' do
            context 'for Group entity' do
              let(:params) do
                { entity_type: 'Group', entity_id: group.id, page: 1, per_page: 20, pagination: 'offset' }
              end

              it 'returns only events for the specific group' do
                result = execute

                expected_order = [group_event2, group_event1].sort_by(&:id).reverse
                expect(result[:records]).to eq(expected_order)
                expect(result[:records]).to all(have_attributes(group_id: group.id))
              end
            end

            context 'for Project entity' do
              let(:params) do
                { entity_type: 'Project', entity_id: project.id, page: 1, per_page: 20, pagination: 'offset' }
              end

              it 'returns only events for the specific project' do
                result = execute

                expected_order = [project_event2, project_event1].sort_by(&:id).reverse
                expect(result[:records]).to eq(expected_order)
                expect(result[:records]).to all(have_attributes(project_id: project.id))
              end
            end

            context 'for User entity' do
              let(:params) { { entity_type: 'User', entity_id: user.id, page: 1, per_page: 20, pagination: 'offset' } }

              it 'returns only events for the specific user' do
                result = execute

                expect(result[:records]).to eq([user_event1])
                expect(result[:records]).to all(have_attributes(user_id: user.id))
              end
            end

            context 'when entity_id does not exist' do
              let(:params) do
                { entity_type: 'Group', entity_id: non_existing_record_id, page: 1, per_page: 20, pagination: 'offset' }
              end

              it 'returns empty results' do
                result = execute

                expect(result[:records]).to be_empty
              end
            end
          end

          context 'when entity_id is provided without entity_type' do
            let(:params) { { entity_id: group.id, page: 1, per_page: 20, pagination: 'offset' } }

            it 'ignores entity_id and returns all events' do
              result = execute

              expected_order = [
                project_event2,
                group_event2,
                project_event1,
                group_event1,
                user_event1,
                instance_event1
              ].sort_by(&:id).reverse

              expect(result[:records]).to eq(expected_order)
            end
          end
        end

        context 'when filtering by date range' do
          let(:params) do
            { created_after: Time.zone.parse('2024-01-15 09:00:00'),
              created_before: Time.zone.parse('2024-01-15 11:00:00'),
              page: 1, per_page: 20, pagination: 'offset' }
          end

          it 'returns events within date range' do
            result = execute

            expected_order = [project_event2, group_event2, project_event1].sort_by(&:id).reverse
            expect(result[:records]).to eq(expected_order)
          end
        end

        context 'when filtering by author' do
          let(:params) { { author_id: author.id, page: 1, per_page: 20, pagination: 'offset' } }

          it 'returns events by specific author' do
            result = execute

            expected_order = [project_event2, instance_event1].sort_by(&:id).reverse
            expect(result[:records]).to eq(expected_order)
          end
        end

        context 'when filtering by entity_username' do
          let_it_be(:user_with_username) { create(:user, username: 'testuser') }
          let_it_be(:user_event_with_username) do
            create(:audit_events_user_audit_event,
              created_at: Time.zone.parse('2024-01-15 12:00:00'),
              user_id: user_with_username.id)
          end

          context 'with entity_type User and entity_username' do
            let(:params) do
              { entity_type: 'User', entity_username: 'testuser', page: 1, per_page: 20, pagination: 'offset' }
            end

            it 'returns only events for the user with specified username' do
              result = execute

              expect(result[:records]).to eq([user_event_with_username])
              expect(result[:records]).to all(have_attributes(user_id: user_with_username.id))
            end
          end
        end
      end

      context 'when using combined filters with pagination' do
        let_it_be(:another_group) { create(:group) }
        let_it_be(:another_project) { create(:project) }

        let_it_be(:another_group_event1) do
          create(:audit_events_group_audit_event,
            created_at: Time.zone.parse('2024-01-15 09:30:00'),
            group_id: another_group.id)
        end

        let_it_be(:another_group_event2) do
          create(:audit_events_group_audit_event,
            created_at: Time.zone.parse('2024-01-15 10:30:00'),
            group_id: another_group.id)
        end

        let_it_be(:another_project_event) do
          create(:audit_events_project_audit_event,
            created_at: Time.zone.parse('2024-01-15 09:45:00'),
            project_id: another_project.id,
            author_id: author.id)
        end

        context 'with entity_type and entity_id' do
          let(:params) { { entity_type: 'Group', entity_id: group.id, page: 1, per_page: 1, pagination: 'offset' } }

          it 'applies both entity type and entity_id filters with pagination correctly' do
            expected_order = [group_event2, group_event1].sort_by(&:id).reverse

            page1 = execute
            expect(page1[:records]).to eq([expected_order[0]])
            expect(page1[:records].first.group_id).to eq(group.id)

            page2 = described_class.new(params: params.merge(page: 2)).execute
            expect(page2[:records]).to eq([expected_order[1]])
            expect(page2[:records].first.group_id).to eq(group.id)

            all_pages = [page1[:records], page2[:records]].flatten
            expect(all_pages).not_to include(another_group_event1, another_group_event2)
          end
        end

        context 'with date range, entity type, and entity_id' do
          let(:params) do
            {
              entity_type: 'Project',
              entity_id: project.id,
              created_after: Time.zone.parse('2024-01-15 09:00:00'),
              page: 1,
              per_page: 1,
              pagination: 'offset'
            }
          end

          it 'applies all three filters correctly' do
            expected_order = [project_event2, project_event1].sort_by(&:id).reverse

            page1 = execute
            expect(page1[:records]).to eq([expected_order[0]])
            expect(page1[:records].first.project_id).to eq(project.id)

            page2 = described_class.new(params: params.merge(page: 2)).execute
            expect(page2[:records]).to eq([expected_order[1]])
            expect(page2[:records].first.project_id).to eq(project.id)

            expect(page1[:records]).not_to include(another_project_event)
            expect(page2[:records]).not_to include(another_project_event)
          end
        end

        context 'with author_id, entity_type, and entity_id' do
          let(:params) do
            {
              entity_type: 'Project',
              entity_id: project.id,
              author_id: author.id,
              page: 1,
              per_page: 1,
              pagination: 'offset'
            }
          end

          it 'filters by all criteria including author' do
            result = execute
            expect(result[:records]).to eq([project_event2])
            expect(result[:records].first).to have_attributes(
              project_id: project.id,
              author_id: author.id
            )

            expect(result[:records]).not_to include(project_event1)
          end
        end

        context 'with entity_id for non-existent entity' do
          let(:params) do
            {
              entity_type: 'Group',
              entity_id: non_existing_record_id,
              page: 1,
              per_page: 2,
              pagination: 'offset'
            }
          end

          it 'returns empty result when entity_id does not match any records' do
            result = execute

            expect(result[:records]).to be_empty
          end
        end

        context 'with all filters combined' do
          let(:params) do
            {
              entity_type: 'Group',
              entity_id: another_group.id,
              created_after: Time.zone.parse('2024-01-15 09:00:00'),
              created_before: Time.zone.parse('2024-01-15 10:00:00'),
              page: 1,
              per_page: 1,
              pagination: 'offset'
            }
          end

          it 'correctly applies all filters with pagination' do
            page1 = execute
            expect(page1[:records]).to eq([another_group_event1])
            expect(page1[:records].first.group_id).to eq(another_group.id)

            expect(page1[:records]).not_to include(another_group_event2)
          end
        end

        it 'returns empty result when no events match all combined filters' do
          result = described_class.new(params: {
            entity_type: 'User',
            entity_id: user.id,
            created_before: Time.zone.parse('2024-01-15 06:00:00'),
            page: 1,
            per_page: 2,
            pagination: 'offset'
          }).execute

          expect(result[:records]).to be_empty
        end
      end

      context 'with edge cases' do
        context 'when page is zero or negative' do
          let(:params) { { page: 0, per_page: 2, pagination: 'offset' } }

          it 'treats page as 1' do
            result = execute
            expect(result[:page]).to eq(1)
          end
        end

        context 'when per_page is zero or negative' do
          let(:params) { { page: 1, per_page: 0, pagination: 'offset' } }

          it 'treats per_page as 1' do
            result = execute
            expect(result[:per_page]).to eq(1)
          end
        end

        context 'when requesting page beyond available data' do
          let(:params) { { page: 100, per_page: 20, pagination: 'offset' } }

          it 'returns empty records but correct metadata' do
            result = execute
            expect(result[:records]).to be_empty
            expect(result[:page]).to eq(100)
          end
        end
      end
    end

    context 'when pagination parameter is not specified' do
      let(:params) { { per_page: 20 } }

      it 'defaults to offset pagination' do
        result = execute

        expect(result).to have_key(:page)
        expect(result).to have_key(:has_next_page)
        expect(result).not_to have_key(:total_count)
        expect(result).not_to have_key(:total_pages)
        expect(result).not_to have_key(:cursor_for_next_page)
      end
    end
  end
end
