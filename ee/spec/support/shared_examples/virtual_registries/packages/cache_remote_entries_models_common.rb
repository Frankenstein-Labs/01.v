# frozen_string_literal: true

# rubocop:disable Rails/SaveBang -- false positives
# TODO: Remove inverted_cache_association_name parameter once all callers use :cache_entries
RSpec.shared_examples 'virtual registries remote entries models' do
  |upstream_class:, upstream_factory:, entry_factory:, inverted_cache_association_name: :cache_remote_entries|
  it { is_expected.to include_module(ShaAttribute) }

  it_behaves_like 'having unique enum values'

  describe 'associations' do
    it 'belongs to a group' do
      is_expected.to belong_to(:group).required
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream).class_name(upstream_class).required
        .inverse_of(inverted_cache_association_name)
    end
  end

  describe 'validations' do
    %i[file file_sha1 relative_path size].each do |attr|
      it { is_expected.to validate_presence_of(attr) }
    end

    %i[upstream_etag content_type].each do |attr|
      it { is_expected.to validate_length_of(attr).is_at_most(255) }
    end

    %i[relative_path object_storage_key].each do |attr|
      it { is_expected.to validate_length_of(attr).is_at_most(1024) }
    end

    it { is_expected.to validate_length_of(:file_md5).is_equal_to(32).allow_nil }
    it { is_expected.to validate_length_of(:file_sha1).is_equal_to(40) }
  end

  describe 'scopes' do
    let_it_be(:cache_entry1) { create(entry_factory) }
    let_it_be(:cache_entry2) { create(entry_factory) }
    let_it_be(:cache_entry3) { create(entry_factory) }

    describe '.for_group' do
      let(:groups) { [cache_entry1.group, cache_entry2.group] }

      subject { described_class.for_group(groups) }

      it { is_expected.to contain_exactly(cache_entry1, cache_entry2) }
    end

    describe '.order_iid_desc' do
      subject { described_class.order_iid_desc }

      it { is_expected.to eq([cache_entry3, cache_entry2, cache_entry1].sort_by(&:iid).reverse) }
    end
  end

  describe '.create_or_update_by!' do
    let_it_be(:upstream, freeze: false) { create(upstream_factory) }

    let(:size) { 10.bytes }

    subject(:create_or_update) do
      Tempfile.create('test.txt') do |file|
        file.write('test')
        described_class.create_or_update_by!(
          upstream: upstream,
          group_id: upstream.group_id,
          relative_path: '/test',
          updates: { file: file, size: size, file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f95' }
        )
      end
    end

    context 'with parallel execution' do
      it 'creates or update the existing record' do
        expect { with_threads { create_or_update } }.to change { described_class.count }.by(1)
      end
    end

    context 'with invalid updates' do
      let(:size) { nil }

      it 'bubbles up the error' do
        expect { create_or_update }.to not_change { described_class.count }
          .and raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when the exception has no record' do
      it 'raises the error without retrying' do
        exception = ActiveRecord::RecordInvalid.new

        allow(exception).to receive(:record).and_return(nil)
        allow(described_class).to receive(:default).and_raise(exception)

        expect { create_or_update }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when the record has no errors' do
      it 'raises the error without retrying' do
        errors = instance_double(ActiveModel::Errors, of_kind?: false)
        record = instance_double(described_class, errors: errors)
        exception = ActiveRecord::RecordInvalid.allocate

        allow(exception).to receive(:record).and_return(record)
        allow(described_class).to receive(:default).and_raise(exception)

        expect { create_or_update }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when the record has nil errors' do
      it 'raises the error without retrying' do
        record = instance_double(described_class, errors: nil)
        exception = ActiveRecord::RecordInvalid.allocate

        allow(exception).to receive(:record).and_return(record)
        allow(described_class).to receive(:default).and_raise(exception)

        expect { create_or_update }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when the record has a relative_path taken' do
      it 'retries the transaction' do
        errors = instance_double(ActiveModel::Errors, of_kind?: true)
        record = instance_double(described_class, errors: errors)
        exception = ActiveRecord::RecordInvalid.allocate

        allow(exception).to receive(:record).and_return(record)

        original_method = described_class.method(:default)
        allow(described_class).to receive(:default).and_invoke(
          ->(*_args) { raise exception },
          ->(*args) { original_method.call(*args) }
        )

        expect { create_or_update }.to change { described_class.count }.by(1)
      end
    end
  end

  describe '.search_by_relative_path' do
    let_it_be(:cache_entry, freeze: false) { create(entry_factory) }
    let_it_be(:other_cache_entry) do
      create(entry_factory, relative_path: 'other/path')
    end

    subject { described_class.search_by_relative_path(relative_path) }

    context 'with a matching relative path' do
      let(:relative_path) { cache_entry.relative_path.slice(3, 8) }

      it { is_expected.to contain_exactly(cache_entry) }
    end
  end

  describe '#bump_downloads_count' do
    let_it_be(:cache_entry, freeze: false) { create(entry_factory) }

    subject(:bump) { cache_entry.bump_downloads_count }

    it 'enqueues the update', :sidekiq_inline do
      expect(FlushCounterIncrementsWorker).to receive(:perform_in)
        .with(
          Gitlab::Counters::BufferedCounter::WORKER_DELAY,
          described_class.name,
          cache_entry.id,
          'downloads_count'
        )
        .and_call_original

      expect { bump }.to change { cache_entry.reload.downloads_count }.by(1).and change { cache_entry.downloaded_at }
    end
  end

  describe '#generate_id' do
    let_it_be(:upstream, freeze: false) { create(upstream_factory) }
    let_it_be(:cache_entry, freeze: false) { create(entry_factory, upstream:) }

    let(:expected) { Base64.urlsafe_encode64("#{cache_entry.group_id} #{cache_entry.iid}") }

    subject { cache_entry.generate_id }

    it { is_expected.to eq(expected) }

    context 'for different cache entry' do
      let(:cache_entry2) { create(entry_factory) }

      it { is_expected.not_to eq(cache_entry2.generate_id) }
    end
  end

  context 'with loose foreign key on virtual_registries_packages_maven_cache_remote_entries.upstream_id' do
    it_behaves_like 'update by a loose foreign key' do
      let_it_be(:parent, freeze: false) { create(upstream_factory) }
      let_it_be(:model, freeze: false) { create(entry_factory, upstream: parent) }

      let(:find_model) { described_class.take }
    end
  end

  def with_threads(count: 5, &block)
    return unless block

    # Creates a race condition - structure from https://blog.arkency.com/2015/09/testing-race-conditions/
    wait_for_it = true

    threads = Array.new(count) do
      Thread.new do
        # Each thread must checkout its own connection
        ApplicationRecord.connection_pool.with_connection do
          # A loop to make threads busy until we `join` them
          true while wait_for_it

          yield
        end
      end
    end

    wait_for_it = false
    threads.each(&:join)
  end
end
# rubocop:enable Rails/SaveBang
