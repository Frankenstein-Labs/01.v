# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::TypesFramework::SystemDefined::WidgetDefinition, feature_category: :team_planning do
  describe '.widget_types' do
    subject(:widget_types) { described_class.widget_types }

    it 'includes all EE-specific widget types' do
      ee_widget_types = %w[
        agent_plan
        ai_session
        health_status
        weight
        iteration
        progress
        verification_status
        requirement_legacy
        test_reports
        color
        status
        custom_fields
        vulnerabilities
      ]

      expect(widget_types).to include(*ee_widget_types)
    end
  end

  describe '#licensed?' do
    shared_examples 'widget license checking' do
      context 'when widget type has a license requirement' do
        shared_examples 'requirements license check' do |widget_type, licence_name, work_item_type_id|
          let(:widget_definition) do
            build(:work_item_system_defined_widget_definition, widget_type: widget_type,
              work_item_type_id: work_item_type_id)
          end

          it "returns true when the requirement license is available" do
            setup_license_available(licence_name.to_sym)
            expect(widget_definition.licensed?(resource_parent)).to be true
          end

          it 'returns false when requirements license is not available' do
            setup_license_not_available(licence_name.to_sym)
            expect(widget_definition.licensed?(resource_parent)).to be false
          end
        end

        it_behaves_like 'requirements license check', 'agent_plan', 'ai_workflows', 1 # for issue type
        it_behaves_like 'requirements license check', 'ai_session', 'ai_workflows', 1 # for issue type
        it_behaves_like 'requirements license check', 'health_status', 'issuable_health_status', 1 # for issue type
        it_behaves_like 'requirements license check', 'iteration', 'iterations', 1
        it_behaves_like 'requirements license check', 'weight', 'issue_weights', 1
        it_behaves_like 'requirements license check', 'verification_status', 'requirements', 4 # for requirement type
        it_behaves_like 'requirements license check', 'requirement_legacy', 'requirements', 4
        it_behaves_like 'requirements license check', 'test_reports', 'requirements', 4
        it_behaves_like 'requirements license check', 'progress', 'okrs', 6 # for objective type
        it_behaves_like 'requirements license check', 'color', 'epic_colors', 8 # for epic type
        it_behaves_like 'requirements license check', 'custom_fields', 'custom_fields', 1
        it_behaves_like 'requirements license check', 'vulnerabilities', 'security_dashboard', 1
        it_behaves_like 'requirements license check', 'status', 'work_item_status', 1
      end

      context 'when widget type does not have a license requirement' do
        context 'with CE widget types' do
          let(:ce_widget_types) do
            %w[
              assignees
              description
              labels
              milestone
              notes
              hierarchy
            ]
          end

          it 'returns true for all CE widgets without checking license' do
            ce_widget_types.each do |widget_type|
              widget_definition = build(:work_item_system_defined_widget_definition, widget_type: widget_type)

              setup_no_license_expectations
              expect(widget_definition.licensed?(resource_parent)).to be true
            end
          end
        end
      end

      context 'when resource_parent is nil for a licenced widget' do
        let(:widget_definition) { build(:work_item_system_defined_widget_definition, widget_type: 'iteration') }

        it 'returns false when resource_parent is nil' do
          expect(widget_definition.licensed?(nil)).to be(false)
        end
      end
    end

    context 'when resource_parent is a project' do
      let(:resource_parent) { build(:project) }

      def setup_license_available(license_name)
        expect(resource_parent).to receive(:licensed_feature_available?)
          .with(license_name)
          .and_return(true)
      end

      def setup_license_not_available(license_name)
        expect(resource_parent).to receive(:licensed_feature_available?)
          .with(license_name)
          .and_return(false)
      end

      def setup_no_license_expectations
        expect(resource_parent).not_to receive(:licensed_feature_available?)
      end

      it_behaves_like 'widget license checking'
    end

    context 'when resource_parent is an organization' do
      let(:resource_parent) { build_stubbed(:organization) }

      def setup_license_available(license_name)
        allow(License).to receive(:feature_available?)
          .with(license_name)
          .and_return(true)
      end

      def setup_license_not_available(license_name)
        allow(License).to receive(:feature_available?)
          .with(license_name)
          .and_return(false)
      end

      def setup_no_license_expectations
        expect(resource_parent).not_to receive(:licensed_feature_available?)
        # Allow other non-widget license checks
        allow(License).to receive(:feature_available?).and_call_original
      end

      it_behaves_like 'widget license checking'
    end
  end

  describe '#build_widget' do
    let(:work_item) { build(:work_item, :epic) }

    context 'with widget_options' do
      let(:definition) { build(:work_item_system_defined_widget_definition, widget_type: 'hierarchy') }

      it 'passes widget_definition with options to the widget' do
        widget = definition.build_widget(work_item)
        widget_def = widget.instance_variable_get(:@widget_definition)

        expect(widget_def.widget_options).to eq(definition.widget_options)
      end
    end
  end

  describe '#work_item_type' do
    context 'when work_item_type_id is for a system-defined type' do
      let(:system_type) { build(:work_item_system_defined_type, :issue) }
      let(:widget_definition) do
        build(:work_item_system_defined_widget_definition, widget_type: 'description',
          work_item_type_id: system_type.id)
      end

      it 'returns the system-defined type' do
        expect(widget_definition.work_item_type).to eq(system_type)
      end
    end

    context 'when work_item_type_id is for a custom type' do
      let!(:custom_type) { create(:work_item_custom_type) }
      let!(:widget_definition) do
        build(:work_item_system_defined_widget_definition, widget_type: 'description') do |wd|
          # WidgetDefinition is a FixedItemsModel with pre-populated items that only reference
          # system-defined types. We manually set work_item_type_id to a custom type's ID to
          # simulate the scenario where Custom::Type#widget_definitions clones definitions
          # and overrides work_item_type_id to point to the custom type.
          wd.work_item_type_id = custom_type.id
        end
      end

      it 'returns the custom type' do
        expect(widget_definition.work_item_type).to eq(custom_type)
      end
    end

    context 'when work_item_type_id does not exist in either system-defined or custom types' do
      let(:widget_definition) do
        build(:work_item_system_defined_widget_definition, widget_type: 'description') do |wd|
          wd.work_item_type_id = non_existing_record_id
        end
      end

      it 'returns nil' do
        expect(widget_definition.work_item_type).to be_nil
      end
    end
  end
end
