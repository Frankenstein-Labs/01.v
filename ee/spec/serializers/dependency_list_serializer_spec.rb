# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyListSerializer do
  let_it_be(:project) { create(:project, :repository, :private) }
  let_it_be(:user) { create(:user) }

  let(:dependencies) { [build_stubbed(:sbom_occurrence, :with_vulnerabilities, :mit)] }

  let(:serializer) do
    described_class.new(project: project, user: user).represent(dependencies)
  end

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true, license_scanning: true)
  end

  describe "#to_json" do
    subject { serializer.to_json }

    it 'matches the schema' do
      is_expected.to match_schema('dependency_list', dir: 'ee')
    end
  end
end
