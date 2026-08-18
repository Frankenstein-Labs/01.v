# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteWorkItemCreatedWorkflowTriggersWorker, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:work_item) { create(:work_item, project: project, author: user) }
  let_it_be(:service_account) { create(:service_account) }
  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger,
      project: project,
      user: service_account,
      event_types: [Ai::FlowTrigger::EVENT_TYPES[:work_item]]
    )
  end

  let(:cloud_event) do
    WorkItems::CreatedEvent.build(
      work_item: work_item,
      current_user: user
    )
  end

  let(:resource) { work_item }
  let(:event) { cloud_event }

  let(:wrong_event) do
    WorkItems::WorkItemCreatedEvent.new(
      data: {
        id: work_item.id,
        namespace_id: work_item.namespace_id
      }
    )
  end

  let(:doomed_resource) { create(:work_item, project: project, author: user) }

  let(:doomed_resource_event) do
    WorkItems::CreatedEvent.build(work_item: doomed_resource, current_user: user)
  end

  it_behaves_like 'subscribes to event'
  it_behaves_like 'a cloud events flow trigger worker'
end
