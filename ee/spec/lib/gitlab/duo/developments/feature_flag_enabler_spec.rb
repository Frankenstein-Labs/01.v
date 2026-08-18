# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::FeatureFlagEnabler, feature_category: :duo_chat do
  def definition(name:, group:, type: :development)
    Feature::Definition.new(nil, name: name.to_s, group: group, type: type)
  end

  it 'enables feature flags by group ai framework' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: definition(name: :test_f, group: 'group::ai framework') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group ai coding' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: definition(name: :test_f, group: 'group::ai coding') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group agent foundations' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: definition(name: :test_f, group: 'group::agent foundations') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group duo chat' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: definition(name: :test_f, group: 'group::duo chat') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group duo workflow' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: definition(name: :test_f, group: 'group::duo workflow') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group custom models' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: definition(name: :test_f, group: 'group::custom models') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'does not enable feature flags from groups outside the AI groups' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: definition(name: :test_f, group: 'group::other') })
    expect(Feature).not_to receive(:enable)

    described_class.execute
  end

  it 'excludes WIP feature flags even when they belong to an AI group' do
    wip_flag = :wip_duo_flag
    regular_flag = :regular_duo_flag

    expect(Feature::Definition).to receive(:definitions)
      .and_return({
        wip_flag => definition(name: wip_flag, group: 'group::ai framework', type: :wip),
        regular_flag => definition(name: regular_flag, group: 'group::ai framework')
      })

    expect(Feature).to receive(:enable).with(regular_flag)
    expect(Feature).not_to receive(:enable).with(wip_flag)

    described_class.execute
  end

  it 'excludes feature flags listed in EXCLUDED_FEATURE_FLAGS' do
    excluded_flag = described_class::EXCLUDED_FEATURE_FLAGS.first
    regular_flag = :regular_duo_flag

    expect(Feature::Definition).to receive(:definitions)
      .and_return({
        excluded_flag => definition(name: excluded_flag, group: 'group::ai framework'),
        regular_flag => definition(name: regular_flag, group: 'group::ai framework')
      })

    expect(Feature).to receive(:enable).with(regular_flag)
    expect(Feature).not_to receive(:enable).with(excluded_flag)

    described_class.execute
  end
end
