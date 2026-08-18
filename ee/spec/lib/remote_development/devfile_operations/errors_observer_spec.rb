# frozen_string_literal: true

require "fast_spec_helper"

# rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
RSpec.describe RemoteDevelopment::DevfileOperations::ErrorsObserver, feature_category: :workspaces do
  let(:user) { instance_double("User") }
  let(:internal_events_class) { class_double("Gitlab::InternalEvents") }
  let(:event_name) { "devfile_validate_result" }
  let(:label) { "failed" }
  let(:category) { described_class.to_s }
  let(:context) do
    {
      user: user,
      internal_events_class: internal_events_class
    }
  end

  let(:message) do
    RemoteDevelopment::Messages::DevfileYamlParseFailed.new(
      details: "Devfile yaml parsing failed",
      context: context
    )
  end

  subject(:returned_value) do
    described_class.observe(message)
  end

  describe ".observe" do
    let(:err_message) { message.class.name.demodulize }

    it "tracks a failed event" do
      expect(internal_events_class)
        .to receive(:track_event)
              .with(event_name, category: category, user: user,
                additional_properties: { label: label, property: err_message })

      expect(returned_value).to be_nil
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubleReference
