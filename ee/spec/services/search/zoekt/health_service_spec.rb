# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::HealthService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger, options: options) }
  let(:options) { {} }

  let(:node_result) { { status: :healthy, warnings: [], errors: [] } }
  let(:configuration_result) { { status: :healthy, warnings: [], errors: [] } }
  let(:connectivity_result) { { status: :healthy, warnings: [], errors: [] } }
  let(:process_health_result) { { status: :healthy, warnings: [], errors: [] } }

  before do
    allow(logger).to receive(:info)
    allow(Search::Zoekt::HealthCheck::NodeStatusService).to receive(:execute).and_return(node_result)
    allow(Search::Zoekt::HealthCheck::ConfigurationService).to receive(:execute).and_return(configuration_result)
    allow(Search::Zoekt::HealthCheck::ConnectivityService).to receive(:execute).and_return(connectivity_result)
    allow(Search::Zoekt::HealthCheck::ProcessHealthService).to receive(:execute).and_return(process_health_result)
  end

  describe '#execute' do
    it 'calls all four health check services' do
      expect(Search::Zoekt::HealthCheck::NodeStatusService).to receive(:execute).with(logger: logger)
      expect(Search::Zoekt::HealthCheck::ConfigurationService).to receive(:execute).with(logger: logger)
      expect(Search::Zoekt::HealthCheck::ConnectivityService).to receive(:execute).with(logger: logger)
      expect(Search::Zoekt::HealthCheck::ProcessHealthService).to receive(:execute).with(logger: logger)

      service.execute
    end

    it 'logs health check sections' do
      expect(logger).to receive(:info).with(include('=== Zoekt Health Check ==='))
      expect(logger).to receive(:info).with(include('Overall Status:'))

      service.execute
    end

    context 'when all checks are healthy' do
      it 'returns healthy overall status' do
        expect(logger).to receive(:info).with(include('HEALTHY'))

        exit_code = service.execute
        expect(exit_code).to eq(0)
      end

      it 'does not display recommendations' do
        expect(logger).not_to receive(:info).with(include('Recommendations:'))

        service.execute
      end

      it 'does not call exit in normal mode' do
        expect(service).not_to receive(:exit)

        service.execute
      end
    end

    context 'when some checks are degraded' do
      let(:node_result) { { status: :degraded, warnings: ['Node warning'], errors: [] } }

      it 'returns degraded overall status' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('DEGRADED'))

        exit_code = service.execute
        expect(exit_code).to eq(1)
      end

      it 'displays recommendations' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('Recommendations:'))
        expect(logger).to receive(:info).with(include('Node warning'))

        service.execute
      end

      context 'in normal mode' do
        let(:options) { {} }

        it 'calls exit with code 1' do
          expect(service).to receive(:exit).with(1)

          service.execute
        end
      end
    end

    context 'when some checks are unhealthy' do
      let(:connectivity_result) { { status: :unhealthy, warnings: [], errors: ['Connection error'] } }

      it 'returns unhealthy overall status' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('UNHEALTHY'))

        exit_code = service.execute
        expect(exit_code).to eq(2)
      end

      it 'displays error recommendations' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('Recommendations:'))
        expect(logger).to receive(:info).with(include('Connection error'))

        service.execute
      end

      context 'in normal mode' do
        let(:options) { {} }

        it 'calls exit with code 2' do
          expect(service).to receive(:exit).with(2)

          service.execute
        end
      end
    end

    context 'when process health check is unhealthy' do
      let(:process_health_result) { { status: :unhealthy, warnings: [], errors: ['Node 1 indexer is crashlooping'] } }

      it 'returns unhealthy overall status' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('UNHEALTHY'))

        exit_code = service.execute
        expect(exit_code).to eq(2)
      end

      it 'displays process health error in recommendations' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('Recommendations:'))
        expect(logger).to receive(:info).with(include('crashlooping'))

        service.execute
      end
    end

    context 'when process health check is degraded' do
      let(:process_health_result) do
        { status: :degraded, warnings: ['Node 1 indexer had a recent restart'], errors: [] }
      end

      it 'returns degraded overall status' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('DEGRADED'))

        exit_code = service.execute
        expect(exit_code).to eq(1)
      end
    end

    context 'when multiple checks have issues' do
      let(:node_result) { { status: :degraded, warnings: ['Storage warning'], errors: [] } }
      let(:configuration_result) { { status: :unhealthy, warnings: ['Config warning'], errors: ['Config error'] } }

      it 'returns unhealthy overall status (worst case)' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('UNHEALTHY'))

        exit_code = service.execute
        expect(exit_code).to eq(2)
      end

      it 'displays all recommendations' do
        allow(service).to receive(:exit)
        expect(logger).to receive(:info).with(include('Recommendations:'))
        expect(logger).to receive(:info).with(include('Config error'))
        expect(logger).to receive(:info).with(include('Storage warning'))
        expect(logger).to receive(:info).with(include('Config warning'))

        service.execute
      end
    end

    context 'in watch mode' do
      let(:options) { { watch_mode: true } }
      let(:node_result) { { status: :degraded, warnings: ['Node warning'], errors: [] } }

      it 'does not call exit even with errors' do
        expect(service).not_to receive(:exit)

        service.execute
      end

      it 'still returns correct exit code' do
        exit_code = service.execute
        expect(exit_code).to eq(1)
      end
    end
  end

  describe '.execute' do
    it 'creates instance and calls execute' do
      expect(described_class).to receive(:new).with(logger: logger, options: {}).and_call_original

      described_class.execute(logger: logger, options: {})
    end
  end

  describe '#determine_overall_status' do
    let(:service_instance) { described_class.new(logger: logger, options: {}) }

    it 'returns unhealthy if any result is unhealthy' do
      results = [
        { status: :healthy },
        { status: :unhealthy },
        { status: :degraded }
      ]

      status = service_instance.send(:determine_overall_status, results)
      expect(status).to eq(:unhealthy)
    end

    it 'returns degraded if any result is degraded and none are unhealthy' do
      results = [
        { status: :healthy },
        { status: :degraded },
        { status: :healthy }
      ]

      status = service_instance.send(:determine_overall_status, results)
      expect(status).to eq(:degraded)
    end

    it 'returns healthy if all results are healthy' do
      results = [
        { status: :healthy },
        { status: :healthy },
        { status: :healthy }
      ]

      status = service_instance.send(:determine_overall_status, results)
      expect(status).to eq(:healthy)
    end
  end

  describe '#status_color_for' do
    let(:service_instance) { described_class.new(logger: logger, options: {}) }

    it 'returns correct colors for each status' do
      expect(service_instance.send(:status_color_for, :healthy)).to eq(:green)
      expect(service_instance.send(:status_color_for, :degraded)).to eq(:yellow)
      expect(service_instance.send(:status_color_for, :unhealthy)).to eq(:red)
      expect(service_instance.send(:status_color_for, :unknown)).to eq(:white)
    end
  end
end
