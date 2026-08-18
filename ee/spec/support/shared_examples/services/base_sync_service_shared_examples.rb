# frozen_string_literal: true

RSpec.shared_examples 'geo base sync execution' do
  describe '#execute' do
    let(:project) { build('project') }

    context 'when can acquire exclusive lease' do
      before do
        exclusive_lease = double(:exclusive_lease, try_obtain: 12345)
        expect(subject).to receive(:exclusive_lease).and_return(exclusive_lease)
      end

      it 'executes the synchronization' do
        expect(subject).to receive(:sync_repository)

        subject.execute
      end
    end

    context 'when exclusive lease is not acquired' do
      before do
        exclusive_lease = double(:exclusive_lease, try_obtain: nil)
        expect(subject).to receive(:exclusive_lease).and_return(exclusive_lease)
      end

      it 'is does not execute synchronization' do
        expect(subject).not_to receive(:sync_repository)

        subject.execute
      end
    end
  end
end

RSpec.shared_examples 'geo base sync fetch' do
  describe '#sync_repository' do
    it 'tells registry that sync will start now' do
      registry = subject.send(:registry)
      allow_any_instance_of(registry.class).to receive(:start_sync!)

      subject.send(:sync_repository)
    end
  end

  describe '#fetch_repository' do
    let(:fetch_repository) { subject.send(:fetch_repository) }

    before do
      allow(subject).to receive(:fetch_geo_mirror).and_return(true)
      allow(subject).to receive(:clone_geo_mirror).and_return(true)
      allow(repository).to receive(:update_root_ref)
    end

    it 'syncs the HEAD ref' do
      expect(repository).to receive(:update_root_ref)

      fetch_repository
    end

    context 'with existing repository' do
      it 'fetches repository from geo node' do
        subject.send(:ensure_repository)

        is_expected.to receive(:fetch_geo_mirror)

        fetch_repository
      end
    end

    context 'with a never synced repository' do
      it 'clones repository from geo node' do
        allow(repository).to receive(:exists?).and_return(false)

        is_expected.to receive(:clone_geo_mirror)

        fetch_repository
      end
    end
  end
end
