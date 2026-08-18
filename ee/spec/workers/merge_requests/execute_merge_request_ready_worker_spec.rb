# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ExecuteMergeRequestReadyWorker, feature_category: :code_suggestions do
  # DEPRECATED: This worker is replaced by
  # Ai::Catalog::Flows::ExecuteMergeRequestReadyWorkflowTriggersWorker
  # which subscribes to the MergeRequests::ReadyEvent CloudEvent.
  #
  # This no-op is kept for one milestone for backward compatability
  # to drain in-flight Sidekiq jobs during rolling deploys.
  # Removal follow up: https://gitlab.com/gitlab-org/gitlab/-/work_items/602537

  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, author: user) }

  let(:event) do
    MergeRequests::DraftStateChangeEvent.new(
      data: { current_user_id: user.id, merge_request_id: merge_request.id }
    )
  end

  it 'handles the event without raising' do
    expect { described_class.new.handle_event(event) }.not_to raise_error
  end
end
