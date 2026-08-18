# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::Files, feature_category: :workspaces do
  after do
    # Reset mock data because the tests change class level constants
    RSpec::Mocks.space.reset_all
    described_class.reload_constants!
  end

  describe "hot reloading for constants" do
    let(:root_path) { File.expand_path("../../../", __dir__.to_s) }
    let(:script_path) { "settings/default_devfile.yaml" }
    let(:full_script_path) { File.join(root_path, "lib/remote_development", script_path) }

    it "updates constants when file content changes" do
      # Verify initial state of the script file
      expect(described_class::DEFAULT_DEVFILE_YAML).to match(/schemaVersion/)

      # "Update" the script file
      allow(described_class).to receive(:default_devfile_yaml).and_return("updated content")

      described_class.reload_constants!

      expect(described_class::DEFAULT_DEVFILE_YAML).to eq("updated content")
    end
  end

  describe "enforcement that reload_constants! is in sync with actual constants" do
    context "when all_expected_file_constants count does not match the number of constants defined" do
      it "raises an error" do
        allow(described_class).to receive(:all_expected_file_constants).and_return([:JUST_ONE_CONSTANT])

        expect { described_class.reload_constants! }
          .to raise_error(/File constants count mismatch!/)
      end
    end

    context "when any expected file constant is not defined" do
      let(:all_expected_file_constants) do
        Array.new(described_class.send(:all_expected_file_constants).length) { |i| "MISMATCHED_CONSTANT_#{i}" }
      end

      it "raises an error" do
        allow(described_class).to receive(:all_expected_file_constants).and_return(all_expected_file_constants)

        expect { described_class.reload_constants! }
          .to raise_error(NameError, /MISMATCHED_CONSTANT_0 not defined/)
      end
    end
  end
end
