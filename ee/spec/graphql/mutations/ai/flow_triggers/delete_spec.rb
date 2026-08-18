# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::FlowTriggers::Delete, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiFlowTriggerDelete') }

  it { expect(described_class).to require_graphql_authorizations(:manage_ai_flow_triggers) }

  it { is_expected.to have_graphql_fields(:errors, :client_mutation_id) }

  it { is_expected.to have_graphql_arguments(:id, :client_mutation_id) }
end
