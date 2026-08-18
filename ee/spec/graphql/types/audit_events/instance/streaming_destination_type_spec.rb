# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['InstanceAuditEventStreamingDestination'], feature_category: :audit_events do
  let(:fields) do
    %i[id name category config event_type_filters namespace_filters secret_token active]
  end

  specify { expect(described_class.graphql_name).to eq('InstanceAuditEventStreamingDestination') }
  specify { expect(described_class).to have_graphql_fields(fields) }
  specify { expect(described_class).to require_graphql_authorizations(:admin_instance_external_audit_events) }
end
