# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiSubscriptionsProject'], feature_category: :source_code_management do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[id downstream_project upstream_project author] }

  it { is_expected.to have_graphql_fields(fields) }
end
