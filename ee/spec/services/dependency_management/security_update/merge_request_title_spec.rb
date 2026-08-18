# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::MergeRequestTitle,
  feature_category: :dependency_management do
  def dependency(name:, version:, previous_version: '1.0.0')
    DependencyManagement::SecurityUpdate::OutputParser::DependencyChange.new(
      name: name, previous_version: previous_version, version: version
    )
  end

  describe '.build' do
    it 'renders a single-dependency title' do
      title = described_class.build([dependency(name: 'rails', previous_version: '6.1.4', version: '6.1.5')])

      expect(title).to eq('Security: Update rails from 6.1.4 to 6.1.5')
    end

    it 'renders a grouped title for multiple dependencies' do
      deps = [dependency(name: 'rails', version: '6.1.5'), dependency(name: 'rack', version: '3.0.0')]

      expect(described_class.build(deps)).to eq('Security: Update 2 dependencies')
    end
  end

  describe '.parse_single_dependency' do
    it 'captures the name and target version' do
      match = described_class.parse_single_dependency('Security: Update rails from 6.1.4 to 6.1.5')

      expect(match[:name]).to eq('rails')
      expect(match[:version]).to eq('6.1.5')
    end

    it 'does not match grouped titles' do
      expect(described_class.parse_single_dependency('Security: Update 2 dependencies')).to be_nil
    end
  end

  describe 'round trip' do
    it 'parses back the title built for a single dependency' do
      dep = dependency(name: '@scope/pkg', previous_version: '1.2.3', version: '4.5.6')

      match = described_class.parse_single_dependency(described_class.build([dep]))

      expect(match[:name]).to eq('@scope/pkg')
      expect(match[:version]).to eq('4.5.6')
    end
  end
end
