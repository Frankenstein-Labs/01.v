# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.lifecycleTemplates', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be_with_refind(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:namespace) { group }
  let(:query) do
    <<~QUERY
    query {
      namespace(fullPath: "#{namespace.full_path}") {
        id
        lifecycleTemplates {
          id
          name
          workItemTypes {
            id
            name
          }
          statuses {
            id
            name
            color
            description
            category
            iconName
          }
          defaultOpenStatus {
            id
            name
            color
            description
            category
            iconName
          }
          defaultClosedStatus {
            id
            name
            color
            description
            category
            iconName
          }
          defaultDuplicateStatus {
            id
            name
            color
            description
            category
            iconName
          }
        }
      }
    }
    QUERY
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  context 'when user has permission to read lifecycle templates' do
    context 'with only system defined statuses' do
      it 'returns lifecycle templates with system defined attributes' do
        post_graphql(query, current_user: guest)

        expect(response).to have_gitlab_http_status(:ok)

        templates = graphql_data_at(:namespace, :lifecycleTemplates)
        expect(templates.size).to eq(WorkItems::Statuses::SystemDefined::Lifecycle.all.size)

        template = templates.first
        system_defined_lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first

        expect(template).to include(
          'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Lifecycle/Default',
          'name' => system_defined_lifecycle.name,
          'workItemTypes' => []
        )

        template['statuses'].each do |status|
          system_defined_status = system_defined_lifecycle.statuses.find { |s| s.name == status['name'] }
          expect(status).to include(
            'id' => status_template_gid(system_defined_status.name),
            'name' => system_defined_status.name,
            'color' => system_defined_status.color,
            'description' => system_defined_status.description,
            'category' => system_defined_status.category.to_s,
            'iconName' => system_defined_status.icon_name
          )
        end

        expect(template['defaultOpenStatus']).to include(
          'id' => status_template_gid(system_defined_lifecycle.default_open_status.name),
          'name' => system_defined_lifecycle.default_open_status.name,
          'color' => system_defined_lifecycle.default_open_status.color,
          'description' => system_defined_lifecycle.default_open_status.description,
          'category' => system_defined_lifecycle.default_open_status.category.to_s,
          'iconName' => system_defined_lifecycle.default_open_status.icon_name
        )

        expect(template['defaultClosedStatus']).to include(
          'id' => status_template_gid(system_defined_lifecycle.default_closed_status.name),
          'name' => system_defined_lifecycle.default_closed_status.name,
          'color' => system_defined_lifecycle.default_closed_status.color,
          'description' => system_defined_lifecycle.default_closed_status.description,
          'category' => system_defined_lifecycle.default_closed_status.category.to_s,
          'iconName' => system_defined_lifecycle.default_closed_status.icon_name
        )

        expect(template['defaultDuplicateStatus']).to include(
          'id' => status_template_gid(system_defined_lifecycle.default_duplicate_status.name),
          'name' => system_defined_lifecycle.default_duplicate_status.name,
          'color' => system_defined_lifecycle.default_duplicate_status.color,
          'description' => system_defined_lifecycle.default_duplicate_status.description,
          'category' => system_defined_lifecycle.default_duplicate_status.category.to_s,
          'iconName' => system_defined_lifecycle.default_duplicate_status.icon_name
        )
      end
    end

    context 'with custom statuses' do
      let!(:custom_status) do
        create(:work_item_custom_status,
          namespace: namespace,
          name: 'To do',
          color: '#000000',
          description: 'Custom description',
          category: :to_do
        )
      end

      it 'returns lifecycle templates with merged custom attributes' do
        post_graphql(query, current_user: guest)

        expect(response).to have_gitlab_http_status(:ok)

        template = graphql_data_at(:namespace, :lifecycleTemplates).first
        system_defined_lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first

        expect(template).to include(
          'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Lifecycle/Default',
          'name' => system_defined_lifecycle.name,
          'workItemTypes' => []
        )

        template['statuses'].each do |status|
          if status['name'] == 'To do'
            # Custom status should have custom attributes
            expect(status).to include(
              'id' => status_template_gid('To do'),
              'name' => 'To do',
              'color' => '#000000',
              'description' => 'Custom description',
              'category' => 'to_do',
              'iconName' => 'status-waiting'
            )
          else
            # System defined statuses should have system attributes
            system_defined_status = system_defined_lifecycle.statuses.find { |s| s.name == status['name'] }
            expect(status).to include(
              'id' => status_template_gid(system_defined_status.name),
              'name' => system_defined_status.name,
              'color' => system_defined_status.color,
              'description' => system_defined_status.description,
              'category' => system_defined_status.category.to_s,
              'iconName' => system_defined_status.icon_name
            )
          end
        end

        expect(template['defaultOpenStatus']).to include(
          'id' => status_template_gid('To do'),
          'name' => 'To do',
          'color' => '#000000',
          'description' => 'Custom description',
          'category' => 'to_do',
          'iconName' => 'status-waiting'
        )

        expect(template['defaultClosedStatus']).to include(
          'id' => status_template_gid(system_defined_lifecycle.default_closed_status.name),
          'name' => system_defined_lifecycle.default_closed_status.name,
          'color' => system_defined_lifecycle.default_closed_status.color,
          'description' => system_defined_lifecycle.default_closed_status.description,
          'category' => system_defined_lifecycle.default_closed_status.category.to_s,
          'iconName' => system_defined_lifecycle.default_closed_status.icon_name
        )

        expect(template['defaultDuplicateStatus']).to include(
          'id' => status_template_gid(system_defined_lifecycle.default_duplicate_status.name),
          'name' => system_defined_lifecycle.default_duplicate_status.name,
          'color' => system_defined_lifecycle.default_duplicate_status.color,
          'description' => system_defined_lifecycle.default_duplicate_status.description,
          'category' => system_defined_lifecycle.default_duplicate_status.category.to_s,
          'iconName' => system_defined_lifecycle.default_duplicate_status.icon_name
        )
      end
    end
  end

  context 'when user does not have permission to read lifecycle templates' do
    it 'does not return lifecycle templates' do
      post_graphql(query, current_user: create(:user))

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :lifecycleTemplates, :nodes)).to be_blank
    end
  end

  context 'when feature is not available' do
    before do
      stub_licensed_features(work_item_status: false)
    end

    it 'does not return lifecycle templates' do
      post_graphql(query, current_user: guest)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:namespace, :lifecycleTemplates, :nodes)).to be_blank
    end
  end

  def status_template_gid(name)
    "gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/#{CGI.escape(name)}"
  end
end
