# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::DuoWorkflows::WorkflowMergeRequestLinksResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  it_behaves_like 'a workflow links resolver',
    type: Types::Ai::DuoWorkflows::WorkflowMergeRequestLinkType,
    association: :merge_request_links
end
