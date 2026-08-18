# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ValueStreamActions, feature_category: :value_stream_management do
  let_it_be(:group) { build(:group) }
  let_it_be(:project) { build(:project, group: group) }
  let_it_be(:current_user) { build(:user) }

  subject(:controller_class) do
    Class.new(ApplicationController) do
      include Analytics::CycleAnalytics::ValueStreamActions

      def call_data_attributes
        data_attributes
      end
    end
  end

  describe '#data_attributes' do
    subject(:controller) { controller_class.new }

    before do
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(controller).to receive(:vsa_path).and_return('gdk.test/test_path')
    end

    shared_examples 'data attributes for frontend' do
      it 'returns the expected result for new endpoint' do
        expect(controller.call_data_attributes.keys).to contain_exactly(
          :default_stages,
          :namespace,
          :vsa_path,
          :full_path,
          :is_project,
          :value_stream_gid,
          :group_path,
          :stage_events
        )
      end

      it 'returns the expected result for edit endpoint' do
        allow(controller).to receive(:action_name).and_return('edit')
        allow(controller).to receive(:value_stream).and_return(
          build(:cycle_analytics_value_stream, name: 'test', namespace: group)
        )

        expect(controller.call_data_attributes.keys).to contain_exactly(
          :default_stages,
          :namespace,
          :vsa_path,
          :full_path,
          :is_project,
          :value_stream_gid,
          :group_path,
          :stage_events
        )
      end
    end

    describe 'for groups' do
      before do
        allow(controller).to receive(:namespace).and_return(group)
      end

      it_behaves_like 'data attributes for frontend'

      it 'returns the correct group path' do
        expect(controller.call_data_attributes[:group_path]).to eq(group.full_path)
      end
    end

    describe 'for projects' do
      before do
        allow(controller).to receive(:namespace).and_return(project.project_namespace)
      end

      it_behaves_like 'data attributes for frontend'

      it 'returns the correct group path' do
        expect(controller.call_data_attributes[:group_path]).to eq(project.group.full_path)
      end
    end
  end
end
