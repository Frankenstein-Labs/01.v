# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectSecurityExclusionsFinder, feature_category: :secret_detection do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:exclusions) do
    {
      inactive: create(:project_security_exclusion, :with_raw_value, :inactive, project: project),
      raw_value: create(:project_security_exclusion, :with_raw_value, project: project),
      path: create(:project_security_exclusion, :with_path, project: project),
      regex_pattern: create(:project_security_exclusion, :with_regex_pattern, project: project),
      rule: create(:project_security_exclusion, :with_rule, project: project)
    }
  end

  let(:params) { {} }

  subject(:finder) { described_class.new(user, project: project, params: params) }

  shared_examples 'returns expected exclusions' do |expected_exclusions|
    it 'returns the correct exclusions' do
      expect(finder.execute).to match_array(expected_exclusions.map { |key| exclusions[key] })
    end
  end

  describe '#execute' do
    context 'with a role that can read security exclusions' do
      before_all { project.add_maintainer(user) }

      context 'without filters' do
        include_examples 'returns expected exclusions', %i[rule regex_pattern raw_value path inactive]
      end

      context 'when filtering by id' do
        let(:params) { { id: exclusions[:rule].id } }

        include_examples 'returns expected exclusions', %i[rule]
      end

      context 'when filtering by security scanner' do
        let(:params) { { scanner: 'secret_push_protection' } }

        include_examples 'returns expected exclusions', %i[rule regex_pattern raw_value path inactive]
      end

      context 'when filtering by exclusion type' do
        let(:params) { { type: 'rule' } }

        include_examples 'returns expected exclusions', %i[rule]
      end

      context 'when filtering by exclusion status' do
        let(:params) { { active: true } }

        include_examples 'returns expected exclusions', %i[rule regex_pattern raw_value path]
      end
    end

    context 'with a role that cannot read security exclusions' do
      before_all { project.add_reporter(user) }

      it 'returns no exclusions' do
        expect(finder.execute).to be_empty
      end
    end
  end
end
