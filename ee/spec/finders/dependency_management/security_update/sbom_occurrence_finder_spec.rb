# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::SbomOccurrenceFinder, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability) do
    create(:vulnerability, :with_finding, :detected, project: project, report_type: :dependency_scanning)
  end

  subject(:execute) { described_class.new(project: project, vulnerability: vulnerability).execute }

  def link(occurrence)
    create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability)
  end

  context 'when a supported occurrence is linked to the vulnerability' do
    let_it_be(:occurrence) do
      create(:sbom_occurrence, project: project, package_manager: 'bundler').tap { |o| link(o) }
    end

    it 'returns the occurrence' do
      expect(execute).to contain_exactly(occurrence)
    end
  end

  context 'when the linked occurrence uses an unsupported package manager' do
    before do
      create(:sbom_occurrence, project: project, package_manager: 'composer').tap { |o| link(o) }
    end

    it { is_expected.to be_empty }
  end

  context 'when the linked occurrence has no component version' do
    before do
      create(:sbom_occurrence, project: project, package_manager: 'bundler', component_version: nil).tap { |o| link(o) }
    end

    it { is_expected.to be_empty }
  end

  context 'when the vulnerability has no linked occurrences' do
    it { is_expected.to be_empty }
  end

  context 'when several supported occurrences are linked' do
    let_it_be(:first_occurrence) do
      create(:sbom_occurrence, project: project, package_manager: 'bundler').tap { |o| link(o) }
    end

    let_it_be(:second_occurrence) do
      create(:sbom_occurrence, project: project, package_manager: 'npm').tap { |o| link(o) }
    end

    it 'orders by id so the first is deterministic' do
      expect(execute.first).to eq([first_occurrence, second_occurrence].min_by(&:id))
    end
  end

  context 'when a matching occurrence belongs to another project' do
    let_it_be(:other_project) { create(:project) }

    before do
      create(:sbom_occurrence, project: other_project, package_manager: 'bundler').tap { |o| link(o) }
    end

    it { is_expected.to be_empty }
  end
end
