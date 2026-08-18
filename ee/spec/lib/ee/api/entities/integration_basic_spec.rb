# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::API::Entities::IntegrationBasic, feature_category: :continuous_integration do
  let_it_be(:integration) { create(:jenkins_integration) }

  let(:entity) do
    API::Entities::IntegrationBasic.new(integration)
  end

  subject(:representation) { entity.as_json }

  it 'exposes vulnerability_events' do
    expect(representation[:vulnerability_events]).to eq(integration.vulnerability_events)
  end
end
