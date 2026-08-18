# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ExternalAuditEventDestination'], feature_category: :audit_events do
  let(:fields) do
    %i[id destination_url group verification_token headers event_type_filters name namespace_filter active]
  end

  specify { expect(described_class.graphql_name).to eq('ExternalAuditEventDestination') }
  specify { expect(described_class).to have_graphql_fields(fields) }
  specify { expect(described_class).to require_graphql_authorizations(:admin_external_audit_events) }
end
