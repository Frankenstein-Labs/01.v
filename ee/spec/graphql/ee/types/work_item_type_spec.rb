# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WorkItem'], feature_category: :team_planning do
  include GraphqlHelpers

  it { expect(described_class).to have_graphql_field(:promotedToEpicUrl) }
  it { expect(described_class).to have_graphql_field(:duoWorkflowLinks) }
end
