# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQValidateCommandSourceService, feature_category: :ai_agents do
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  describe '#validate' do
    subject(:validate) { described_class.new(command: command, source: source).validate }

    context 'with deprecated command on merge request' do
      let(:command) { 'test' }
      let(:source) { merge_request }

      it 'raises DeprecatedCommandError' do
        expect { validate }.to raise_error(
          described_class::DeprecatedCommandError,
          "/q test is now supported by using /q dev in an issue or merge request. " \
            "To generate unit tests for this MR, add an inline comment " \
            "and enter /q dev along with a comment about the tests you want written."
        )
      end
    end

    context 'with issue source' do
      let(:source) { issue }

      context 'with supported command' do
        let(:command) { 'dev' }

        it 'does not raise an error' do
          expect { validate }.not_to raise_error
        end
      end

      context 'with unsupported command' do
        let(:command) { 'unsupported' }

        it 'raises UnsupportedCommandError' do
          expect { validate }.to raise_error(
            described_class::UnsupportedCommandError,
            "Unsupported issue command: unsupported"
          )
        end
      end
    end

    context 'with merge request source' do
      let(:source) { merge_request }

      context 'with supported command' do
        let(:command) { 'dev' }

        it 'does not raise an error' do
          expect { validate }.not_to raise_error
        end
      end

      context 'with unsupported command' do
        let(:command) { 'unsupported' }

        it 'raises UnsupportedCommandError' do
          expect { validate }.to raise_error(
            described_class::UnsupportedCommandError,
            "Unsupported merge request command: unsupported"
          )
        end
      end
    end

    context 'with unsupported source type' do
      let(:command) { 'dev' }
      let(:source) { "invalid_source" }

      it 'raises UnsupportedSourceError' do
        expect { validate }.to raise_error(
          described_class::UnsupportedSourceError,
          "Unsupported source type: String"
        )
      end
    end
  end
end
