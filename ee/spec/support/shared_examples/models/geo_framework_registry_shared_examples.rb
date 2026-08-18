# frozen_string_literal: true

RSpec.shared_examples 'a Geo framework registry' do
  include EE::GeoHelpers

  let(:registry_class_factory) { described_class.underscore.tr('/', '_').to_sym }
  let_it_be(:secondary) { create(:geo_node) }
  let(:expired_timeout) { described_class.replicator_class.sync_timeout + 1.hour }

  before do
    stub_current_geo_node(secondary)
  end

  it_behaves_like 'a Geo verifiable registry'

  context 'obligatory fields check' do
    it 'has expected fields or methods' do
      registry = create(registry_class_factory) # rubocop:disable Rails/SaveBang
      expected_fields = %i[
        state retry_count last_sync_failure retry_at last_synced_at created_at
      ]

      expected_fields.each do |field|
        expect(registry).to respond_to(field)
      end
    end
  end

  context 'scopes' do
    describe 'sync_timed_out' do
      it 'return correct records' do
        record = create(registry_class_factory, :started, last_synced_at: expired_timeout.ago)
        create(registry_class_factory, :started, last_synced_at: 1.hour.ago)
        create(registry_class_factory, :failed, last_synced_at: expired_timeout.ago)

        expect(described_class.sync_timed_out).to eq [record]
      end
    end

    describe 'not_pending' do
      let(:registry1) { create(registry_class_factory, :started) }
      let(:registry2) { create(registry_class_factory, :failed) }
      let(:registry3) { create(registry_class_factory) } # rubocop:disable Rails/SaveBang

      it 'returns registries that are not pending' do
        expect(described_class.not_pending).to match_array([registry1, registry2])
      end
    end
  end

  context 'finders' do
    let!(:failed_item1) { create(registry_class_factory, :failed, retry_at: 1.minute.ago) }
    let!(:failed_item2) { create(registry_class_factory, :failed, retry_at: 1.minute.ago) }
    let!(:unsynced_item1) { create(registry_class_factory) } # rubocop:disable Rails/SaveBang
    let!(:unsynced_item2) { create(registry_class_factory) } # rubocop:disable Rails/SaveBang

    describe '.find_registries_pending' do
      it 'returns pending items' do
        result = described_class.find_registries_pending(batch_size: 10)

        expect(result).to include(unsynced_item1, unsynced_item2)
      end

      it 'returns pending items except some specific item ID' do
        except_id = unsynced_item1.model_record_id

        result = described_class.find_registries_pending(batch_size: 10, except_ids: [except_id])

        expect(result).to include(unsynced_item2)
        expect(result).not_to include(unsynced_item1)
      end
    end

    describe '.find_registries_needs_sync_again' do
      it 'returns failed items' do
        result = described_class.find_registries_needs_sync_again(batch_size: 10)

        expect(result).to include(failed_item1, failed_item2)
      end

      it 'returns failed items except some specific item ID' do
        except_id = failed_item1.model_record_id

        result = described_class.find_registries_needs_sync_again(batch_size: 10, except_ids: [except_id])

        expect(result).to include(failed_item2)
        expect(result).not_to include(failed_item1)
      end

      it 'orders records according to retry_at' do
        failed_item1.update!(retry_at: 2.days.ago)
        failed_item2.update!(retry_at: 4.days.ago)

        result = described_class.find_registries_needs_sync_again(batch_size: 10)

        expect(result.first).to eq failed_item2
      end
    end
  end

  describe '.ordered_by_id' do
    it 'orders records by id ASC' do
      registry1 = create(registry_class_factory, :started)
      registry2 = create(registry_class_factory, :failed)
      registry3 = create(registry_class_factory) # rubocop:disable Rails/SaveBang

      expect(described_class.ordered_by_id.to_a).to eq([registry1, registry2, registry3])
    end
  end

  describe '.ordered_by' do
    let!(:registry1) { create(registry_class_factory, last_synced_at: 3.hours.ago, verified_at: 6.hours.ago) }
    let!(:registry2) { create(registry_class_factory, last_synced_at: 6.hours.ago, verified_at: 3.hours.ago) }
    # rubocop:disable Rails/SaveBang -- Rubocop believes this is a record creation, not factory :(
    let!(:registry3) { create(registry_class_factory) }
    # rubocop:enable Rails/SaveBang

    it 'orders records by id ASC by default' do
      expect(described_class.ordered_by('').to_a).to eq([registry1, registry2, registry3])
    end

    it 'orders records by id DESC' do
      expect(described_class.ordered_by('id_desc').to_a).to eq([registry3, registry2, registry1])
    end

    it 'orders records by last_synced_at DESC' do
      expect(described_class.ordered_by('last_synced_at_desc').to_a).to eq([registry3, registry1, registry2])
    end

    it 'orders records by last_synced_at ASC' do
      expect(described_class.ordered_by('last_synced_at_asc').to_a).to eq([registry2, registry1, registry3])
    end

    it 'orders records by verified_at DESC' do
      expect(described_class.ordered_by('verified_at_desc').to_a).to eq([registry3, registry2, registry1])
    end

    it 'orders records by verified_at ASC' do
      expect(described_class.ordered_by('verified_at_asc').to_a).to eq([registry1, registry2, registry3])
    end
  end

  describe '.oldest_unsynced_time' do
    before do
      if described_class == Geo::GroupWikiRepositoryRegistry
        skip 'not currently supported for Geo::GroupWikiRepositoryRegistry: https://gitlab.com/gitlab-org/gitlab/-/work_items/593430'
      end
    end

    def update_model_timestamp(registry, time)
      case registry
      when Geo::SnippetRepositoryRegistry
        snippet_ids = described_class.model_updated_scope([registry.model_record_id]).pluck(:snippet_id)
        Snippet.where(id: snippet_ids).update_all(updated_at: time)
      when Geo::GroupWikiRepositoryRegistry
        group_ids = described_class.model_updated_scope([registry.model_record_id]).pluck(:group_id)
        Group.where(id: group_ids).update_all(updated_at: time)
      else
        described_class.model_updated_scope([registry.model_record_id])
          .update_all(described_class.model_updated_last => time)
      end
    end

    context 'when there are no unsynced records' do
      it 'returns nil when registry is empty' do
        expect(described_class.oldest_unsynced_time).to be_nil
      end

      it 'returns nil when all records are synced' do
        create(registry_class_factory, :synced)
        create(registry_class_factory, :synced)

        expect(described_class.oldest_unsynced_time).to be_nil
      end
    end

    context 'when there is one unsynced record' do
      it 'returns the timestamp of a pending record' do
        registry = create(registry_class_factory) # rubocop:disable Rails/SaveBang -- This is factory bot create
        update_model_timestamp(registry, 2.hours.ago)

        result = described_class.oldest_unsynced_time

        expect(result).to be_within(1.second).of(2.hours.ago)
      end

      it 'returns the timestamp of a started record' do
        registry = create(registry_class_factory, :started)
        update_model_timestamp(registry, 2.hours.ago)

        result = described_class.oldest_unsynced_time

        expect(result).to be_within(1.second).of(2.hours.ago)
      end

      it 'returns the timestamp of a failed record' do
        registry = create(registry_class_factory, :failed)
        update_model_timestamp(registry, 2.hours.ago)

        result = described_class.oldest_unsynced_time

        expect(result).to be_within(1.second).of(2.hours.ago)
      end
    end

    context 'when there are multiple unsynced records' do
      it 'returns the oldest (minimum) timestamp' do
        # rubocop:disable Rails/SaveBang -- This is factory bot create
        registry1 = create(registry_class_factory)
        registry2 = create(registry_class_factory)
        registry3 = create(registry_class_factory)
        # rubocop:enable Rails/SaveBang
        update_model_timestamp(registry1, 2.hours.ago)
        update_model_timestamp(registry2, 4.hours.ago)
        update_model_timestamp(registry3, 3.hours.ago)

        result = described_class.oldest_unsynced_time

        expect(result).to be_within(1.second).of(4.hours.ago)
      end

      it 'returns the oldest timestamp across different unsynced states' do
        failed_registry = create(registry_class_factory, :failed)
        started_registry = create(registry_class_factory, :started)
        pending_registry = create(registry_class_factory) # rubocop:disable Rails/SaveBang -- This is factory bot create
        update_model_timestamp(failed_registry, 2.hours.ago)
        update_model_timestamp(started_registry, 4.hours.ago)
        update_model_timestamp(pending_registry, 3.hours.ago)

        result = described_class.oldest_unsynced_time

        expect(result).to be_within(1.second).of(4.hours.ago)
      end
    end

    context 'with mixed states' do
      it 'ignores synced records and only considers unsynced' do
        synced_registry = create(registry_class_factory, :synced)
        unsynced_registry = create(registry_class_factory) # rubocop:disable Rails/SaveBang -- This is factory bot create
        update_model_timestamp(synced_registry, 2.hours.ago)
        update_model_timestamp(unsynced_registry, 3.hours.ago)

        result = described_class.oldest_unsynced_time

        expect(result).to be_within(1.second).of(3.hours.ago)
      end

      it 'correctly handles all unsynced states mixed with synced' do
        pending_registry = create(registry_class_factory) # rubocop:disable Rails/SaveBang -- This is factory bot create
        started_registry = create(registry_class_factory, :started)
        failed_registry = create(registry_class_factory, :failed)
        synced_registry = create(registry_class_factory, :synced)

        update_model_timestamp(pending_registry, 2.hours.ago)
        update_model_timestamp(started_registry, 3.hours.ago)
        update_model_timestamp(failed_registry, 4.hours.ago)
        update_model_timestamp(synced_registry, 1.hour.ago)
        result = described_class.oldest_unsynced_time

        expect(result).to be_within(1.second).of(4.hours.ago)
      end
    end

    context 'edge cases' do
      it 'returns nil when all records transition to synced' do
        registry = create(registry_class_factory) # rubocop:disable Rails/SaveBang -- This is factory bot create

        expect(described_class.oldest_unsynced_time).not_to be_nil

        registry.start!
        registry.synced!

        expect(described_class.oldest_unsynced_time).to be_nil
      end
    end
  end

  describe '.fail_sync_timeouts' do
    it 'marks started records as failed if they are expired' do
      record1 = create(registry_class_factory, :started, last_synced_at: expired_timeout.ago)
      record2 = create(registry_class_factory, :started, last_synced_at: 1.hour.ago) # not yet expired

      described_class.fail_sync_timeouts

      expect(record1.reload.state).to eq described_class::STATE_VALUES[:failed]
      expect(record2.reload.state).to eq described_class::STATE_VALUES[:started]
    end
  end

  describe '#failed!' do
    let(:registry) { create(registry_class_factory, :started) }
    let(:message) { 'Foo' }

    it 'sets last_sync_failure with message' do
      registry.failed!(message: message)

      expect(registry.last_sync_failure).to include(message)
    end

    it 'truncates a long last_sync_failure' do
      registry.failed!(message: 'a' * 256)

      expect(registry.last_sync_failure).to eq(('a' * 252) + '...')
    end

    it 'increments retry_count' do
      registry.failed!(message: message)

      expect(registry.retry_count).to eq(1)

      registry.start
      registry.failed!(message: message)

      expect(registry.retry_count).to eq(2)
    end

    it 'sets retry_at to a time in the future' do
      now = Time.current

      registry.failed!(message: message)

      expect(registry.retry_at >= now).to be_truthy
    end

    context 'when an error is given' do
      it 'includes error.message in last_sync_failure' do
        registry.failed!(message: message, error: StandardError.new('bar'))

        expect(registry.last_sync_failure).to eq('Foo: bar')
      end
    end

    context 'when missing_on_primary is not given' do
      it 'caps retry_at to default 1 hour' do
        registry.retry_count = 9999
        registry.failed!(message: message)

        expect(registry.retry_at).to be_within(10.minutes).of(1.hour.from_now)
      end
    end

    context 'when missing_on_primary is falsey' do
      it 'caps retry_at to default 1 hour' do
        registry.retry_count = 9999
        registry.failed!(message: message, missing_on_primary: false)

        expect(registry.retry_at).to be_within(10.minutes).of(1.hour.from_now)
      end
    end

    context 'when missing_on_primary is truthy' do
      it 'caps retry_at to 4 hours' do
        registry.retry_count = 9999
        registry.failed!(message: message, missing_on_primary: true)

        expect(registry.retry_at).to be_within(10.minutes).of(4.hours.from_now)
      end
    end

    it 'can transition from any state' do
      # initial state is started
      registry.failed!(message: message)

      expect(registry.reload.failed?).to be_truthy

      registry.start!

      expect(registry.reload.started?).to be_truthy

      registry.pending!

      registry.start!

      expect(registry.reload.started?).to be_truthy

      registry.pending!

      registry.failed!(message: message)

      expect(registry.reload.failed?).to be_truthy

      registry.failed!(message: message)

      expect(registry.reload.failed?).to be_truthy

      registry.synced!

      registry.failed!(message: message)

      expect(registry.reload.failed?).to be_truthy
    end

    it 'logs the state transition' do
      expect(Gitlab::Geo::Logger).to receive(:warn).with(
        hash_including(
          message: 'Sync state transition',
          class: registry.class.name,
          registry_id: registry.id,
          model_record_id: registry.model_record_id,
          from: 'started',
          to: 'failed',
          result: true
        )
      )

      registry.failed!(message: message)
    end
  end

  describe '#synced!' do
    let(:registry) { create(registry_class_factory, :started) }

    it 'mark as synced', :aggregate_failures do
      registry.synced!

      expect(registry.reload).to have_attributes(
        retry_count: 0,
        retry_at: nil,
        last_sync_failure: nil
      )

      expect(registry.synced?).to be_truthy
    end

    context 'when a sync was scheduled after the last sync finishes' do
      before do
        registry.update!(
          state: 'pending',
          retry_count: 2,
          retry_at: 1.hour.ago,
          last_sync_failure: 'Something went wrong'
        )

        registry.synced!
      end

      it 'does not reset state' do
        expect(registry.reload.pending?).to be_truthy
      end

      it 'resets the other sync state fields' do
        expect(registry.reload).to have_attributes(
          retry_count: 0,
          retry_at: nil,
          last_sync_failure: nil
        )
      end
    end

    it 'logs the state transition' do
      expect(Gitlab::Geo::Logger).to receive(:debug).with(
        hash_including(
          message: 'Sync state transition',
          class: registry.class.name,
          registry_id: registry.id,
          model_record_id: registry.model_record_id,
          from: 'started',
          to: 'synced'
        )
      )

      registry.synced!
    end
  end

  describe '.unsynced' do
    let(:unsynced_item1) { create(registry_class_factory) } # rubocop:disable Rails/SaveBang -- This is factory bot create
    let(:unsynced_item2) { create(registry_class_factory, :failed) }
    let(:synced_item1) { create(registry_class_factory, :synced) }

    it 'includes unsynced items in its response' do
      result = described_class.unsynced
      expect(result).to include(unsynced_item1, unsynced_item2)
      expect(result).not_to include(synced_item1)
    end
  end

  describe '#pending!' do
    context 'when a sync is currently running' do
      let(:registry) { create(registry_class_factory, :started) }

      it 'successfully moves state to pending' do
        expect do
          registry.pending!
        end.to change { registry.pending? }.from(false).to(true)
      end

      it 'logs the state transition' do
        expect(Gitlab::Geo::Logger).to receive(:debug).with(
          hash_including(
            message: 'Sync state transition',
            class: registry.class.name,
            registry_id: registry.id,
            model_record_id: registry.model_record_id,
            from: 'started',
            to: 'pending',
            result: true
          )
        )

        registry.pending!
      end
    end

    context 'when the registry has recorded a failure' do
      let(:registry) { create(registry_class_factory, :failed) }

      it 'clears failure retry fields' do
        expect do
          registry.pending!
          registry.reload
        end.to change { registry.retry_at }.from(a_kind_of(ActiveSupport::TimeWithZone)).to(nil)
           .and change { registry.retry_count }.to(0)
      end
    end
  end

  describe '#start!' do
    let(:registry) { create(registry_class_factory, :failed) }

    it 'successfully moves state to started' do
      expect do
        registry.start!
      end.to change { registry.started? }.from(false).to(true)
    end

    it 'logs the state transition' do
      expect(Gitlab::Geo::Logger).to receive(:debug).with(
        hash_including(
          message: 'Sync state transition',
          class: registry.class.name,
          registry_id: registry.id,
          model_record_id: registry.model_record_id,
          from: 'failed',
          to: 'started',
          result: true
        )
      )

      registry.start!
    end
  end
end
