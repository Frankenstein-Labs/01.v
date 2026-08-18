# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['VulnerableDependency'], feature_category: :vulnerability_management do
  it { expect(described_class).to have_graphql_fields(:package, :version) }
end
