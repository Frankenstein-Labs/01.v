# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::CreateAuditEventsService, feature_category: :package_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:namespace) { build_stubbed(:namespace) }
  let_it_be(:group_project) { build_stubbed(:project, group:) }
  let_it_be(:namespace_project) { build_stubbed(:project, namespace:) }
  let_it_be(:user) { build_stubbed(:user, maintainer_of: [group_project, namespace_project]) }
  let_it_be(:group_packages) { build_list(:nuget_package, 2, project: group_project) }
  let_it_be(:namespace_packages) { build_list(:npm_package, 2, project: namespace_project) }
  let_it_be(:packages) { group_packages + namespace_packages }
  let_it_be(:group_package_setting) do
    build_stubbed(:namespace_package_setting, audit_events_enabled: true, namespace: group)
  end

  let_it_be(:namespace_package_setting) do
    build_stubbed(:namespace_package_setting, audit_events_enabled: true, namespace: namespace)
  end

  let(:service) { described_class.new(packages, current_user: user) }

  describe '#execute', :request_store do
    subject(:execute) { service.execute }

    let(:operation) { execute }
    let(:event_type) { 'package_registry_package_deleted' }
    let(:event_count) { packages.size }
    let(:fail_condition!) { allow(service).to receive(:audit_events_enabled?).and_return(false) }

    let(:attributes) do
      packages.map do |package|
        {
          author_id: user.id,
          entity_id: package.project.group ? package.project.namespace_id : package.project_id,
          entity_type: package.project.group ? 'Group' : 'Project',
          details: {
            author_name: user.name,
            event_name: event_type,
            target_id: package.id,
            target_type: package.class.name,
            target_details: "#{package.project.full_path}/#{package.name}-#{package.version}",
            author_class: user.class.name,
            custom_message: "#{package.package_type.humanize} package deleted",
            auth_token_type: 'PersonalAccessToken'
          }
        }
      end
    end

    before do
      allow(::Namespace::PackageSetting).to receive(:with_audit_events_enabled)
        .and_return([group_package_setting, namespace_package_setting])
    end

    include_examples 'audit event logging'
  end
end
