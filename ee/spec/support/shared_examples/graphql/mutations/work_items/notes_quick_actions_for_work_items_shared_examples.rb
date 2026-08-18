# frozen_string_literal: true

RSpec.shared_examples 'work item supports weights widget updates via quick actions' do
  let(:body) { "/clear_weight" }

  before do
    noteable.update!(weight: 2)
  end

  it 'updates the work item' do
    expect do
      post_graphql_mutation(mutation, current_user: current_user)
      noteable.reload
    end.to change { noteable.weight }.from(2).to(nil)
  end
end

RSpec.shared_examples 'work item does not support weights widget updates via quick actions' do
  let(:body) { "Updating weight.\n/weight 1" }

  before do
    stub_all_work_item_widgets(weight: false)
  end

  it 'ignores the quick action' do
    expect do
      post_graphql_mutation(mutation, current_user: current_user)
      noteable.reload
    end.not_to change { noteable.weight }
  end
end

RSpec.shared_examples 'work item supports health status widget updates via quick actions' do
  let(:body) { "/health_status on_track" }

  before do
    noteable.update!(health_status: nil)
  end

  it 'updates work item health status' do
    expect do
      post_graphql_mutation(mutation, current_user: current_user)
      noteable.reload
    end.to change { noteable.health_status }.from(nil).to('on_track')
  end
end

RSpec.shared_examples 'work item does not support health status widget updates via quick actions' do
  let(:body) { "Updating health status.\n/health_status on_track" }

  before do
    stub_all_work_item_widgets(health_status: false)
    noteable.update!(health_status: nil)
  end

  it 'ignores the quick action' do
    expect do
      post_graphql_mutation(mutation, current_user: current_user)
      noteable.reload
    end.not_to change { noteable.health_status }
  end
end

RSpec.shared_examples 'work item supports promotion via quick actions' do
  context 'with /promote_to quick command' do
    context 'when param is Epic' do
      let(:body) { "Updating type.\n/promote_to epic" }

      shared_examples 'failed promote command' do
        specify do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            noteable.reload
          end.to not_change { WorkItem.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['quickActionsStatus']['messages'])
            .to include("Failed to promote this work item: #{error_message}.")
        end
      end

      it 'promotes issue to epic' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
          noteable.reload
        end.to change { noteable.state }.from('opened').to('closed')
           .and change { WorkItem.count }.by(1)

        new_work_item_epic = WorkItem.last
        expect(noteable.promoted_to_epic_id).to eq(new_work_item_epic.synced_epic.id)
        expect(response).to have_gitlab_http_status(:success)
      end

      context 'when issue cannot be promoted to an epic' do
        let(:error_message) { 'Provided type is not supported' }

        before do
          noteable.update!(promoted_to_epic_id: create(:epic).id)
        end

        it_behaves_like 'failed promote command'
      end

      context 'with PromoteError exceptions' do
        let(:error_message) { 'some error' }

        before do
          allow_next_instance_of(::WorkItems::LegacyEpics::IssuePromoteService) do |instance|
            allow(instance).to receive(:execute).and_raise(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError,
              error_message)
          end
        end

        it_behaves_like 'failed promote command'
      end
    end
  end
end
