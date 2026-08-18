# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ProductAnalytics::Developments::Setup, :saas, feature_category: :product_analytics do
  include RakeHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, path: 'test-group', organization: organization) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  let(:task) { described_class.new(args) }
  let(:args) { { root_group_path: group.path } }
  let(:rake_task) { instance_double(Rake::Task, invoke: true) }

  subject(:setup) { task.execute }

  before do
    allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)

    stub_env('GITLAB_SIMULATE_SAAS', '1')

    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
  end

  context 'with production environment' do
    before do
      allow(::Gitlab).to receive(:dev_or_test_env?).and_return(false)
    end

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end

  context 'when GITLAB_SIMULATE_SAAS is missing' do
    before do
      stub_const('ENV', { 'GITLAB_SIMULATE_SAAS' => nil })
    end

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end

  context 'when group does not exist' do
    let(:args) { { root_group_path: 'new-path' } }

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end

  context 'when a group exists' do
    before do
      setup
    end

    it 'sets the group plan to "ultimate"' do
      expect(group.actual_plan_name).to eq('ultimate')
    end

    it 'enables feature flags for product analytics' do
      expect(Feature.enabled?(:product_analytics_features)).to be(true)
    end

    it 'enables the application settings' do
      expect(::Gitlab::CurrentSettings.check_namespace_plan).to be(true)
      expect(::Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services).to be(true)
    end
  end

  context 'when not configured' do
    it 'outputs instructions to configure Product Analytics' do
      expect { setup }.to output(/Product Analytics is now enabled but not yet configured/).to_stdout
    end
  end

  context 'when configured' do
    before do
      allow(::Gitlab::CurrentSettings).to receive(:product_analytics_data_collector_host).and_return('http://foo')
    end

    it 'outputs that Product Analytics is already configured' do
      expect { setup }.to output(/Product Analytics is now enabled and configured/).to_stdout
    end
  end

  context 'when all checks pass' do
    it 'outputs the success message with the group name' do
      expect { setup }.to output(/Access Product Analytics on any project in "#{group.name}"/).to_stdout
    end
  end
end
