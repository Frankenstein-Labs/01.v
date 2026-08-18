# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GroupAuditEventNamespaceFilter'], feature_category: :audit_events do
  let(:fields) do
    %i[id namespace external_streaming_destination]
  end

  specify { expect(described_class.graphql_name).to eq('GroupAuditEventNamespaceFilter') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end
