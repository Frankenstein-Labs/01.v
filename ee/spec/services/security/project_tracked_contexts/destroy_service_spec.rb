# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::DestroyService, feature_category: :vulnerability_management do
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :small_repo, maintainers: maintainer) }

  let!(:tracked_context) do
    create(:security_project_tracked_context, :tracked,
      project: project,
      context_name: 'feature-branch',
      context_type: :branch,
      is_default: false)
  end

  let(:service) do
    described_class.new(
      tracked_context: tracked_context,
      current_user: maintainer
    )
  end

  subject(:result) { service.execute }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  context 'when destroying tracked context' do
    it 'destroys tracked context successfully' do
      expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
      expect(result).to be_success
      expect(result.payload[:tracked_context]).to eq(tracked_context)
    end

    context 'when destroy fails' do
      before do
        allow(tracked_context).to receive_messages(destroy: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Validation failed']))
      end

      it 'handles destroy failure' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Validation failed')
      end

      it 'does not enqueue the Elasticsearch delete worker' do
        expect(::Search::Elastic::DeleteWorker).not_to receive(:perform_async)

        result
      end
    end

    describe 'Elasticsearch cleanup' do
      it 'enqueues the delete worker with the tracked context scope' do
        expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with(
          'task' => 'delete_tracked_context_sbom_occurrences',
          'project_id' => tracked_context.project_id,
          'security_project_tracked_context_id' => tracked_context.id
        )

        result
      end
    end

    context 'when tracked context is default branch' do
      let!(:tracked_context) do
        create(:security_project_tracked_context, :tracked,
          project: project,
          context_name: project.default_branch,
          context_type: :branch,
          is_default: true)
      end

      it 'prevents deletion of default branch' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Cannot untrack default branch')
      end
    end
  end
end
