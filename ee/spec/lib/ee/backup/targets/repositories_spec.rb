# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Backup::Targets::Repositories, feature_category: :backup_restore do
  let(:progress) { instance_double(StringIO, puts: nil, print: nil) }
  let(:strategy) { instance_double(Backup::GitalyBackup, start: nil, enqueue: nil, finish!: nil) }
  let(:storages) { [] }
  let(:paths) { [] }
  let(:destination) { 'repositories' }
  let(:backup_id) { 'backup_id' }
  let(:backup_options) { Backup::Options.new }

  subject(:repositories) do
    described_class.new(progress, strategy: strategy, options: backup_options, storages: storages, paths: paths)
  end

  describe '#dump' do
    let_it_be(:project) { create(:project, :small_repo) }
    let_it_be(:groups) { create_list(:group, 5, :wiki_repo) }

    it 'calls enqueue for each repository type', :aggregate_failures do
      repositories.dump(destination, backup_id)

      expect(strategy).to have_received(:start).with(:create, destination, backup_id: backup_id)
      expect(strategy).to have_received(:enqueue).with(project, Gitlab::GlRepository::PROJECT)
      groups.each do |group|
        expect(strategy).to have_received(:enqueue).with(group, Gitlab::GlRepository::WIKI)
      end
      expect(strategy).to have_received(:finish!)
    end

    describe 'command failure' do
      it 'enqueue_group raises an error' do
        allow(strategy).to receive(:enqueue).with(anything, Gitlab::GlRepository::WIKI).and_raise(IOError)

        expect { repositories.dump(destination, backup_id) }.to raise_error(IOError)
      end

      it 'group query raises an error' do
        allow(Group).to receive_message_chain(:includes, :find_each).and_raise(ActiveRecord::StatementTimeout)

        expect { repositories.dump(destination, backup_id) }.to raise_error(ActiveRecord::StatementTimeout)
      end
    end

    it 'avoids N+1 database queries' do
      control = ActiveRecord::QueryRecorder.new do
        repositories.dump(destination, backup_id)
      end

      create_list(:group, 2, :wiki_repo)

      expect do
        repositories.dump(destination, backup_id)
      end.not_to exceed_query_limit(control)
    end

    context 'for storages' do
      let(:storages) { %w[default] }

      before do
        stub_storage_settings('test_second_storage' => {})
      end

      it 'calls enqueue for all repositories on the specified storage', :aggregate_failures do
        excluded_group = create(:group, :wiki_repo)
        excluded_group.group_wiki_repository.update!(shard_name: 'test_second_storage')

        repositories.dump(destination, backup_id)

        expect(strategy).to have_received(:start).with(:create, destination, backup_id: backup_id)
        expect(strategy).to have_received(:enqueue).with(project, Gitlab::GlRepository::PROJECT)
        expect(strategy).not_to have_received(:enqueue).with(excluded_group, Gitlab::GlRepository::WIKI)
        groups.each do |group|
          expect(strategy).to have_received(:enqueue).with(group, Gitlab::GlRepository::WIKI)
        end
        expect(strategy).to have_received(:finish!)
      end
    end
  end

  describe '#restore' do
    let_it_be(:project) { create(:project, :small_repo) }
    let_it_be(:group) { create(:group, :wiki_repo) }

    it 'calls enqueue for each repository type', :aggregate_failures do
      repositories.restore(destination, backup_id)

      expect(strategy).to have_received(:start).with(
        :restore,
        destination,
        remove_all_repositories: %w[default],
        backup_id: backup_id
      )
      expect(strategy).to have_received(:enqueue).with(project, Gitlab::GlRepository::PROJECT)
      expect(strategy).to have_received(:enqueue).with(group, Gitlab::GlRepository::WIKI)
      expect(strategy).to have_received(:finish!)
    end

    context 'for storages' do
      let(:storages) { %w[default] }

      before do
        stub_storage_settings('test_second_storage' => {})
      end

      it 'calls enqueue for all repositories on the specified storage', :aggregate_failures do
        excluded_group = create(:group, :wiki_repo)
        excluded_group.group_wiki_repository.update!(shard_name: 'test_second_storage')

        repositories.restore(destination, backup_id)

        expect(strategy).to have_received(:start).with(
          :restore,
          destination,
          remove_all_repositories: %w[default],
          backup_id: backup_id
        )
        expect(strategy).not_to have_received(:enqueue).with(excluded_group, Gitlab::GlRepository::WIKI)
        expect(strategy).to have_received(:enqueue).with(project, Gitlab::GlRepository::PROJECT)
        expect(strategy).to have_received(:enqueue).with(group, Gitlab::GlRepository::WIKI)
        expect(strategy).to have_received(:finish!)
      end
    end

    context 'for paths' do
      let(:paths) { [group.full_path] }

      it 'calls enqueue for all descendant repositories on the specified group', :aggregate_failures do
        repositories.restore(destination, backup_id)

        expect(strategy).to have_received(:start).with(
          :restore,
          destination,
          remove_all_repositories: nil,
          backup_id: backup_id
        )
        expect(strategy).not_to have_received(:enqueue).with(project, Gitlab::GlRepository::PROJECT)
        expect(strategy).to have_received(:enqueue).with(group, Gitlab::GlRepository::WIKI)
        expect(strategy).to have_received(:finish!)
      end
    end
  end
end
