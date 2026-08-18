# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEventFinder, feature_category: :audit_events do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:subproject) { create(:project, namespace: subgroup) }

  let_it_be(:user_audit_event) { create(:user_audit_event, created_at: 3.days.ago, entity_id: user.id) }
  let_it_be(:project_audit_event) do
    create(:project_audit_event, entity_id: project.id, author_id: user.id, created_at: 2.days.ago)
  end

  let_it_be(:subproject_audit_event) { create(:project_audit_event, entity_id: subproject.id, created_at: 2.days.ago) }
  let_it_be(:group_audit_event) do
    create(:group_audit_event, entity_id: group.id, author_id: user.id, created_at: 1.day.ago)
  end

  let(:level) { Gitlab::Audit::Levels::Instance.new }
  let(:params) { {} }

  subject(:finder) { described_class.new(level: level, params: params) }

  describe '#execute' do
    subject(:execute) { finder.execute }

    shared_examples 'no filtering' do
      it 'finds all the events' do
        expect(execute.count).to eq(4)
      end
    end

    context 'when scoping the results' do
      context 'when project level' do
        let(:level) { Gitlab::Audit::Levels::Project.new(project: project) }

        it 'finds all project events' do
          expect(execute).to contain_exactly(project_audit_event)
        end
      end

      context 'when group level' do
        let(:level) { Gitlab::Audit::Levels::Group.new(group: group) }

        it 'finds all group events' do
          expect(execute).to contain_exactly(group_audit_event)
        end
      end

      context 'when instance level' do
        let(:level) { Gitlab::Audit::Levels::Instance.new }

        it 'finds all instance level events' do
          expect(execute).to contain_exactly(
            project_audit_event,
            subproject_audit_event,
            group_audit_event,
            user_audit_event
          )
        end
      end

      context 'when invalid level' do
        let(:level) { 'an invalid level' }

        it 'raises exception' do
          expect { execute }.to raise_error(described_class::InvalidLevelTypeError)
        end
      end
    end

    context 'when filtering by entity_id' do
      context 'with no entity_type provided' do
        let(:params) { { entity_id: 1 } }

        it_behaves_like 'no filtering'
      end

      context 'with invalid entity_id' do
        let(:params) { { entity_type: 'User', entity_id: '0' } }

        it 'ignores entity_id and returns all events for given entity_type' do
          expect(execute.count).to eq(1)
        end
      end

      shared_examples 'finds the right event' do
        it 'finds the right event' do
          expect(execute.count).to eq(1)

          entity = execute.first

          expect(entity.entity_type).to eq(entity_type)
          expect(entity.id).to eq(audit_event.id)
        end
      end

      context 'with User Event' do
        let(:params) { { entity_type: 'User', entity_id: user_audit_event.entity_id } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'User' }
          let(:audit_event) { user_audit_event }
        end
      end

      context 'with Project Event' do
        let(:params) { { entity_type: 'Project', entity_id: project_audit_event.entity_id } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'Project' }
          let(:audit_event) { project_audit_event }
        end
      end

      context 'with Group Event' do
        let(:params) { { entity_type: 'Group', entity_id: group_audit_event.entity_id } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'Group' }
          let(:audit_event) { group_audit_event }
        end
      end

      context 'with Instance Event' do
        let_it_be(:instance_audit_event) { create(:instance_audit_event) }
        let(:params) { { entity_type: 'Gitlab::Audit::InstanceScope', entity_id: instance_audit_event.entity_id } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'Gitlab::Audit::InstanceScope' }
          let(:audit_event) { instance_audit_event }
        end
      end
    end

    context 'when filtering by entity_type' do
      let(:entity_types) { execute.map(&:entity_type) }

      context 'with User Event' do
        let(:params) { { entity_type: 'User' } }

        it 'finds the right user event' do
          expect(entity_types).to all(eq 'User')
        end
      end

      context 'with Project Event' do
        let(:params) { { entity_type: 'Project' } }

        it 'finds the right project event' do
          expect(entity_types).to all(eq 'Project')
        end
      end

      context 'with Group Event' do
        let(:params) { { entity_type: 'Group' } }

        it 'finds the right group event' do
          expect(entity_types).to all(eq 'Group')
        end
      end

      context 'with Instance Event' do
        let(:params) { { entity_type: 'Gitlab::Audit::InstanceScope' } }

        it 'finds the right group event' do
          expect(entity_types).to all(eq 'Gitlab::Audit::InstanceScope')
        end
      end

      context 'with invalid entity types' do
        context 'with blank entity_type' do
          let(:params) { { entity_type: '' } }

          it_behaves_like 'no filtering'
        end

        context 'with invalid entity_type' do
          let(:params) { { entity_type: 'Invalid Entity Type' } }

          it_behaves_like 'no filtering'
        end
      end
    end

    context 'when filtering by author_id' do
      context 'with no author_id provided' do
        let(:params) { { entity_type: 'Author' } }

        it_behaves_like 'no filtering'
      end

      context 'with invalid author_id' do
        let(:params) { { author_id: '0' } }

        it 'ignores author_id and returns all events irrespective of entity_type' do
          expect(execute.count).to eq(4)
        end
      end

      shared_examples 'finds the right event' do
        it 'finds the right event' do
          expect(execute.count).to eq(1)

          entity = execute.first

          expect(entity.entity_type).to eq(entity_type)
          expect(entity.id).to eq(audit_event.id)
          expect(entity.author_id).to eq(audit_event.author_id)
        end
      end

      context 'with Group Event' do
        let(:level) { Gitlab::Audit::Levels::Group.new(group: group) }
        let(:params) { { author_id: group_audit_event.author_id } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'Group' }
          let(:audit_event) { group_audit_event }
        end
      end

      context 'with Project Event' do
        let(:level) { Gitlab::Audit::Levels::Project.new(project: project) }
        let(:params) { { author_id: project_audit_event.author_id } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'Project' }
          let(:audit_event) { project_audit_event }
        end
      end
    end

    context 'when filtering by created_at' do
      context 'with created_after' do
        let(:params) { { created_after: group_audit_event.created_at } }

        it 'returns events created on or after the given date' do
          expect(execute).to contain_exactly(group_audit_event)
        end
      end

      context 'with created_before' do
        let(:params) { { created_before: user_audit_event.created_at } }

        it 'returns events created on or before the given date' do
          expect(execute).to contain_exactly(user_audit_event)
        end
      end

      context 'with created_after and created_before' do
        let(:params) { { created_after: user_audit_event.created_at, created_before: project_audit_event.created_at } }

        it 'returns events created between the given dates' do
          expect(execute).to contain_exactly(user_audit_event, project_audit_event)
        end
      end
    end

    context 'when filtering by entity_username' do
      context 'with User Event' do
        let(:params) { { entity_type: 'User', entity_username: user.username } }
        let(:entity_type) { 'User' }
        let(:audit_event) { user_audit_event }

        it 'finds the right event' do
          expect(execute.count).to eq(1)

          entity = execute.first

          expect(entity.entity_type).to eq(entity_type)
          expect(entity.id).to eq(audit_event.id)
          expect(entity.entity_id).to eq(user.id)
        end
      end
    end

    context 'when filtering by author_username' do
      context 'when username is too short' do
        let(:params) { { author_username: 'a' * (User::MIN_USERNAME_LENGTH - 1) } }

        it 'ignores author_username and returns all events irrespective of entity_type' do
          expect(execute.count).to eq(4)
        end
      end

      context 'when username is too long' do
        let(:params) { { author_username: 'a' * (User::MAX_USERNAME_LENGTH + 1) } }

        it 'ignores author_username and returns all events irrespective of entity_type' do
          expect(execute.count).to eq(4)
        end
      end

      shared_examples 'finds the right event' do
        it 'finds the right event' do
          expect(execute.count).to eq(1)

          entity = execute.first

          expect(entity.entity_type).to eq(entity_type)
          expect(entity.id).to eq(audit_event.id)
          expect(entity.author_id).to eq(audit_event.author_id)
        end
      end

      context 'with Instance Event' do
        let(:level) { Gitlab::Audit::Levels::Instance.new }
        let(:params) { { author_username: user.username } }

        it 'finds all the events the user authored', :aggregate_failures do
          expect(execute.count).to eq(2)

          execute.each do |entity|
            expect(entity.author_id).to eq(user.id)
          end
        end
      end

      context 'with Group Event' do
        let(:level) { Gitlab::Audit::Levels::Group.new(group: group) }
        let(:params) { { author_username: user.username } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'Group' }
          let(:audit_event) { group_audit_event }
        end
      end

      context 'with Project Event' do
        let(:level) { Gitlab::Audit::Levels::Project.new(project: project) }
        let(:params) { { author_username: user.username } }

        it_behaves_like 'finds the right event' do
          let(:entity_type) { 'Project' }
          let(:audit_event) { project_audit_event }
        end
      end
    end
  end

  describe '#find_by!' do
    let(:id) { user_audit_event.id }

    subject(:find_by) { finder.find_by!(id: id) } # rubocop:disable Rails/FindById -- testing the finder's own method, not AR

    it { is_expected.to eq(user_audit_event) }

    context 'when non-existent id provided' do
      let(:id) { 'non-existent-id' }

      it 'raises exception' do
        expect { find_by }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'offset optimization' do
    let_it_be(:many_events) { create_list(:audit_event, 2) }

    it 'does not use optimization for keyset pagination' do
      params = { page: 101, per_page: 1, pagination: 'keyset', optimize_offset: true }

      expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan).not_to receive(:new)

      described_class.new(level: level, params: params).execute
    end

    it 'does not use optimization for low page numbers' do
      params = { page: 1, per_page: 10, optimize_offset: true }

      expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan).not_to receive(:new)

      described_class.new(level: level, params: params).execute
    end

    it 'uses optimization for high page numbers' do
      params = { page: 101, per_page: 10, optimize_offset: true }

      expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
        .to receive(:new)
        .with(hash_including(
          page: 101,
          per_page: 10,
          scope: kind_of(ActiveRecord::Relation)
        ))
        .and_call_original

      described_class.new(level: level, params: params).execute
    end

    context 'with filters' do
      let(:base_params) { { page: 101, per_page: 10, optimize_offset: true } }

      it 'uses optimization with created_after filter and returns correct results' do
        created_time = project_audit_event.created_at
        params = base_params.merge(created_after: created_time)

        expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
          .to receive(:new)
          .with(hash_including(page: 101, per_page: 10))
          .and_call_original

        results = described_class.new(level: level, params: params).execute

        expect(results).to all(have_attributes(created_at: be > created_time))
      end

      it 'uses optimization with entity_type filter and returns correct results' do
        params = base_params.merge(entity_type: 'User')

        expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
          .to receive(:new)
          .with(hash_including(page: 101, per_page: 10))
          .and_call_original

        results = described_class.new(level: level, params: params).execute

        expect(results).to all(have_attributes(entity_type: 'User'))
      end

      it 'uses optimization with author_id filter and returns correct results' do
        params = base_params.merge(author_id: user.id)

        expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
          .to receive(:new)
          .with(hash_including(page: 101, per_page: 10))
          .and_call_original

        results = described_class.new(level: level, params: params).execute

        expect(results).to all(have_attributes(author_id: user.id))
      end

      it 'uses optimization with multiple filters combined and returns correct results' do
        created_time = project_audit_event.created_at
        params = base_params.merge(
          created_after: created_time,
          entity_type: 'User',
          author_id: user.id
        )

        expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
          .to receive(:new)
          .with(hash_including(page: 101, per_page: 10))
          .and_call_original

        results = described_class.new(level: level, params: params).execute

        aggregate_failures do
          expect(results).to all(have_attributes(
            entity_type: 'User',
            author_id: user.id
          ))
          expect(results).to all(have_attributes(created_at: be > created_time))
        end
      end

      it 'returns same results with and without optimization' do
        params = base_params.merge(
          created_after: project_audit_event.created_at,
          entity_type: 'User',
          author_id: user.id
        )

        optimized_results = described_class.new(
          level: level,
          params: params
        ).execute.to_a

        params[:optimize_offset] = false
        unoptimized_results = described_class.new(
          level: level,
          params: params
        ).execute.to_a

        expect(optimized_results).to match_array(unoptimized_results)
      end
    end
  end
end
