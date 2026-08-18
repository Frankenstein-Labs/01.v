# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::TaskSerializerService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be(:task) { create(:zoekt_task, node: node) }

  let(:service) { described_class.new(task, node) }

  subject(:execute_task) { service.execute }

  describe '.execute' do
    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(task, node).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(task, node)
    end
  end

  describe '#execute' do
    let(:project) { task.zoekt_repository.project }
    let(:empty_repo) { false }

    before do
      allow(project).to receive(:self_or_ancestors_archived?).and_return(true)
      allow(::Search::Zoekt).to receive(:missing_repo?).with(project).and_return(empty_repo)
    end

    it 'serializes the task with GitalyConnectionInfo' do
      allow(::Search::Zoekt::Settings).to receive_messages(file_size_limit: 100, indexing_timeout: 1.hour)
      response = execute_task
      expect(response[:name]).to eq(:index)
      payload = execute_task[:payload]
      expect(payload.keys).to contain_exactly(
        :GitalyConnectionInfo,
        :Callback,
        :RepoID,
        :ProjectFullPath,
        :FileSizeLimit,
        :Timeout,
        :Parallelism,
        :FileCountLimit,
        :TrigramMax,
        :MissingRepo,
        :Metadata
      )
      expect(payload[:FileSizeLimit]).to eq(100)
      expect(payload[:Timeout]).to eq("#{1.hour.to_i}s")
      expect(payload[:TrigramMax]).to eq(::Gitlab::CurrentSettings.zoekt_trigram_max)
      expect(payload[:ProjectFullPath]).to eq(project.path_with_namespace)

      meta = payload[:Metadata]
      expect(meta[:project_id]).to eq(project.id.to_s)
      expect(meta[:traversal_ids]).to eq(project.namespace_ancestry)
      expect(meta[:visibility_level]).to eq(project.visibility_level.to_s)
      expect(meta[:repository_access_level]).to eq(project.repository_access_level.to_s)
      expect(meta[:forked]).to eq("f")
      expect(meta[:archived]).to eq("t")
    end

    it 'sets MissingRepo to false' do
      expect(execute_task[:payload][:MissingRepo]).to be false
    end

    context 'when repo does not exist' do
      let(:empty_repo) { true }

      it 'serializes the task without GitalyConnectionInfo' do
        expect(execute_task[:name]).to eq(:index)
        expect(execute_task[:payload].keys).to contain_exactly(
          :Callback,
          :RepoID,
          :ProjectFullPath,
          :FileSizeLimit,
          :Timeout,
          :Parallelism,
          :FileCountLimit,
          :TrigramMax,
          :MissingRepo,
          :Metadata
        )

        meta = execute_task[:payload][:Metadata]
        expect(meta[:project_id]).to eq(project.id.to_s)
        expect(meta[:traversal_ids]).to eq(project.namespace_ancestry)
        expect(meta[:visibility_level]).to eq(project.visibility_level.to_s)
        expect(meta[:repository_access_level]).to eq(project.repository_access_level.to_s)
        expect(meta[:forked]).to eq("f")
        expect(meta[:archived]).to eq("t")
      end

      it 'sets MissingRepo to true' do
        expect(execute_task[:payload][:MissingRepo]).to be true
      end
    end

    context 'when local socket is used' do
      let(:connection_data) { { "address" => "unix:gdk-ee/praefect.socket", "token" => nil } }

      before do
        allow(Gitlab::GitalyClient).to receive(:connection_data).and_return(connection_data)
      end

      it 'transforms unix socket' do
        expected_path = "unix:#{Rails.root.join('gdk-ee/praefect.socket')}"
        expect(execute_task[:payload][:GitalyConnectionInfo][:Address]).to eq(expected_path)
      end
    end

    context 'with :force_index_repo task' do
      let(:task) { create(:zoekt_task, task_type: :force_index_repo) }

      it 'serializes the task' do
        expect(execute_task[:name]).to eq(:index)
        expect(execute_task[:payload].keys).to contain_exactly(
          :GitalyConnectionInfo,
          :Callback,
          :RepoID,
          :ProjectFullPath,
          :FileSizeLimit,
          :Timeout,
          :Force,
          :Parallelism,
          :FileCountLimit,
          :TrigramMax,
          :MissingRepo,
          :Metadata
        )
      end
    end

    context 'with :delete_repo task' do
      let(:task) { create(:zoekt_task, task_type: :delete_repo) }

      it 'serializes the task' do
        expect(execute_task[:name]).to eq(:delete)
        expect(execute_task[:payload].keys).to contain_exactly(:RepoID, :Callback)
        expect(execute_task[:payload][:RepoID]).to eq(task.project_identifier)
      end
    end

    context 'with unknown task' do
      let(:task) { create(:zoekt_task) }

      before do
        allow(task).to receive(:task_type).and_return(:unknown)
      end

      it 'raises an exception' do
        expect { execute_task }.to raise_error(ArgumentError)
      end
    end
  end
end
