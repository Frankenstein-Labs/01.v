# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ObserveHistogramsService, feature_category: :security_policy_management do
  let(:name) { :gitlab_security_policies_scan_execution_configuration_rendering_seconds }
  let(:histogram) { described_class.histogram(name) }
  let(:duration) { 1 }

  before do
    allow(Gitlab::Metrics::System).to receive(:monotonic_time).twice.and_return(duration - 1, duration)
  end

  describe '.histogram' do
    let(:description) { described_class::HISTOGRAMS.dig(name, :description) }
    let(:buckets) { described_class::HISTOGRAMS.dig(name, :buckets) }

    it 'returns the expected histogram', :aggregate_failures do
      expect(histogram.name).to be(name)
      expect(histogram.docstring).to eq(description)
      expect(histogram.instance_variable_get(:@buckets)).to eq(buckets)
    end
  end

  describe '.measure' do
    let(:labels) { {} }
    let(:return_value) { Object.new }

    subject(:measure) { described_class.measure(name, labels: labels) { return_value } }

    it 'observes' do
      expect(histogram).to receive(:observe).with(labels, duration)

      measure
    end

    context 'with labels' do
      let(:labels) { { foo: "bar" } }

      it 'observes' do
        expect(histogram).to receive(:observe).with(labels, duration)

        measure
      end
    end

    it 'returns the block return value' do
      allow(histogram).to receive(:observe).with(labels, duration)
      expect(measure).to be(return_value)
    end

    context 'with callback' do
      subject(:measure) { described_class.measure(name, labels: labels, callback: callback) { return_value } }

      let(:callback) { ->(duration) { receiver.call(duration) } }
      let(:receiver) { spy }

      before do
        allow(histogram).to receive(:observe).with(labels, duration)
      end

      it 'passes the duration' do
        expect(receiver).to receive(:call).with(duration)

        measure
      end

      context 'with arguments' do
        let(:arg) { :foo }
        let(:callback) { ->(duration) { receiver.call(duration, arg) } }

        it 'passes arguments' do
          expect(receiver).to receive(:call).with(duration, arg)

          measure
        end
      end
    end
  end
end
