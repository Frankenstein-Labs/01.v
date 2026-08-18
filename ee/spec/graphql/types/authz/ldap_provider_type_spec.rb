# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['LdapProvider'], feature_category: :permissions do
  it { expect(described_class.graphql_name).to eq('LdapProvider') }

  describe 'fields' do
    let(:fields) { %i[id label] }

    it { expect(described_class).to have_graphql_fields(fields) }
  end
end
