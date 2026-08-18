# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::Base, feature_category: :dependency_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let(:occurrence_maps) { [instance_double('Sbom::Ingestion::OccurrenceMap')] }

  describe '#filter_invalid_objects' do
    let(:task_instance) { described_class.new(pipeline, occurrence_maps) }
    let(:component) { create(:sbom_component, organization: organization) }

    context 'when all objects are valid' do
      let(:valid_occurrence1) { build(:sbom_occurrence, project: project, component: component, pipeline: pipeline) }
      let(:valid_occurrence2) { build(:sbom_occurrence, project: project, component: component, pipeline: pipeline) }

      it 'does not filter any objects' do
        expect(Gitlab::AppLogger).not_to receive(:warn)

        result = task_instance.send(:filter_invalid_objects, [valid_occurrence1, valid_occurrence2])
        expect(result).to contain_exactly(valid_occurrence1, valid_occurrence2)
      end
    end

    context 'when some objects are invalid' do
      let(:valid_occurrence) { build(:sbom_occurrence, project: project, component: component, pipeline: pipeline) }
      let(:invalid_occurrence) do
        build(:sbom_occurrence, project: project, component: component, pipeline: pipeline, licenses: 'invalid json')
      end

      it 'filters out invalid objects and logs a warning' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          message: "Components failed validation during SBoM ingestion",
          project_id: project.id,
          errors: [{
            model: 'Sbom::Occurrence',
            attribute_name: "licenses",
            attribute_value: "invalid json",
            error: "Licenses must be a valid json schema"
          }]
        )

        result = task_instance.send(:filter_invalid_objects, [valid_occurrence, invalid_occurrence])
        expect(result).to contain_exactly(valid_occurrence)
      end
    end

    context 'when all objects are invalid' do
      let(:invalid_occurrence1) do
        build(:sbom_occurrence, project: project, component: component, pipeline: pipeline, licenses: 'invalid json')
      end

      let(:invalid_occurrence2) do
        build(:sbom_occurrence, project: project, component: component, pipeline: pipeline, licenses: '{"bad": json}')
      end

      it 'filters out all objects and logs a warning' do
        expect(Gitlab::AppLogger).to receive(:warn).once

        result = task_instance.send(:filter_invalid_objects, [invalid_occurrence1, invalid_occurrence2])
        expect(result).to be_empty
      end
    end
  end

  describe 'bulk operations' do
    let(:concrete_class) do
      Class.new(described_class) do
        self.model = Sbom::Occurrence
        self.unique_by = %i[uuid].freeze
        self.uses = %i[id].freeze

        def attributes
          []
        end
      end
    end

    let(:task_instance) { concrete_class.new(pipeline, occurrence_maps) }

    describe '#bulk_insert' do
      it 'calls bulk_insert! with validate: false' do
        allow(task_instance).to receive(:insert_objects).and_return([])

        expect(task_instance.send(:klass)).to receive(:bulk_insert!).with(
          [],
          skip_duplicates: true,
          returns: %i[id],
          validate: false
        )

        task_instance.send(:bulk_insert)
      end
    end

    describe '#bulk_upsert' do
      it 'calls bulk_upsert! with validate: false' do
        allow(task_instance).to receive_messages(insert_objects: [], attribute_names: %w[uuid created_at])

        expect(task_instance.send(:klass)).to receive(:bulk_upsert!).with(
          [],
          unique_by: %i[uuid],
          returns: %i[id],
          validate: false
        )

        task_instance.send(:bulk_upsert)
      end
    end
  end

  describe '#each_pair' do
    context 'when implementation does not have unique_by columns in uses' do
      let(:implementation) do
        Class.new(described_class) do
          self.model = Sbom::ComponentVersion
          self.unique_by = %i[component_id version].freeze
          self.uses = %i[id].freeze

          def execute
            each_pair do |map, row|
              map.id = row.first
            end
          end
        end
      end

      it 'raises an ArgumentError' do
        expect { implementation.execute(pipeline, occurrence_maps) }.to raise_error(
          ArgumentError,
          'All unique_by attributes must be included in returned columns'
        )
      end
    end

    context 'when implementation does not have unique_by' do
      let(:implementation) do
        Class.new(described_class) do
          self.model = Sbom::ComponentVersion
          self.uses = %i[id].freeze

          def execute
            each_pair do |map, row|
              map.id = row.first
            end
          end
        end
      end

      it 'raises an ArgumentError' do
        expect { implementation.execute(pipeline, occurrence_maps) }.to raise_error(
          ArgumentError,
          '#each_pair can only be used with unique_by attributes'
        )
      end
    end
  end
end
