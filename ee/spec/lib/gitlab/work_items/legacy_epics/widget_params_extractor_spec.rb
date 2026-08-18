# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::WorkItems::LegacyEpics::WidgetParamsExtractor, feature_category: :team_planning do
  describe '.extract_widget_params' do
    let(:epic_work_item_type) { double }

    before do
      stub_const('::WorkItems::TypesFramework::Provider', double).tap do |klass|
        instance = double
        allow(klass).to receive(:new).and_return(instance)
        allow(instance).to receive(:find_by_base_type).with(:epic).and_return(epic_work_item_type)
      end
    end

    context 'with empty params' do
      it 'returns empty widget params and sets work_item_type' do
        params = {}

        result_params, widget_params = described_class.new(params).extract

        expect(widget_params).to be_empty
        expect(result_params[:work_item_type]).to eq(epic_work_item_type)
      end
    end

    context 'with description widget params' do
      it 'extracts description params' do
        params = { description: 'Epic description', other_param: 'value' }

        result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:description_widget]).to eq({ description: 'Epic description' })
        expect(result_params).to eq({ other_param: 'value', work_item_type: epic_work_item_type })
      end
    end

    context 'with labels widget params' do
      it 'extracts label_ids separately' do
        params = { label_ids: [1, 2], other_param: 'value' }

        result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:labels_widget]).to eq({
          label_ids: [1, 2],
          add_label_ids: nil,
          remove_label_ids: nil
        })
        expect(result_params).to eq({ other_param: 'value', work_item_type: epic_work_item_type })
      end

      it 'keeps label_ids and add_label_ids separate' do
        params = { label_ids: [1, 2], add_label_ids: [3, 4], remove_label_ids: [5, 6] }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:labels_widget]).to eq({
          label_ids: [1, 2],
          add_label_ids: [3, 4],
          remove_label_ids: [5, 6]
        })
      end

      it 'handles only add_label_ids' do
        params = { add_label_ids: [3, 4] }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:labels_widget]).to eq({
          label_ids: nil,
          add_label_ids: [3, 4],
          remove_label_ids: nil
        })
      end

      it 'handles only remove_label_ids' do
        params = { remove_label_ids: [5, 6] }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:labels_widget]).to eq({
          label_ids: nil,
          add_label_ids: nil,
          remove_label_ids: [5, 6]
        })
      end
    end

    context 'with hierarchy widget params' do
      let(:parent_epic) { instance_double('Epic', id: 123) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      let(:parent_work_item) { double }

      before do
        allow(parent_epic).to receive(:work_item).and_return(parent_work_item)
        stub_const('Epic', double).tap do |epic_class|
          allow(epic_class).to receive(:find_by_id).and_return(parent_epic)
        end
      end

      it 'extracts parent_id and finds the work item' do
        params = { parent_id: parent_epic.id }
        allow(Epic).to receive(:find_by_id).with(parent_epic.id).and_return(parent_epic)

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:hierarchy_widget]).to eq({ parent: parent_work_item })
      end

      it 'extracts parent and finds the work item' do
        params = { parent: parent_epic.id }
        allow(Epic).to receive(:find_by_id).with(parent_epic.id).and_return(parent_epic)

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:hierarchy_widget]).to eq({ parent: parent_work_item })
      end

      it 'returns nil when epic is not found' do
        params = { parent_id: 999 }
        allow(Epic).to receive(:find_by_id).with(999).and_return(nil)

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:hierarchy_widget]).to be_nil
      end

      it 'returns nil when epic has no work_item' do
        params = { parent_id: parent_epic.id }
        allow(Epic).to receive(:find_by_id).with(parent_epic.id).and_return(parent_epic)
        allow(parent_epic).to receive(:work_item).and_return(nil)

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:hierarchy_widget]).to be_nil
      end

      it 'returns {parent: nil} when parent_id is explicitly nil' do
        params = { parent_id: nil }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:hierarchy_widget]).to eq({ parent: nil })
      end

      it 'returns {parent: nil} when parent is explicitly nil' do
        params = { parent: nil }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:hierarchy_widget]).to eq({ parent: nil })
      end

      it 'returns nil when no hierarchy params are provided' do
        params = { other_param: 'value' }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params).not_to have_key(:hierarchy_widget)
      end
    end

    context 'with start_and_due_date widget params' do
      it 'extracts due_date_fixed' do
        params = { due_date_fixed: '2024-12-31' }

        result_params, widget_params = described_class.new(params).extract

        expect(result_params[:work_item_type]).to eq(epic_work_item_type)
        expect(widget_params[:start_and_due_date_widget]).to eq({
          due_date: '2024-12-31'
        })
      end

      it 'prefers due_date_fixed over end_date' do
        params = { due_date_fixed: '2024-12-31', end_date: '2024-11-30' }

        result_params, widget_params = described_class.new(params).extract

        expect(result_params[:work_item_type]).to eq(epic_work_item_type)
        expect(widget_params[:start_and_due_date_widget]).to eq({
          due_date: '2024-12-31'
        })
      end

      it 'falls back to end_date when due_date_fixed not present' do
        params = { end_date: '2024-11-30' }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:start_and_due_date_widget]).to eq({
          due_date: '2024-11-30'
        })
      end

      it 'extracts start_date_fixed' do
        params = { start_date_fixed: '2024-01-01' }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:start_and_due_date_widget]).to eq({
          start_date: '2024-01-01'
        })
      end

      it 'prefers start_date_fixed over start_date' do
        params = { start_date_fixed: '2024-01-01', start_date: '2024-02-01' }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:start_and_due_date_widget]).to eq({
          start_date: '2024-01-01'
        })
      end

      it 'extracts is_fixed from due_date_is_fixed' do
        params = { due_date_is_fixed: true }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:start_and_due_date_widget]).to eq({
          is_fixed: true
        })
      end

      it 'extracts is_fixed from start_date_is_fixed' do
        params = { start_date_is_fixed: false }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:start_and_due_date_widget]).to eq({
          is_fixed: false
        })
      end

      it 'combines all date params correctly' do
        params = {
          start_date_fixed: '2024-01-01',
          due_date_fixed: '2024-12-31',
          due_date_is_fixed: true,
          start_date: '2024-02-01',
          end_date: '2024-11-30'
        }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:start_and_due_date_widget]).to eq({
          start_date: '2024-01-01',
          due_date: '2024-12-31',
          is_fixed: true
        })
      end
    end

    context 'with color widget params' do
      it 'extracts color params directly' do
        params = { color: '#FF0000' }

        _result_params, widget_params = described_class.new(params).extract

        expect(widget_params[:color_widget]).to eq({ color: '#FF0000' })
      end
    end

    context 'with multiple widget params' do
      let(:parent_epic) { instance_double('Epic', id: 123) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      let(:parent_work_item) { double }

      before do
        allow(parent_epic).to receive(:work_item).and_return(parent_work_item)
        stub_const('Epic', double).tap do |epic_class|
          allow(epic_class).to receive(:find_by_id).with(parent_epic.id).and_return(parent_epic)
        end
      end

      it 'extracts all widget types correctly' do
        params = {
          description: 'Epic description',
          label_ids: [1, 2],
          parent_id: parent_epic.id,
          start_date_fixed: '2024-01-01',
          due_date_fixed: '2024-12-31',
          color: '#FF0000',
          other_param: 'should remain'
        }

        result_params, widget_params = described_class.new(params).extract

        expect(widget_params).to eq({
          description_widget: { description: 'Epic description' },
          labels_widget: {
            label_ids: [1, 2],
            add_label_ids: nil,
            remove_label_ids: nil
          },
          hierarchy_widget: { parent: parent_work_item },
          start_and_due_date_widget: { start_date: '2024-01-01', due_date: '2024-12-31' },
          color_widget: { color: '#FF0000' }
        })

        expect(result_params).to eq({
          other_param: 'should remain',
          work_item_type: epic_work_item_type
        })
      end
    end
  end
end
