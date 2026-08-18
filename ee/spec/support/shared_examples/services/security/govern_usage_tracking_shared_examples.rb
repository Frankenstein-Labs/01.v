# frozen_string_literal: true

RSpec.shared_examples_for 'tracks govern usage event' do |page_name|
  it 'tracks unique event' do
    # allow other method calls in addition to the expected one
    allow(Gitlab::InternalEvents).to receive(:track_event).with(any_args)

    expect(Gitlab::InternalEvents).to receive(:track_event)
      .with('user_perform_visit', hash_including(additional_properties: hash_including(page_name: page_name)))

    request
  end
end

RSpec.shared_examples_for "doesn't track govern usage event" do |page_name|
  it "doesn't tracks event" do
    expect(Gitlab::InternalEvents).not_to receive(:track_event)
      .with(hash_including(additional_properties: hash_including(page_name: page_name)), any_args)

    request
  end
end

RSpec.shared_examples_for 'tracks govern usage service event' do |event_name|
  include_examples 'tracks govern usage event', event_name do
    let(:request) { execute }
  end
end

RSpec.shared_examples_for "doesn't track govern usage service event" do |event_name|
  include_examples "doesn't track govern usage event", event_name do
    let(:request) { execute }
  end
end
