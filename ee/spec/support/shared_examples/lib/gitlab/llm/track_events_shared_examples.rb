# frozen_string_literal: true

RSpec.shared_examples 'tracks events for AI requests' do |prompt_size, response_size, label: 'chat', klass: nil|
  it 'tracks a snowplow event' do
    subject

    expect_snowplow_event(
      category: klass || described_class.to_s,
      action: 'tokens_per_user_request_prompt',
      property: 'uuid',
      label: label,
      user: user,
      value: prompt_size
    )

    expect_snowplow_event(
      category: klass || described_class.to_s,
      action: 'tokens_per_user_request_response',
      property: 'uuid',
      label: label,
      user: user,
      value: response_size
    )
  end
end

RSpec.shared_examples 'tracks embedding events for AI requests' do |token_size|
  it 'tracks a snowplow event' do
    subject

    expect_snowplow_event(
      category: described_class.to_s,
      action: 'tokens_per_embedding',
      property: 'uuid',
      label: 'chat',
      user: user,
      value: token_size
    )
  end
end
