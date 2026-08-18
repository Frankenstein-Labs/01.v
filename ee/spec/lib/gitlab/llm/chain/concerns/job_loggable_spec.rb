# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Concerns::JobLoggable, feature_category: :duo_chat do
  let(:dummy_class) do
    Class.new do
      include Gitlab::Llm::Chain::Concerns::JobLoggable

      attr_accessor :job

      def initialize(job)
        @job = job
      end
    end
  end

  let_it_be(:build) { create(:ci_build, :trace_live) }

  subject(:dummy_instance) { dummy_class.new(build) }

  before do
    Gitlab::ExclusiveLease.skipping_transaction_check do
      build.trace.set(trace_log)
    end
  end

  describe '#job_log' do
    context 'when the job log has less than 1000 lines' do
      let(:trace_log) { Array.new(500, 'line of log').join("\n") }

      it 'returns the complete job log' do
        expect(dummy_instance.job_log).to eq(trace_log)
      end
    end

    context 'when the job log has more than 1000 lines' do
      let(:trace_log) { Array.new(1010, 'line of log').join("\n") }
      let(:job_log_with_limit) { build.trace.raw(last_lines: 1000) }

      it 'returns the last 1000 lines of the job log' do
        expect(dummy_instance.job_log).to eq(job_log_with_limit)
      end
    end
  end
end
