# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflow::RunnerExecutors, feature_category: :duo_agent_platform do
  compatible = %i[docker docker_autoscaler docker_machine kubernetes]
  incompatible = %i[unknown custom shell ssh parallels virtualbox instance
    docker_windows docker_ssh docker_ssh_machine]

  describe '.docker_compatible?' do
    it 'accepts every executor able to run the Linux workload image' do
      compatible.each do |executor|
        manager = build(:ci_runner_machine, executor_type: executor)

        expect(described_class.docker_compatible?(manager)).to be(true), "expected #{executor} to be compatible"
      end
    end

    it 'rejects executors that cannot host a Duo workload' do
      incompatible.each do |executor|
        manager = build(:ci_runner_machine, executor_type: executor)

        expect(described_class.docker_compatible?(manager)).to be(false), "expected #{executor} to be incompatible"
      end
    end

    it 'decides every executor type the enum defines' do
      expect(compatible + incompatible)
        .to match_array(::Ci::RunnerManager.executor_types.keys.map(&:to_sym))
    end
  end
end
