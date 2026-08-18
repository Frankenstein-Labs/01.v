# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::FunnelStep, feature_category: :product_analytics do
  let(:funnel) do
    ::ProductAnalytics::Funnel.new(
      name: 'test',
      project: create(:project, :small_repo),
      seconds_to_convert: 300,
      config_path: 'nothing',
      config_project: create(:project, :small_repo)
    )
  end

  subject(:funnel_step) { described_class.new(name: 'test', target: '/page1.html', action: 'pageview', funnel: funnel) }

  it { is_expected.to validate_inclusion_of(:action).in_array(%w[pageview]) }
  it { is_expected.not_to allow_value('test').for(:action) }
  it { is_expected.to allow_value('Test_name-format01').for(:name) }
  it { is_expected.not_to allow_value('${(test(){})}').for(:name) }
  it { is_expected.to allow_value('section/subsection/page.html').for(:target) }
  it { is_expected.not_to allow_value('${(test(){})}').for(:target) }

  describe '#initialize' do
    it 'has a name' do
      expect(funnel_step.name).to eq('test')
    end

    it 'has a target' do
      expect(funnel_step.target).to eq('/page1.html')
    end

    it 'has an action' do
      expect(funnel_step.action).to eq('pageview')
    end
  end

  describe '#to_h' do
    subject { funnel_step.to_h }

    let(:expected) do
      {
        name: 'test',
        target: '/page1.html',
        action: 'pageview'
      }
    end

    it { is_expected.to eq expected }
  end

  describe '#step_definition' do
    subject { funnel_step.step_definition }

    context 'when snowplow' do
      it { is_expected.to eq("page_urlpath = '/page1.html'") }
    end
  end
end
