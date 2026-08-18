# frozen_string_literal: true

require "fast_spec_helper"

# rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::WorkspaceObserver, feature_category: :workspaces do
  let(:user) { instance_double("User") }
  let(:namespace) { instance_double("Namespace") }
  let(:project) { instance_double("Project", namespace: namespace) }
  let(:internal_events_class) { class_double("Gitlab::InternalEvents") }
  let(:event_name) { "create_workspace_result" }
  let(:label) { "succeed" }
  let(:category) { described_class.to_s }
  let(:context) do
    {
      user: user,
      internal_events_class: internal_events_class,
      params: {
        project: project
      }
    }
  end

  subject(:returned_value) do
    described_class.observe(context)
  end

  describe ".observe" do
    it "tracks a succeeded event" do
      expect(internal_events_class)
        .to receive(:track_event)
              .with(event_name, category: category, project: project, namespace: namespace, user: user,
                additional_properties: { label: label })

      expect(returned_value).to be_nil
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubleReference
