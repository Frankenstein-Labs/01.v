# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CleanupPolicyLastRunUpstreamMetrics'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[deleted_entries_count deleted_size] }

  it { is_expected.to have_graphql_fields(fields) }
end
