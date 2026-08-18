# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::DeleteContainerRepositoryWorker, :aggregate_failures, feature_category: :container_registry do
  let_it_be_with_reload(:container_repository) { create(:container_repository) }

  let(:worker) { described_class.new }

  before do
    stub_container_registry_config(enabled: true)

    stub_container_registry_tags(
      repository: container_repository.path,
      tags: []
    )
  end

  describe '#perform_work' do
    before do
      container_repository.delete_scheduled!
    end

    include_examples 'audit event logging' do
      let(:operation) { worker.perform_work }
      let(:event_type) { 'container_repository_deleted' }
      let(:fail_condition!) do
        allow(ContainerRepository).to receive(:next_pending_destruction).and_return(nil)
      end

      let(:author) { ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)') }

      let(:attributes) do
        {
          author_id: author.id,
          entity_id: container_repository.project.id,
          entity_type: 'Project',
          details: {
            event_name: "container_repository_deleted",
            author_class: author.class.to_s,
            author_name: author.name,
            custom_message: "Container repository #{container_repository.id} deleted by worker",
            target_details: container_repository.name,
            target_id: container_repository.id,
            target_type: container_repository.class.to_s
          }
        }
      end
    end
  end
end
