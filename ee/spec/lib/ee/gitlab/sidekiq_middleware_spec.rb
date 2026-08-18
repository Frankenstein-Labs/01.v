# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SidekiqMiddleware, feature_category: :shared do
  let(:job_args) { [0.01] }
  let(:disabled_sidekiq_middlewares) { [] }
  let(:chain) { Sidekiq::Middleware::Chain.new(Sidekiq) }
  let(:queue) { 'test' }
  let(:enabled_sidekiq_middlewares) { all_sidekiq_middlewares - disabled_sidekiq_middlewares }
  let(:worker_class) do
    Class.new do
      def self.name
        'TestWorker'
      end

      include ApplicationWorker

      def perform(*_args); end
    end
  end

  before do
    stub_const('TestWorker', worker_class)
  end

  shared_examples "a middleware chain" do
    before do
      configurator.call(chain)
      stub_feature_flags("drop_sidekiq_jobs_#{worker_class.name}": false) # not dropping the job
    end

    it "passes through the right middlewares", :aggregate_failures do
      enabled_sidekiq_middlewares.each do |middleware|
        expect_next_instances_of(middleware, 1, true) do |middleware_instance|
          expect(middleware_instance).to receive(:call).with(*middleware_expected_args).once.and_call_original
        end
      end

      expect { |b| chain.invoke(*worker_args, &b) }.to yield_control.once
    end
  end

  describe 'Server.configurator' do
    let(:configurator) { described_class::Server.configurator }
    let(:worker_args) { [worker_class.new, { 'args' => job_args }, queue] }
    let(:middleware_expected_args) { [a_kind_of(worker_class), hash_including({ 'args' => job_args }), queue] }
    let(:all_sidekiq_middlewares) do
      [
        ::Gitlab::SidekiqMiddleware::SetSession::Server
      ]
    end

    it_behaves_like "a middleware chain"
  end
end
