# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::DependencyListExport, feature_category: :dependency_management do
  let_it_be(:project) { build_stubbed(:project, id: 1) }
  let_it_be(:dependency_list_export) { build_stubbed(:dependency_list_export, :finished, id: 1, project: project) }

  let(:entity) { described_class.new(dependency_list_export) }

  subject { entity.as_json }

  # rubocop:disable RSpec/NamedSubject -- TODO: needs to be fixed
  it 'contains a small set of dependency list export properties', :aggregate_failures do
    expect(subject[:id]).to eq(dependency_list_export.id)
    expect(subject[:status]).to eq(dependency_list_export.status_name)
    expect(subject[:has_finished]).to eq(dependency_list_export.finished?)
    expect(subject[:export_type]).to eq(dependency_list_export.export_type)
    expect(subject[:send_email]).to eq(dependency_list_export.send_email)
    expect(subject[:expires_at]).to eq(dependency_list_export.expires_at)
    expect(subject[:self]).to end_with(
      "/api/v4/dependency_list_exports/#{dependency_list_export.id}")
    expect(subject[:download]).to end_with(
      "/api/v4/dependency_list_exports/#{dependency_list_export.id}/download")
  end
  # rubocop:enable RSpec/NamedSubject
end
