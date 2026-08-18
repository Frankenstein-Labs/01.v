# frozen_string_literal: true

RSpec.shared_examples 'pushes saas feature' do |feature_name|
  it "pushes #{feature_name} as SaaS feature" do
    allow(controller).to receive(:push_saas_feature)

    subject

    expect(controller).to have_received(:push_saas_feature).with(feature_name)
  end
end
