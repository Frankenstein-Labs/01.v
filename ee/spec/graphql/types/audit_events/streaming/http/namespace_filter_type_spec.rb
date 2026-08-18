# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AuditEventStreamingHTTPNamespaceFilter'], feature_category: :audit_events do
  let(:fields) do
    %i[id namespace external_audit_event_destination]
  end

  specify { expect(described_class.graphql_name).to eq('AuditEventStreamingHTTPNamespaceFilter') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end
