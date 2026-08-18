# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::FlowTriggers::Update, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiFlowTriggerUpdate') }

  it { expect(described_class).to require_graphql_authorizations(:manage_ai_flow_triggers) }

  it { is_expected.to have_graphql_fields(:ai_flow_trigger, :errors, :client_mutation_id) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :id,
      :user_id,
      :description,
      :event_types,
      :config_path,
      :ai_catalog_item_consumer_id,
      :filter,
      :client_mutation_id
    )
  end
end
