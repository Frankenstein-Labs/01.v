# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ValueStreams::ListService, feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }

  let(:params) { {} }
  let(:service) { described_class.new(parent: parent, params: params, current_user: user) }

  subject(:service_response) { service.execute }

  shared_examples 'value stream list service examples' do
    context 'when the resource is licensed' do
      before do
        stub_licensed_features(licensed_feature_name => true)
      end

      it 'returns the no value streams' do
        expect(service_response).to be_success
        expect(service_response.payload[:value_streams]).to be_empty
      end

      context 'when value stream records are present' do
        let_it_be(:value_stream1) { create(:cycle_analytics_value_stream, namespace: parent, name: 'bbb') }
        let_it_be(:value_stream2) { create(:cycle_analytics_value_stream, namespace: parent, name: 'aaa') }

        it 'returns the value streams' do
          expect(service_response).to be_success
          expect(service_response.payload[:value_streams]).to match([
            have_attributes(name: value_stream2.name),
            have_attributes(name: value_stream1.name)
          ])
        end

        context 'when filtering by value stream ids' do
          before do
            params[:value_stream_ids] = [value_stream2.id]
          end

          it 'returns the filtered value stream' do
            expect(service_response).to be_success
            expect(service_response.payload[:value_streams]).to match([
              have_attributes(name: value_stream2.name)
            ])
          end
        end
      end

      context 'when the user is not allowed to access the service' do
        let(:user) { create(:user) }

        it 'returns failed service response' do
          expect(service_response).to be_error
        end
      end
    end
  end

  context 'when project namespace is given' do
    let(:licensed_feature_name) { :cycle_analytics_for_projects }

    let_it_be(:parent) do
      project = create(:project)
      project.add_developer(user)
      project.project_namespace
    end

    it_behaves_like 'value stream list service examples'

    context 'when project is not licensed' do
      it 'returns the default value stream' do
        expect(service_response).to be_success
        expect(service_response.payload[:value_streams]).to match([have_attributes(name: 'default')])
      end
    end
  end

  context 'when group is given' do
    let(:licensed_feature_name) { :cycle_analytics_for_groups }

    let_it_be(:parent) { create(:group).tap { |g| g.add_developer(user) } }

    it_behaves_like 'value stream list service examples'

    context 'when group is not licensed' do
      it 'returns failed service response' do
        expect(service_response).to be_error
      end
    end
  end
end
