# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::Helpers::InvalidUserErrorEvent, feature_category: :activation do
  subject(:helper) { Class.new.include(described_class).new }

  it 'tracks the event' do
    helper.track_invalid_user_error('free_registration')

    expect_snowplow_event(
      category: 'Gitlab::Tracking::Helpers::InvalidUserErrorEvent',
      action: 'track_free_registration_error',
      label: 'failed_creating_user'
    )
  end
end
