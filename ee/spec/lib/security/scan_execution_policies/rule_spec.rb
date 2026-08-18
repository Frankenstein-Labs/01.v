# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::Rule, feature_category: :security_policy_management do
  describe '#type' do
    it 'returns pipeline type' do
      rule = described_class.new({ type: 'pipeline' })
      expect(rule.type).to eq('pipeline')
    end

    it 'returns schedule type' do
      rule = described_class.new({ type: 'schedule' })
      expect(rule.type).to eq('schedule')
    end
  end

  describe '#branches' do
    context 'when branches is present' do
      it 'returns the branches array' do
        rule = described_class.new({ type: 'pipeline', branches: %w[main develop] })
        expect(rule.branches).to match_array(%w[main develop])
      end

      it 'handles wildcard patterns' do
        rule = described_class.new({ type: 'pipeline', branches: ['*', 'release-*'] })
        expect(rule.branches).to match_array(['*', 'release-*'])
      end
    end

    context 'when branches is not present' do
      it 'returns nil' do
        rule = described_class.new({ type: 'pipeline' })
        expect(rule.branches).to be_nil
      end
    end
  end

  describe '#branch_type' do
    context 'when branch_type is present' do
      %w[default protected all target_default target_protected].each do |branch_type|
        it "returns #{branch_type}" do
          rule = described_class.new({ type: 'pipeline', branch_type: branch_type })
          expect(rule.branch_type).to eq(branch_type)
        end
      end
    end

    context 'when branch_type is not present' do
      it 'returns nil' do
        rule = described_class.new({ type: 'pipeline' })
        expect(rule.branch_type).to be_nil
      end
    end
  end

  describe '#branch_exceptions' do
    context 'when branch_exceptions is present' do
      it 'returns string exceptions' do
        rule = described_class.new({
          type: 'pipeline', branches: ['main'], branch_exceptions: ['feature/*', 'hotfix/*']
        })
        expect(rule.branch_exceptions).to match_array(['feature/*', 'hotfix/*'])
      end

      it 'returns object exceptions with name and full_path' do
        exceptions = [
          { name: 'feature-branch', full_path: 'group/project/feature-branch' }
        ]
        rule = described_class.new({ type: 'pipeline', branches: ['main'], branch_exceptions: exceptions })
        expect(rule.branch_exceptions).to match_array(exceptions)
      end

      it 'handles mixed string and object exceptions' do
        exceptions = [
          'feature/*',
          { name: 'specific-branch', full_path: 'group/project/specific-branch' }
        ]
        rule = described_class.new({ type: 'pipeline', branches: ['main'], branch_exceptions: exceptions })
        expect(rule.branch_exceptions).to match_array(exceptions)
      end
    end

    context 'when branch_exceptions is not present' do
      it 'returns an empty array' do
        rule = described_class.new({ type: 'pipeline' })
        expect(rule.branch_exceptions).to be_empty
      end
    end
  end

  describe '#cadence' do
    context 'when cadence is present' do
      it 'returns cron expression' do
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * 1-5' })
        expect(rule.cadence).to eq('0 22 * * 1-5')
      end

      it 'handles special cron expressions' do
        rule = described_class.new({ type: 'schedule', cadence: '@daily' })
        expect(rule.cadence).to eq('@daily')
      end
    end

    context 'when cadence is not present' do
      it 'returns nil' do
        rule = described_class.new({ type: 'schedule' })
        expect(rule.cadence).to be_nil
      end
    end
  end

  describe '#timezone' do
    context 'when timezone is present' do
      it 'returns IANA timezone identifier' do
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *', timezone: 'America/New_York' })
        expect(rule.timezone).to eq('America/New_York')
      end

      it 'handles other IANA timezones' do
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *', timezone: 'Europe/London' })
        expect(rule.timezone).to eq('Europe/London')
      end
    end

    context 'when timezone is not present' do
      it 'returns nil' do
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *' })
        expect(rule.timezone).to be_nil
      end
    end
  end

  describe '#time_window' do
    context 'when time_window is present' do
      it 'returns a TimeWindow instance' do
        time_window_data = { distribution: 'random', value: 7200 }
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *', time_window: time_window_data })
        expect(rule.time_window).to be_a(Security::ScanExecutionPolicies::TimeWindow)
      end

      it 'passes time_window data to TimeWindow' do
        time_window_data = { distribution: 'random', value: 3600 }
        expect(Security::ScanExecutionPolicies::TimeWindow).to receive(:new).with(time_window_data)
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *', time_window: time_window_data })
        rule.time_window
      end

      it 'handles minimum value (3600 seconds = 1 hour)' do
        time_window_data = { distribution: 'random', value: 3600 }
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *', time_window: time_window_data })
        expect(rule.time_window.value).to eq(3600)
      end

      it 'handles maximum value (86400 seconds = 24 hours)' do
        time_window_data = { distribution: 'random', value: 86400 }
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *', time_window: time_window_data })
        expect(rule.time_window.value).to eq(86400)
      end
    end

    context 'when time_window is not present' do
      it 'returns a TimeWindow instance with empty hash' do
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *' })
        expect(rule.time_window).to be_a(Security::ScanExecutionPolicies::TimeWindow)
      end

      it 'passes empty hash to TimeWindow' do
        expect(Security::ScanExecutionPolicies::TimeWindow).to receive(:new).with({})
        rule = described_class.new({ type: 'schedule', cadence: '0 22 * * *' })
        rule.time_window
      end
    end
  end

  describe '#agents' do
    context 'when agents is present' do
      it 'returns an Agents instance' do
        agents_data = { 'agent-name' => { namespaces: %w[namespace1 namespace2] } }
        rule = described_class.new({ type: 'pipeline', agents: agents_data })
        expect(rule.agents).to be_a(Security::ScanExecutionPolicies::Agents)
      end

      it 'passes agents data to Agents' do
        agents_data = { 'agent-name' => { namespaces: ['namespace1'] } }
        expect(Security::ScanExecutionPolicies::Agents).to receive(:new).with(agents_data)
        rule = described_class.new({ type: 'pipeline', agents: agents_data })
        rule.agents
      end

      it 'handles agent name matching patternProperties schema' do
        agents_data = { 'agent-123' => { namespaces: ['default'] } }
        rule = described_class.new({ type: 'pipeline', agents: agents_data })
        expect(rule.agents).to be_a(Security::ScanExecutionPolicies::Agents)
      end
    end

    context 'when agents is not present' do
      it 'returns an Agents instance with empty hash' do
        rule = described_class.new({ type: 'pipeline' })
        expect(rule.agents).to be_a(Security::ScanExecutionPolicies::Agents)
      end

      it 'passes empty hash to Agents' do
        expect(Security::ScanExecutionPolicies::Agents).to receive(:new).with({})
        rule = described_class.new({ type: 'pipeline' })
        rule.agents
      end
    end
  end

  describe '#pipeline_sources' do
    context 'when pipeline_sources is present' do
      it 'returns a PipelineSources instance' do
        pipeline_sources_data = { including: %w[push web] }
        rule = described_class.new({ type: 'pipeline', branches: ['main'], pipeline_sources: pipeline_sources_data })
        expect(rule.pipeline_sources).to be_a(Security::ScanExecutionPolicies::PipelineSources)
      end

      it 'passes pipeline_sources data to PipelineSources' do
        pipeline_sources_data = { including: ['push'] }
        expect(Security::ScanExecutionPolicies::PipelineSources).to receive(:new).with(pipeline_sources_data)
        rule = described_class.new({ type: 'pipeline', branches: ['main'], pipeline_sources: pipeline_sources_data })
        rule.pipeline_sources
      end

      it 'handles all valid pipeline source values from schema' do
        sources = %w[unknown push web trigger schedule api external pipeline chat merge_request_event
          external_pull_request_event]
        pipeline_sources_data = { including: sources }
        rule = described_class.new({ type: 'pipeline', branches: ['main'], pipeline_sources: pipeline_sources_data })
        expect(rule.pipeline_sources.including).to match_array(sources)
      end
    end

    context 'when pipeline_sources is not present' do
      it 'returns a PipelineSources instance with empty hash' do
        rule = described_class.new({ type: 'pipeline', branches: ['main'] })
        expect(rule.pipeline_sources).to be_a(Security::ScanExecutionPolicies::PipelineSources)
      end

      it 'passes empty hash to PipelineSources' do
        expect(Security::ScanExecutionPolicies::PipelineSources).to receive(:new).with({})
        rule = described_class.new({ type: 'pipeline', branches: ['main'] })
        rule.pipeline_sources
      end
    end
  end

  describe 'pipeline type rule' do
    it 'handles complete pipeline rule with branches' do
      rule_data = {
        type: 'pipeline',
        branches: %w[main develop],
        branch_exceptions: ['feature/*'],
        pipeline_sources: { including: %w[push web] }
      }
      rule = described_class.new(rule_data)

      expect(rule.type).to eq('pipeline')
      expect(rule.branches).to match_array(%w[main develop])
      expect(rule.branch_exceptions).to match_array(['feature/*'])
      expect(rule.pipeline_sources.including).to match_array(%w[push web])
    end

    it 'handles pipeline rule with branch_type' do
      rule_data = {
        type: 'pipeline',
        branch_type: 'protected'
      }
      rule = described_class.new(rule_data)

      expect(rule.type).to eq('pipeline')
      expect(rule.branch_type).to eq('protected')
    end
  end

  describe 'schedule type rule' do
    it 'handles complete schedule rule' do
      rule_data = {
        type: 'schedule',
        cadence: '0 22 * * 1-5',
        timezone: 'America/New_York',
        time_window: { distribution: 'random', value: 7200 }
      }
      rule = described_class.new(rule_data)

      expect(rule.type).to eq('schedule')
      expect(rule.cadence).to eq('0 22 * * 1-5')
      expect(rule.timezone).to eq('America/New_York')
      expect(rule.time_window.distribution).to eq('random')
      expect(rule.time_window.value).to eq(7200)
    end
  end

  describe 'agents type rule' do
    it 'handles rule with agents' do
      rule_data = {
        type: 'pipeline',
        agents: { 'my-agent' => { namespaces: %w[default production] } }
      }
      rule = described_class.new(rule_data)

      expect(rule.type).to eq('pipeline')
      expect(rule.agents.agent_names).to match_array(['my-agent'])
      expect(rule.agents.namespaces_for_agent('my-agent')).to match_array(%w[default production])
    end
  end
end
