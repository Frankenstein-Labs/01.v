# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ContainerRepository::DeleteTagsService, feature_category: :container_registry do
  describe '#resolve' do
    using RSpec::Parameterized::TableSyntax

    include_context 'container repository delete tags service shared context'

    let(:tags) { %w[a b c] }
    let(:subject) { described_class.new(project, user, params) }

    before do
      allow(repository.client).to receive(:supports_tag_delete?).and_return(true)
      stub_delete_reference_requests(tags)
      project.add_developer(user)
    end

    context 'with audit event logging' do
      let(:operation) { subject.execute(repository) }
      let(:event_type) { 'container_repository_tags_deleted' }
      let(:fail_condition!) do
        allow_next_instance_of(::Projects::ContainerRepository::Gitlab::DeleteTagsService) do |instance|
          allow(instance).to receive(:execute).and_return({ status: :error })
        end
      end

      let(:author) { user }

      let(:attributes) do
        {
          author_id: author.id,
          entity_id: repository.project.id,
          entity_type: 'Project',
          details: {
            event_name: "container_repository_tags_deleted",
            author_class: author.class.to_s,
            author_name: author.name,
            custom_message: "Container repository tags marked for deletion: #{tags.join(', ')}",
            target_details: repository.name,
            target_id: repository.id,
            target_type: repository.class.to_s
          }
        }
      end

      it_behaves_like 'audit event logging'

      context 'without user' do
        let_it_be(:user) { nil }
        let(:params) { { tags: tags, container_expiration_policy: true } }

        let(:author) { ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)') }

        it_behaves_like 'audit event logging'
      end
    end
  end
end
