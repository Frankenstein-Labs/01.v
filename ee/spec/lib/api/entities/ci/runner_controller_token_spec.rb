# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Ci::RunnerControllerToken, feature_category: :continuous_integration do
  let_it_be(:token) { create(:ci_runner_controller_token, :recently_used) }

  subject(:as_json) { described_class.new(token).as_json }

  it 'includes basic fields' do
    expect(as_json).to eq({
      id: token.id,
      runner_controller_id: token.runner_controller_id,
      description: token.description,
      last_used_at: token.last_used_at,
      created_at: token.created_at,
      updated_at: token.updated_at
    })
  end

  context 'when last_used_at is nil' do
    let_it_be(:token) { create(:ci_runner_controller_token, :unused) }

    it { is_expected.to include(last_used_at: nil) }
  end
end
