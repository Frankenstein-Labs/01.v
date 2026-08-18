# frozen_string_literal: true

require "fast_spec_helper"
require_relative "../../../app/finders/remote_development/filter_argument_validator"

RSpec.describe RemoteDevelopment::FilterArgumentValidator, feature_category: :workspaces do
  let(:filter_arguments) do
    {
      ids: [1, 2],
      cluster_agent_ids: [99, 98]
    }
  end

  let(:filter_argument_types) do
    {
      ids: Integer,
      cluster_agent_ids: Integer
    }
  end

  describe ".validate_filter_argument_types!" do
    context "when all types are valid" do
      it "does not raise an error" do
        expect do
          described_class.validate_filter_argument_types!(filter_argument_types, filter_arguments)
        end.not_to raise_error
      end
    end

    context "when an invalid filter argument type is provided" do
      let(:expected_exception_message) do
        "'ids' must be an Array of 'Integer', " \
          "'cluster_agent_ids' must be an Array of 'Integer'"
      end

      context "when argument is not an array" do
        let(:filter_arguments) do
          {
            ids: 1,
            cluster_agent_ids: 1
          }
        end

        it "raises an RuntimeError", :unlimited_max_formatted_output_length do
          expect do
            described_class.validate_filter_argument_types!(filter_argument_types,
              filter_arguments)
          end.to raise_error(RuntimeError, expected_exception_message)
        end
      end

      context "when array content is wrong type" do
        let(:filter_arguments) do
          {
            ids: %w[a b],
            cluster_agent_ids: %w[a b]
          }
        end

        it "raises an RuntimeError", :unlimited_max_formatted_output_length do
          expect do
            described_class.validate_filter_argument_types!(filter_argument_types,
              filter_arguments)
          end.to raise_error(RuntimeError, expected_exception_message)
        end
      end
    end
  end

  describe ".validate_at_least_one_filter_argument_provided!" do
    context "when at lease one filter argument is provided" do
      it "does not raise an error" do
        expect do
          described_class.validate_at_least_one_filter_argument_provided!(**filter_arguments)
        end.not_to raise_error
      end
    end

    context "when no filter argument is provided" do
      let(:filter_arguments) { {} }

      it "raise ArgumentError" do
        expect do
          described_class.validate_at_least_one_filter_argument_provided!(**filter_arguments)
        end.to raise_error(ArgumentError,
          "At least one filter argument must be provided")
      end
    end
  end
end
