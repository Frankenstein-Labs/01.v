# frozen_string_literal: true

RSpec.shared_examples 'graphql work item type list request spec EE' do
  include GraphqlHelpers

  # Derived from the single source of truth in
  # EE::WorkItems::TypesFramework::SystemDefined::WidgetDefinition::WIDGETS_WITH_LICENSE
  # so that adding/removing a licensed widget there is automatically picked
  # up by these shared examples.
  licensed_widgets = ::EE::WorkItems::TypesFramework::SystemDefined::WidgetDefinition::WIDGETS_WITH_LICENSE
    .group_by { |_widget_type, license| license }
    .transform_values do |entries|
      entries.map { |widget_type, _| ::WorkItems::Widgets.const_get(widget_type.camelize, false) }
    end
    .freeze

  let(:parent_key) { parent.to_ability_name.to_sym }
  let(:licensed_features) { licensed_widgets.keys }
  let(:disabled_features) { [] }
  let(:work_item_type_fields) { 'name widgetDefinitions { type }' }
  let(:returned_widgets) do
    graphql_data_at(parent_key.to_s, 'workItemTypes', 'nodes').flat_map do |type|
      type['widgetDefinitions'].pluck('type')
    end.uniq
  end

  let(:available_types) { ::WorkItems::TypesFramework::Provider.new(parent).available_types }
  let(:available_types_names) { available_types.map(&:name) }

  let(:query) do
    graphql_query_for(
      parent_key.to_s,
      { 'fullPath' => parent.full_path },
      query_nodes('WorkItemTypes', work_item_type_fields)
    )
  end

  context 'with custom work item types' do
    let(:root_namespace) { parent.resource_parent&.root_ancestor }
    let!(:custom_work_item_type) { create(:work_item_custom_type, namespace: root_namespace) }

    before do
      if parent.is_a?(Project) && parent.namespace.user_namespace?
        skip 'User namespace projects cannot have custom types'
      end

      raise 'root_namespace must not be nil for custom work item type tests' if root_namespace.nil?

      stub_licensed_features(configurable_work_item_types: true)
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    it 'returns system-defined and custom work item types' do
      post_graphql(query, current_user: current_user)

      returned_types = graphql_data_at(parent_key, :workItemTypes, :nodes)
      type_names = returned_types.pluck('name')

      expect(type_names).to include(*available_types_names)
      expect(type_names).to include(custom_work_item_type.name)

      expected_count = available_types.count
      expect(returned_types.size).to eq(expected_count)
    end

    context 'with converted work item types' do
      let!(:converted_custom_work_item_type) do
        create(:work_item_custom_type, :converted_from_issue,
          namespace: root_namespace, name: 'Issue V2')
      end

      it 'returns system-defined, custom and converted work item types' do
        post_graphql(query, current_user: current_user)

        returned_types = graphql_data_at(parent_key, :workItemTypes, :nodes)
        type_names = returned_types.pluck('name')

        converted_type_name = converted_custom_work_item_type.converted_from_system_defined_type.name
        system_defined_type_names = available_types_names - [converted_type_name]

        expect(type_names).to include(*system_defined_type_names)
        expect(type_names).to include(custom_work_item_type.name, converted_custom_work_item_type.name)

        expected_count = available_types.count
        expect(returned_types.size).to eq(expected_count)
      end
    end

    describe 'supportedConversionTypes with custom types' do
      include_context 'with work item types request context EE'

      it 'returns supported conversion types from the Provider' do
        post_graphql(query, current_user: current_user)

        returned_types = graphql_data_at(parent_key, :workItemTypes, :nodes)
        custom_type_data = returned_types.find { |t| t['name'] == custom_work_item_type.name }

        expect(custom_type_data).to be_present
        expect(custom_type_data['supportedConversionTypes']).to be_an(Array)

        conversion_type_names = custom_type_data['supportedConversionTypes'].pluck('name')
        expect(conversion_type_names).to include('Task', 'Incident')
      end

      context 'with converted work item type' do
        let!(:converted_custom_type) do
          create(:work_item_custom_type, :converted_from_issue,
            namespace: root_namespace, name: 'Bug')
        end

        it 'returns the converted custom type instead of the system-defined type' do
          post_graphql(query, current_user: current_user)

          returned_types = graphql_data_at(parent_key, :workItemTypes, :nodes)
          task_type_data = returned_types.find { |t| t['name'] == 'Task' }

          expect(task_type_data).to be_present
          conversion_type_names = task_type_data['supportedConversionTypes'].pluck('name')

          expect(conversion_type_names).to include('Bug')
          expect(conversion_type_names).not_to include('Issue')
        end
      end
    end

    describe 'hierarchy widget with custom types' do
      include_context 'with work item types request context EE'

      it 'returns hierarchy types from the Provider' do
        post_graphql(query, current_user: current_user)

        returned_types = graphql_data_at(parent_key, :workItemTypes, :nodes)
        custom_type_data = returned_types.find { |t| t['name'] == custom_work_item_type.name }

        expect(custom_type_data).to be_present

        hierarchy_widget = custom_type_data['widgetDefinitions'].find { |w| w['type'] == 'HIERARCHY' }
        expect(hierarchy_widget).to be_present

        child_type_names = hierarchy_widget.dig('allowedChildTypes', 'nodes').pluck('name')

        expect(child_type_names).to include('Task')
      end

      context 'with converted work item type' do
        let!(:converted_custom_type) do
          create(:work_item_custom_type, :converted_from_task,
            namespace: root_namespace, name: 'Subtask')
        end

        it 'returns converted custom type instead of system-defined type in hierarchy' do
          post_graphql(query, current_user: current_user)

          returned_types = graphql_data_at(parent_key, :workItemTypes, :nodes)
          issue_type_data = returned_types.find { |t| t['name'] == 'Issue' }

          expect(issue_type_data).to be_present

          hierarchy_widget = issue_type_data['widgetDefinitions'].find { |w| w['type'] == 'HIERARCHY' }
          child_type_names = hierarchy_widget.dig('allowedChildTypes', 'nodes').pluck('name')

          expect(child_type_names).to include('Subtask')
          expect(child_type_names).not_to include('Task')
        end
      end
    end
  end

  describe 'allowed statuses' do
    include_context 'with work item types request context EE'

    let(:work_item_types) { graphql_data_at(parent_key, :workItemTypes, :nodes) }
    let_it_be(:names_of_system_defined_statuses, freeze: false) do
      ::WorkItems::Statuses::SystemDefined::Status.all.map(&:name)
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      context 'with system-defined statuses' do
        it 'returns system-defined statuses for supported work item types' do
          post_graphql(query, current_user: current_user)

          work_item_types.each do |work_item_type|
            status_widgets = work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }

            status_widgets.each do |widget|
              if status_widget_supported?(work_item_type['name'])
                allowed_statuses = widget['allowedStatuses']
                status_names = allowed_statuses.pluck('name')
                default_open_status_name = widget.dig('defaultOpenStatus', 'name')
                default_closed_status_name = widget.dig('defaultClosedStatus', 'name')

                expect(allowed_statuses).to all(include('id', 'name', 'iconName', 'color', 'position'))
                expect(status_names).to match_array(names_of_system_defined_statuses)
                expect(default_open_status_name).to eq('To do')
                expect(default_closed_status_name).to eq('Done')
              else
                expect(widget['allowedStatuses']).to be_empty
                expect(widget.dig('defaultOpenStatus', 'name')).to be_empty
                expect(widget.dig('defaultClosedStatus', 'name')).to be_empty
              end
            end
          end
        end
      end

      context 'with custom statuses' do
        let(:root_namespace) { parent.resource_parent&.root_ancestor }
        let(:open_status) { create(:work_item_custom_status, :open, namespace: root_namespace) }
        let(:closed_status) { create(:work_item_custom_status, :closed, namespace: root_namespace) }
        let(:duplicate_status) { create(:work_item_custom_status, :duplicate, namespace: root_namespace) }

        let(:lifecycle) do
          create(:work_item_custom_lifecycle,
            namespace: root_namespace,
            default_open_status: open_status,
            default_closed_status: closed_status,
            default_duplicate_status: duplicate_status
          )
        end

        let(:supported_item_types) do
          [build(:work_item_system_defined_type, :task), build(:work_item_system_defined_type, :issue)]
        end

        let(:type_custom_lifecycles) do
          supported_item_types.filter_map do |work_item_type|
            if status_widget_supported?(work_item_type.name)
              create(:work_item_type_custom_lifecycle,
                lifecycle: lifecycle,
                work_item_type: work_item_type,
                namespace: root_namespace)
            end
          end
        end

        it 'returns custom statuses for supported work item types' do
          skip "No work item types support status widget" if type_custom_lifecycles.empty?

          post_graphql(query, current_user: current_user)

          expected_names = [
            open_status.name,
            closed_status.name,
            duplicate_status.name
          ]

          work_item_types.each do |work_item_type|
            status_widgets = work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }

            status_widgets.each do |widget|
              allowed_statuses = widget['allowedStatuses']
              default_open_status_name = widget.dig('defaultOpenStatus', 'name')
              default_closed_status_name = widget.dig('defaultClosedStatus', 'name')

              expect(allowed_statuses).to all(include('id', 'name', 'iconName', 'color', 'position'))
              expect(allowed_statuses.pluck('name')).to match_array(expected_names)
              expect(default_open_status_name).to eq(open_status.name)
              expect(default_closed_status_name).to eq(closed_status.name)
            end
          end
        end
      end
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(work_item_status: false)
        post_graphql(query, current_user: current_user)
      end

      it 'does not return status widget' do
        status_widgets = extract_status_widgets

        expect(status_widgets).to be_empty
      end
    end
  end

  describe 'licensed widgets' do
    before do
      stub_licensed_features(**feature_hash, epics: true)
      post_graphql(query, current_user: current_user)
    end

    where(feature_widget: licensed_widgets.transform_values { |v| Array(v) }.to_a)

    with_them do
      let(:feature) { feature_widget.first }
      let(:widgets) { feature_widget.last }

      context 'when feature is available' do
        it 'returns the associated licensed widget' do
          widgets.each do |widget|
            root_ancestor = parent&.resource_parent&.root_ancestor

            next unless widget_available_in_namespace?(widget, root_ancestor)

            expect(returned_widgets).to include(widget_to_enum_string(widget))
          end
        end
      end

      context 'when feature is not available' do
        let(:disabled_features) { [feature] }

        it 'does not return the unlincensed widgets' do
          post_graphql(query, current_user: developer)

          widgets.each do |widget|
            expect(returned_widgets).not_to include(widget_to_enum_string(widget))
          end
        end
      end
    end
  end

  def widget_available_in_namespace?(widget, namespace)
    group_only_widgets = [
      ::WorkItems::Widgets::CustomFields,
      ::WorkItems::Widgets::Iteration,
      ::WorkItems::Widgets::Status
    ]

    !(group_only_widgets.include?(widget) && namespace&.user_namespace?)
  end

  def widget_to_enum_string(widget)
    widget.type.to_s.upcase
  end

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end

  def extract_status_widgets
    work_item_types.flat_map do |work_item_type|
      work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }
    end
  end

  def status_widget_supported?(work_item_type_name)
    widget_available_for?(work_item_type_name: work_item_type_name, widget_type: 'status') &&
      parent&.resource_parent&.root_ancestor&.licensed_feature_available?(:work_item_status)
  end
end
