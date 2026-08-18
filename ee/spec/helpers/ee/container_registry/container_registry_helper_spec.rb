# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::ContainerRegistryHelper, feature_category: :container_registry do
  let_it_be(:project) { build_stubbed(:project, :repository) }
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:admin) { build_stubbed(:admin) }
  let_it_be(:container_expiration_policy) { build_stubbed(:container_expiration_policy, project: project) }

  before_all do
    project.add_maintainer(user)
    project.add_maintainer(admin)
  end

  describe '#project_container_registry_template_data' do
    subject(:project_container_registry_template_data) do
      helper.project_container_registry_template_data(project, connection_error, invalid_path_error)
    end

    let(:connection_error) { nil }
    let(:invalid_path_error) { nil }

    it 'returns the correct template data' do
      allow(helper).to receive(:current_user).and_return(user)

      expect(project_container_registry_template_data).to include(
        security_configuration_path: helper.project_security_configuration_path(project),
        vulnerability_report_path: helper.project_security_vulnerability_report_index_path(project,
          tab: :CONTAINER_REGISTRY)
      )
    end
  end
end
