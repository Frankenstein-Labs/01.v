# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GroupAuditEventStreamingDestination'], feature_category: :audit_events do
  let(:fields) do
    %i[id name group category config event_type_filters namespace_filters secret_token active]
  end

  specify { expect(described_class.graphql_name).to eq('GroupAuditEventStreamingDestination') }
  specify { expect(described_class).to have_graphql_fields(fields) }
  specify { expect(described_class).to require_graphql_authorizations(:admin_external_audit_events) }
end
