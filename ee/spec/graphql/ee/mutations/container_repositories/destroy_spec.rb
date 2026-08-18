# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ContainerRepositories::Destroy, feature_category: :container_registry do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:container_repository) { create(:container_repository) }
  let_it_be(:current_user) { create(:user) }

  describe '#resolve' do
    subject do
      described_class.new(object: nil, context: query_context, field: nil)
                     .resolve(id: container_repository.to_global_id)
    end

    before do
      container_repository.project.send(:add_maintainer, current_user)
    end

    include_examples 'audit event logging' do
      let(:operation) { subject }
      let(:event_type) { 'container_repository_deletion_marked' }
      let(:fail_condition!) do
        # rubocop:disable RSpec/AnyInstanceOf -- not next instance
        allow_any_instance_of(ContainerRepository).to receive(:delete_scheduled!).and_return(false)
        # rubocop:enable RSpec/AnyInstanceOf
      end

      let(:author) { current_user }

      let(:attributes) do
        {
          author_id: author.id,
          entity_id: container_repository.project.id,
          entity_type: 'Project',
          details: {
            event_name: "container_repository_deletion_marked",
            author_class: author.class.to_s,
            author_name: author.name,
            custom_message: "Marked container repository #{container_repository.id} for deletion",
            target_details: container_repository.name,
            target_id: container_repository.id,
            target_type: container_repository.class.to_s
          }
        }
      end
    end
  end
end
