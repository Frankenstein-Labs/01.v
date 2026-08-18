# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MetricsUpdateCronWorker, feature_category: :global_search do
  it_behaves_like 'an idempotent worker' do
    describe '#perform' do
      using RSpec::Parameterized::TableSyntax

      let(:setting_gauge_double) { instance_double(Prometheus::Client::Gauge) }

      subject(:perform) do
        described_class.new.perform
      end

      before do
        allow(Gitlab::Metrics).to receive(:gauge)
          .with(:search_advanced_boolean_settings, anything, {}, :max)
          .and_return(setting_gauge_double)
      end

      described_class::BOOLEAN_SETTINGS.each do |setting_name|
        context "when #{setting_name} setting is false" do
          before do
            Gitlab::CurrentSettings.update!("#{setting_name}": false)
          end

          it 'reports prometheus metrics' do
            allow(setting_gauge_double).to receive(:set)
            expect(setting_gauge_double).to receive(:set)
              .with({ name: setting_name }, described_class::SETTING_DISABLED)

            perform
          end
        end

        context "when #{setting_name} setting is true" do
          before do
            Gitlab::CurrentSettings.update!("#{setting_name}": true)
          end

          it 'reports prometheus metrics' do
            allow(setting_gauge_double).to receive(:set)
            expect(setting_gauge_double).to receive(:set)
              .with({ name: setting_name }, described_class::SETTING_ENABLED)

            perform
          end
        end
      end
    end
  end
end
