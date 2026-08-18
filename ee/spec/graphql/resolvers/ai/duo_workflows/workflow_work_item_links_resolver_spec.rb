# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::DuoWorkflows::WorkflowWorkItemLinksResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  it_behaves_like 'a workflow links resolver',
    type: Types::Ai::DuoWorkflows::WorkflowWorkItemLinkType,
    association: :work_item_links
end
