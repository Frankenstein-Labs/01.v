# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::RemoteDevelopment::DevfileOperations::Main, feature_category: :workspaces do
  include_context "with remote development shared fixtures"

  let(:user) { create(:user) }
  let(:devfile_fixture_name) { "example.devfile.yaml.erb" }
  let(:devfile_yaml) { read_devfile_yaml(devfile_fixture_name) }
  let(:expected_processed_devfile) { example_processed_devfile }

  let(:context) do
    {
      user: user,
      devfile_yaml: devfile_yaml,
      internal_events_class: Gitlab::InternalEvents
    }
  end

  shared_examples "tracks successful devfile validated event" do
    it "tracks creation event" do
      expect { response }
        .to trigger_internal_events("devfile_validate_result")
        .with(
          category: "RemoteDevelopment::DevfileOperations::Observer",
          user: user,
          additional_properties: { label: "succeed" }
        )
      .and increment_usage_metrics("counts.count_total_succeed_devfiles_validated")
    end
  end

  shared_examples "tracks failed devfile validated event" do |error_message|
    it "tracks failed creation event with proper error details" do
      expect { response }
        .to trigger_internal_events("devfile_validate_result")
      .with(
        category: "RemoteDevelopment::DevfileOperations::ErrorsObserver",
        user: user,
        additional_properties: { label: "failed", property: error_message }
      )
      .and increment_usage_metrics("counts.count_total_failed_devfiles_validated")
    end
  end

  subject(:response) do
    described_class.main(context)
  end

  context "when params are valid" do
    it "returns success" do
      expect(response.fetch(:status)).to eq(:success)
      expect(response[:message]).to be_nil
      expect(response[:payload]).not_to be_nil
      expect(response[:payload]).to eq({})
    end

    it_behaves_like "tracks successful devfile validated event"
  end

  context "when params are invalid" do
    let(:devfile_fixture_name) { "example.invalid-components-entry-missing-devfile.yaml.erb" }

    it "returns failure" do
      expect(response).to eq({
        status: :error,
        message: "Devfile restrictions failed: No components present in devfile",
        reason: :bad_request
      })
    end

    it_behaves_like "tracks failed devfile validated event", "DevfileRestrictionsFailed"
  end

  context "when multiple params are invalid" do
    let(:devfile_fixture_name) { "example.invalid-multiple-errors-devfile.yaml.erb" }

    it "returns failure" do
      err1 =
        "Endpoint name 'gl-example-invalid-second-endpoint' of component 'example-invalid-second-component' " \
          "must not start with 'gl-'"
      err2 = "Event 'gl-example' of type 'preStart' must not start with 'gl-'"
      expected_message = "Devfile restrictions failed: #{err1},  #{err2}"

      expect(response).to eq({
        status: :error,
        message: expected_message,
        reason: :bad_request
      })
    end
  end
end
