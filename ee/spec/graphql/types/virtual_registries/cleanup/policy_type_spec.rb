# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['VirtualRegistryCleanupPolicy'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) do
    %i[enabled
      next_run_at
      last_run_at
      last_run_deleted_size
      last_run_deleted_entries_count
      keep_n_days_after_download
      status
      cadence
      notify_on_success
      notify_on_failure
      failure_message
      last_run_detailed_metrics
      created_at
      updated_at]
  end

  it { is_expected.to require_graphql_authorizations(:admin_virtual_registry) }
  it { is_expected.to have_graphql_fields(fields) }
end
