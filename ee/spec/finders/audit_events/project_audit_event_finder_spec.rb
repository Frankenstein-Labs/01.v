# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::ProjectAuditEventFinder, feature_category: :audit_events do
  let_it_be(:user_1) { create(:user) }
  let_it_be(:user_2) { create(:user) }
  let_it_be(:user_3) { create(:user) }
  let_it_be(:project_1) { create(:project) }
  let_it_be(:project_2) { create(:project) }

  let_it_be(:project_audit_event_1) do
    create(:audit_events_project_audit_event, project_id: project_1.id, author_id: user_1.id, created_at: 5.days.ago)
  end

  let_it_be(:project_audit_event_2) do
    create(:audit_events_project_audit_event, project_id: project_1.id, author_id: user_2.id, created_at: 3.days.ago)
  end

  let_it_be(:project_audit_event_3) do
    create(:audit_events_project_audit_event, project_id: project_2.id, author_id: user_2.id, created_at: 2.days.ago)
  end

  let_it_be(:project_audit_event_4) do
    create(:audit_events_project_audit_event, project_id: project_2.id, author_id: user_3.id, created_at: 1.day.ago)
  end

  let(:params) { {} }

  subject(:finder) { described_class.new(project: project_1, params: params) }

  describe '#execute' do
    subject(:execute) { finder.execute }

    shared_examples 'no filtering' do
      it 'finds all project events' do
        expect(execute).to contain_exactly(project_audit_event_1, project_audit_event_2)
      end
    end

    context 'when filtering by author_id' do
      context 'when invalid author_id is passed' do
        let(:params) { { author_id: '0' } }

        it_behaves_like 'no filtering'
      end

      context 'when author_id is passed' do
        let(:params) { { author_id: user_2.id } }

        it 'finds the right event' do
          expect(execute).to contain_exactly(project_audit_event_2)
        end
      end
    end

    context 'when filtering by created_at' do
      context 'when filtering by created_after' do
        let(:params) { { created_after: project_audit_event_2.created_at } }

        it 'returns events created on or after the given date' do
          expect(execute).to contain_exactly(project_audit_event_2)
        end
      end

      context 'when filtering by created_before' do
        let(:params) { { created_before: project_audit_event_1.created_at } }

        it 'returns events created on or before the given date' do
          expect(execute).to contain_exactly(project_audit_event_1)
        end
      end

      context 'when both created_after and created_before are passed' do
        let(:params) do
          { created_after: project_audit_event_1.created_at, created_before: project_audit_event_2.created_at }
        end

        it 'returns events created between the given dates' do
          expect(execute).to contain_exactly(project_audit_event_1, project_audit_event_2)
        end
      end
    end

    context 'when filtering by author_username' do
      context 'when username is too short' do
        let(:params) { { author_username: 'a' * (User::MIN_USERNAME_LENGTH - 1) } }

        it 'ignores author_username and returns all events' do
          expect(execute).to contain_exactly(project_audit_event_2, project_audit_event_1)
        end
      end

      context 'when username is too long' do
        let(:params) { { author_username: 'a' * (User::MAX_USERNAME_LENGTH + 1) } }

        it 'ignores author_username and returns all events' do
          expect(execute).to contain_exactly(project_audit_event_2, project_audit_event_1)
        end
      end

      context 'when username is of right length' do
        context 'when username does not exist' do
          let(:params) { { author_username: 'a' * User::MAX_USERNAME_LENGTH } }

          it 'ignores author_username and returns all events' do
            expect(execute).to be_empty
          end
        end

        context 'when username does exist' do
          context 'when events belonging to user are of project passed' do
            let(:params) { { author_username: user_1.username } }

            it 'returns events belonging to user' do
              expect(execute).to contain_exactly(project_audit_event_1)
            end
          end

          context 'when events belonging to user are of different project' do
            let(:params) { { author_username: user_3.username } }

            it 'does not return any event' do
              expect(execute).to be_empty
            end
          end
        end
      end
    end

    context 'when sort param is passed' do
      context 'when created_asc is passed' do
        let(:params) { { sort: 'created_asc' } }

        it 'returns project audit events in asc order' do
          expect(execute).to eq([project_audit_event_1, project_audit_event_2])
        end
      end

      context 'when created_desc is passed' do
        let(:params) { { sort: 'created_desc' } }

        it 'returns project audit events in desc order' do
          expect(execute).to eq([project_audit_event_2, project_audit_event_1])
        end
      end
    end

    context 'when using keyset pagination' do
      let(:params) { { pagination: 'keyset', sort: 'created_desc' } }

      it 'orders by created_at and id for partition pruning' do
        result = finder.execute

        expect(result.to_sql).to include('created_at')
        expect(result.to_sql).to include('ORDER BY')
        expect(result.to_sql).to include('"project_audit_events"."created_at" DESC')
        expect(result.to_sql).to include('"project_audit_events"."id" DESC')
      end

      it 'returns results in correct order' do
        result = finder.execute

        expect(result.to_a).to eq([project_audit_event_2, project_audit_event_1])
      end

      it 'does not raise error when generating keyset cursor with paginator' do
        result = finder.execute.limit(1)

        expect do
          paginator = Gitlab::Pagination::Keyset::Paginator.new(scope: result)
          cursor_data = paginator.cursor_for_next_page

          if cursor_data
            decoded = Gitlab::Pagination::Keyset::Paginator::Base64CursorConverter.parse(cursor_data)
            expect(decoded.keys).to include('created_at', 'id')
          end
        end.not_to raise_error
      end

      context 'with created_asc sort' do
        let(:params) { { pagination: 'keyset', sort: 'created_asc' } }

        it 'orders by created_at asc and id asc' do
          result = finder.execute

          expect(result.to_sql).to include('"project_audit_events"."created_at" ASC')
          expect(result.to_sql).to include('"project_audit_events"."id" ASC')
        end
      end
    end

    context 'when using offset pagination (default)' do
      let(:params) { { sort: 'created_desc' } }

      it 'orders by created_at and id' do
        result = finder.execute

        expect(result.to_sql).to include('created_at')
        expect(result.to_sql).to include('"project_audit_events"."id" DESC')
      end

      context 'with created_asc sort' do
        let(:params) { { sort: 'created_asc' } }

        it 'orders by created_at asc and id asc' do
          result = finder.execute

          expect(result.to_sql).to include('"project_audit_events"."created_at" ASC')
          expect(result.to_sql).to include('"project_audit_events"."id" ASC')
        end
      end
    end

    describe 'offset optimization' do
      let_it_be(:pagination_events) do
        create_list(:audit_events_project_audit_event, 5, project_id: project_1.id, created_at: 3.days.ago)
      end

      after do
        pagination_events.each(&:destroy)
      end

      context 'with keyset pagination' do
        let(:params) { { page: 101, per_page: 1, pagination: 'keyset', optimize_offset: true } }

        it 'does not use optimization' do
          expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan).not_to receive(:new)

          finder.execute
        end
      end

      context 'with high page numbers' do
        let(:params) { { page: 101, per_page: 10, optimize_offset: true } }

        it 'uses optimization' do
          expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
            .to receive(:new)
            .with(hash_including(
              page: 101,
              per_page: 10,
              scope: kind_of(ActiveRecord::Relation)
            ))
            .and_call_original

          finder.execute
        end
      end

      context 'with filters' do
        let(:base_params) { { page: 101, per_page: 10, optimize_offset: true } }

        context 'with created_after filter' do
          let(:params) { base_params.merge(created_after: project_audit_event_1.created_at) }

          it 'uses optimization and returns correct results' do
            expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
              .to receive(:new)
              .with(hash_including(page: 101, per_page: 10))
              .and_call_original

            results = finder.execute

            expect(results).to all(have_attributes(created_at: be >= project_audit_event_1.created_at))
          end
        end

        context 'with author_id filter' do
          let(:params) { base_params.merge(author_id: user_1.id) }

          it 'uses optimization and returns correct results' do
            expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
              .to receive(:new)
              .with(hash_including(page: 101, per_page: 10))
              .and_call_original

            results = finder.execute

            expect(results).to all(have_attributes(author_id: user_1.id))
          end
        end
      end
    end
  end

  describe '#find_by!' do
    let(:id) { project_audit_event_1.id }

    subject(:find) { finder.find_by!(id: id) } # rubocop:disable Rails/FindById -- Not ActiveRecord find_by!

    it { is_expected.to eq(project_audit_event_1) }

    context 'when non-existent id provided' do
      let(:id) { 'non-existent-id' }

      it 'raises exception' do
        expect { find }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
