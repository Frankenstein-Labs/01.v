# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Duo::Otel::GoalTemplates, feature_category: :duo_agent_platform do
  shared_examples 'includes resource attributes for agent feedback loop' do
    it 'includes gitlab.project.id, gitlab.project.name, service.version, and deployment.environment.name' do
      expect(description).to include('gitlab.project.id')
      expect(description).to include('CI_PROJECT_ID')
      expect(description).to include('gitlab.project.name')
      expect(description).to include('CI_PROJECT_NAME')
      expect(description).to include('service.version')
      expect(description).to include('CI_COMMIT_SHA')
      expect(description).to include('deployment.environment.name')
      expect(description).to include('CI_ENVIRONMENT_NAME')
    end
  end

  describe '.issue_title' do
    it 'returns the expected title' do
      expect(described_class.issue_title).to eq('Add OpenTelemetry instrumentation')
    end
  end

  describe '.build_description' do
    context 'for Ruby' do
      let(:description) { described_class.build_description('Ruby') }

      it 'returns Ruby template' do
        expect(description).to include('Add OpenTelemetry SDK instrumentation to this Ruby project')
        expect(description).to include('opentelemetry-sdk')
        expect(description).to include('opentelemetry-instrumentation-rails')
        expect(description).to include('bundle install')
      end

      include_examples 'includes resource attributes for agent feedback loop'
    end

    context 'for JavaScript' do
      let(:description) { described_class.build_description('JavaScript') }

      it 'returns JavaScript template' do
        expect(description).to include('Add OpenTelemetry SDK instrumentation to this Node.js project')
        expect(description).to include('@opentelemetry/sdk-node')
        expect(description).to include('getNodeAutoInstrumentations()')
        expect(description).to include('npm install')
      end

      include_examples 'includes resource attributes for agent feedback loop'
    end

    context 'for TypeScript' do
      let(:description) { described_class.build_description('TypeScript') }

      it 'returns JavaScript template (same as JavaScript)' do
        expect(description).to include('Add OpenTelemetry SDK instrumentation to this Node.js project')
        expect(description).to include('@opentelemetry/sdk-node')
        expect(description).to include('npm install')
      end

      include_examples 'includes resource attributes for agent feedback loop'
    end

    context 'for Python' do
      let(:description) { described_class.build_description('Python') }

      it 'returns Python template' do
        expect(description).to include('Add OpenTelemetry SDK instrumentation to this Python project')
        expect(description).to include('opentelemetry-sdk')
        expect(description).to include('TracerProvider')
        expect(description).to include('pip install -r requirements.txt')
      end

      include_examples 'includes resource attributes for agent feedback loop'
    end

    context 'for unknown language' do
      let(:description) { described_class.build_description('Go') }

      it 'returns default template' do
        expect(description).to include('Add OpenTelemetry SDK instrumentation to this project')
        expect(description).to include("for this project's language")
        expect(description).to include('Install the new dependencies using the project\'s package manager')
      end

      include_examples 'includes resource attributes for agent feedback loop'
    end

    context 'for nil language' do
      let(:description) { described_class.build_description(nil) }

      it 'returns default template' do
        expect(description).to include('Add OpenTelemetry SDK instrumentation to this project')
        expect(description).to include("for this project's language")
        expect(description).to include('Install the new dependencies using the project\'s package manager')
      end

      include_examples 'includes resource attributes for agent feedback loop'
    end
  end
end
