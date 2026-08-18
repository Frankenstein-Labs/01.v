# frozen_string_literal: true

RSpec.shared_examples 'pushes dedicated feature' do |feature_name|
  it "pushes #{feature_name} as Dedicated feature" do
    allow(controller).to receive(:push_dedicated_feature)

    subject

    expect(controller).to have_received(:push_dedicated_feature).with(feature_name)
  end
end
