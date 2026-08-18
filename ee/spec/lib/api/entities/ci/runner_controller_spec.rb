# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Ci::RunnerController, feature_category: :continuous_integration do
  let_it_be(:controller) { create(:ci_runner_controller, :enabled) }

  subject(:entity) { described_class.new(controller).as_json }

  it 'includes basic fields' do
    is_expected.to include(
      id: controller.id,
      description: controller.description,
      state: controller.state,
      created_at: controller.created_at,
      updated_at: controller.updated_at
    )
  end

  it 'exposes the state field' do
    expect(entity[:state]).to eq('enabled')
  end

  context 'when state is disabled' do
    let_it_be(:controller) { create(:ci_runner_controller) }

    it 'exposes the state field as disabled' do
      expect(entity[:state]).to eq('disabled')
    end
  end

  context 'when state is dry_run' do
    let_it_be(:controller) { create(:ci_runner_controller, :dry_run) }

    it 'exposes the state field as dry_run' do
      expect(entity[:state]).to eq('dry_run')
    end
  end
end
