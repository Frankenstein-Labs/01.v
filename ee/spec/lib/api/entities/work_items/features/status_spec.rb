# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::Status, feature_category: :portfolio_management do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::StatusType,
    exceptions: %w[widget_definition]

  describe '#as_json' do
    let(:status_object) do
      instance_double(
        WorkItems::Statuses::SystemDefined::Status,
        id: 1,
        name: 'To do',
        icon_name: 'status-waiting',
        color: '#737278',
        position: 0,
        description: nil,
        category: :to_do
      ).tap do |s|
        allow(s).to receive(:to_gid).and_return(
          Gitlab::GlobalId.build(s, id: 1)
        )
      end
    end

    let(:work_item) do
      instance_double(WorkItem).tap do |wi|
        allow(wi).to receive(:status_with_fallback).and_return(status_object)
      end
    end

    let(:widget) do
      instance_double(WorkItems::Widgets::Status, work_item: work_item)
    end

    subject(:representation) { described_class.new(widget).as_json }

    it 'exposes the status fields' do
      aggregate_failures do
        expect(representation[:status]).to include(
          name: 'To do',
          icon_name: 'status-waiting',
          color: '#737278',
          position: 0,
          category: 'to_do'
        )
        expect(representation[:status][:id]).to be_a(String)
      end
    end

    context 'when status is nil' do
      let(:work_item) do
        instance_double(WorkItem).tap do |wi|
          allow(wi).to receive(:status_with_fallback).and_return(nil)
        end
      end

      it 'exposes nil status' do
        expect(representation[:status]).to be_nil
      end
    end

    context 'when category is nil' do
      let(:status_object) do
        instance_double(
          WorkItems::Statuses::SystemDefined::Status,
          id: 1,
          name: 'To do',
          icon_name: 'status-waiting',
          color: '#737278',
          position: 0,
          description: nil,
          category: nil
        ).tap do |s|
          allow(s).to receive(:to_gid).and_return(
            Gitlab::GlobalId.build(s, id: 1)
          )
        end
      end

      it 'exposes nil category' do
        expect(representation[:status][:category]).to be_nil
      end
    end
  end
end
