# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::DuoWorkflows::NoteDuoWorkflowLinksResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  it_behaves_like 'a workflow links resolver',
    type: Types::Ai::DuoWorkflows::WorkflowNoteLinkType,
    association: :duo_workflow_links
end
