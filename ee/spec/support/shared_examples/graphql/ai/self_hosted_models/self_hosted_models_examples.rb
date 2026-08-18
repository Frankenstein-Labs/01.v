# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'performs the right authorization' do
  it 'performs the right authorization correctly' do
    allow(Ability).to receive(:allowed?).and_call_original
    expect(Ability).to receive(:allowed?).with(current_user, :manage_self_hosted_models_settings)

    request
  end
end
