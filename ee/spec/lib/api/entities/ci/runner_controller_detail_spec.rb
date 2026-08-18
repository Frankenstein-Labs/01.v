# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Ci::RunnerControllerDetail, feature_category: :continuous_integration do
  let_it_be(:controller) { create(:ci_runner_controller, :enabled) }

  subject(:as_json) { described_class.new(controller).as_json }

  it 'includes all base runner controller fields' do
    is_expected.to include(
      id: controller.id,
      description: controller.description,
      state: controller.state,
      created_at: controller.created_at,
      updated_at: controller.updated_at
    )
  end

  it { is_expected.to have_key(:connected) }

  context 'when controller has a recently used active token' do
    before do
      create(:ci_runner_controller_token, :recently_used, runner_controller: controller)
    end

    it 'reports connected as true' do
      is_expected.to include(connected: true)
    end
  end

  context 'when controller has no recently used tokens' do
    before do
      create(:ci_runner_controller_token, :not_recently_used, runner_controller: controller)
    end

    it 'reports connected as false' do
      is_expected.to include(connected: false)
    end
  end

  context 'when controller has no tokens' do
    it 'reports connected as false' do
      is_expected.to include(connected: false)
    end
  end
end
