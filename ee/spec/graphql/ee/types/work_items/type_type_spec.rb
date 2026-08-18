# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::TypeType, feature_category: :team_planning do
  it { expect(described_class).to have_graphql_field(:enabled_by_default_for_new_namespaces) }
end
