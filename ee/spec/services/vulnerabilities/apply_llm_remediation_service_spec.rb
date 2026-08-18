# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ApplyLlmRemediationService, feature_category: :vulnerability_management do
  describe '#execute' do
    subject(:service) { described_class.new(old_code, new_code, source_content).execute }

    let(:old_code) { 'Original code' }
    let(:new_code) { 'New code' }
    let(:source_content) { 'Source file content' }

    context 'with fixture examples' do
      let(:fixture_file) { 'ee/spec/fixtures/vulnerabilities/apply_llm_remediation_service.json' }
      let(:recorded_examples) { ::Gitlab::Json.parse(File.read(Rails.root.join(fixture_file))) }

      it 'correctly applies the patches for all examples' do
        recorded_examples.each do |example|
          name = example['name'] || 'Unnamed example'
          description = example['description'] || 'No description provided'

          old_code = example['old_code']
          new_code = example['new_code']
          source_content = example['source_content']
          expected_output = example['expected_output']

          result = described_class.new(old_code, new_code, source_content).execute

          expect(result[:status]).to eq(:success)
          expect(result[:patched_content]).to eq(expected_output), "#{name}: #{description}\n"
        end
      end
    end

    context 'when old code is blank' do
      context 'with nil' do
        let(:old_code) { nil }

        it 'returns an error response' do
          expect(service[:status]).to eq(:error)
          expect(service[:message]).to eq('No original code to match against')
        end
      end

      context 'with blank string' do
        let(:old_code) { '' }

        it 'returns an error response' do
          expect(service[:status]).to eq(:error)
          expect(service[:message]).to eq('No original code to match against')
        end
      end
    end

    context 'when new code is blank' do
      context 'with nil' do
        let(:new_code) { nil }

        it 'returns an error response' do
          expect(service[:status]).to eq(:error)
          expect(service[:message]).to eq('No new code to apply to source')
        end
      end

      context 'with blank string' do
        let(:new_code) { '' }
        let(:old_code) { 'code to delete ' }
        let(:source_content) { 'Source file with code to delete deleted.' }

        it 'returns the source_content with old_code deleted' do
          expect(service[:status]).to eq(:success)
          expect(service[:patched_content]).to eq('Source file with deleted.')
        end
      end
    end

    context 'when source content is nil' do
      context 'with nil' do
        let(:source_content) { nil }

        it 'returns an error response' do
          expect(service[:status]).to eq(:error)
          expect(service[:message]).to eq('No source code to match on')
        end
      end

      context 'with blank string' do
        let(:source_content) { '' }

        it 'returns an error response' do
          expect(service[:status]).to eq(:error)
          expect(service[:message]).to eq('No source code to match on')
        end
      end
    end

    context "when #{described_class.name} causes a StandardError" do
      let(:source_content) { instance_double(String) }

      before do
        allow(source_content).to receive(:gsub).and_raise(StandardError)
      end

      it 'wraps StandardError in a ServiceResponse' do
        expect(service[:status]).to eq(:error)
        expect(service[:message]).to eq('Unexpected error while patching the source')
      end
    end
  end
end
