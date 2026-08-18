# frozen_string_literal: true

RSpec.shared_examples 'active context code indexing integration' do
  let(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, :ready, active_context_connection: connection)
  end

  let(:project) do
    create(:project, :custom_repo, files: { 'app.rb' => "Line 1\nLine 2\nLine 3" })
  end

  let(:repository) do
    create(
      :ai_active_context_code_repository,
      state: :pending,
      project: project,
      connection_id: connection.id
    )
  end

  context 'when indexing a project' do
    it 'indexes code chunks' do
      Ai::ActiveContext::Code::InitialIndexingService.execute(repository)
      refresh_active_context_indices!

      expect(repository.reload.state).to eq('embedding_indexing_in_progress')
      expect(repository.last_commit).to eq(project.repository.commit.id)
      expect(repository.initial_indexing_last_queued_item).to be_present

      result = search_result
      expect(result.first['project_id']).to eq(project.id)
      expect(result.first).to have_key('path')
      expect(result.first).to have_key('content')
    end
  end

  context 'when updating a file in an indexed project' do
    it 'updates indexed chunks and removes orphaned data' do
      Ai::ActiveContext::Code::InitialIndexingService.execute(repository)
      refresh_active_context_indices!

      content = search_result.first['content']
      expect(content).to include('Line 1')
      expect(content).to include('Line 2')
      expect(content).to include('Line 3')

      new_content = "Line 1\nLine 3\nLine 4"
      project.repository.commit_files(
        project.owner,
        branch_name: project.repository.root_ref,
        message: 'Update app.rb',
        actions: [{ action: :update, file_path: 'app.rb', content: new_content }]
      )

      Ai::ActiveContext::Code::IncrementalIndexingService.execute(repository)
      refresh_active_context_indices!

      expect(repository.reload.last_commit).to eq(project.repository.commit.id)

      updated_content = search_result.first['content']
      expect(updated_content).to include('Line 1')
      expect(updated_content).not_to include('Line 2')
      expect(updated_content).to include('Line 3')
      expect(updated_content).to include('Line 4')
    end
  end

  context 'when deleting a project repository' do
    let(:project2) do
      create(:project, :custom_repo, files: { 'other.rb' => "Other Line 1\nOther Line 2" })
    end

    let(:repository2) do
      create(
        :ai_active_context_code_repository,
        state: :pending,
        project: project2,
        connection_id: connection.id
      )
    end

    it 'removes all indexed content for the deleted project' do
      Ai::ActiveContext::Code::InitialIndexingService.execute(repository)
      Ai::ActiveContext::Code::InitialIndexingService.execute(repository2)
      refresh_active_context_indices!

      expect(search_result(project.id).count).to be > 0
      expect(search_result(project2.id).count).to be > 0

      Ai::ActiveContext::Code::Deleter.run!(repository)
      refresh_active_context_indices!

      expect(search_result(project.id).count).to eq(0)
      expect(search_result(project2.id).count).to be > 0
    end
  end

  context 'when embeddings are enqueued and processed' do
    it 'transitions repository from embedding_indexing_in_progress to ready' do
      Ai::ActiveContext::Code::InitialIndexingService.execute(repository)
      refresh_active_context_indices!

      expect(repository.reload.state).to eq('embedding_indexing_in_progress')

      last_queued_item = repository.initial_indexing_last_queued_item
      allow(Ai::ActiveContext::Collections::Code).to receive_messages(
        indexing?: true,
        search: ['id' => last_queued_item, 'embeddings_v1' => double]
      )

      Ai::ActiveContext::Code::MarkRepositoryAsReadyEventWorker.new.handle_event(nil)

      expect(repository.reload.state).to eq('ready')
    end
  end

  def search_result(project_id = project.id)
    Ai::ActiveContext::Collections::Code.search(
      user: nil,
      query: ::ActiveContext::Query.filter(project_id: project_id)
    )
  end
end
