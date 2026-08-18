# frozen_string_literal: true

require('spec_helper')

RSpec.describe Groups::Settings::AnalyticsController, feature_category: :product_analytics do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:pointer_project) { create(:project, group: group) }

  before do
    sign_in(user)
  end

  context 'when user is not authorized' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:group_analytics_settings_available?).with(user, group).and_return(false)
      end
    end

    describe 'GET show' do
      subject(:request) { get group_settings_analytics_path(group) }

      it 'is unavailable' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'when user is authorized' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:group_analytics_settings_available?).with(user, group).and_return(true)
      end
    end

    describe 'GET show' do
      subject(:request) { get group_settings_analytics_path(group) }

      it 'renders the settings page' do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end

    describe 'PATCH update' do
      it 'redirects with expected flash' do
        params = {
          group: {
            value_stream_dashboard_aggregation_attributes: {
              enabled: true
            }
          }
        }
        patch group_settings_analytics_path(group, params)

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(group_settings_analytics_path(group))
        expect(flash[:toast]).to eq("Analytics settings for '#{group.name}' were successfully updated.")
      end

      describe 'value_stream_dashboard_aggregation_attributes' do
        where(:enabled_param, :expected_enabled_state) do
          true | true
          false | false
        end

        with_them do
          it 'sets the value' do
            params = {
              group: {
                value_stream_dashboard_aggregation_attributes: {
                  enabled: enabled_param
                }
              }
            }

            patch group_settings_analytics_path(group, params)

            aggregation = Analytics::ValueStreamDashboard::Aggregation.find_by(namespace_id: group.id)
            expect(aggregation).to be_present
            expect(aggregation.enabled).to eq(expected_enabled_state)
          end
        end
      end

      describe 'analytics_dashboards_pointer_attributes' do
        it 'sets the value' do
          params = {
            group: {
              analytics_dashboards_pointer_attributes: {
                target_project_id: pointer_project.id
              }
            }
          }

          patch group_settings_analytics_path(group, params)

          group.reload
          expect(group.analytics_dashboards_pointer).to be_present
          expect(group.analytics_dashboards_pointer.target_project_id).to eq(pointer_project.id)
        end
      end

      describe 'insight_attributes' do
        it 'sets the value' do
          params = {
            group: {
              insight_attributes: {
                project_id: pointer_project.id
              }
            }
          }

          patch group_settings_analytics_path(group, params)

          group.reload
          expect(group.insight).to be_present
          expect(group.insight.project.id).to eq(pointer_project.id)
        end
      end

      context 'when save is unsuccessful' do
        before do
          allow_next_instance_of(::Groups::UpdateService) do |instance|
            allow(instance).to receive(:execute).and_return(false)
          end
        end

        it 'redirects back to form with error' do
          params = {
            group: {
              value_stream_dashboard_aggregation_attributes: {
                enabled: true
              }
            }
          }
          patch group_settings_analytics_path(group, params)

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(group_settings_analytics_path(group))
          expect(flash[:alert]).to eq('Unable to update analytics settings. Please try again.')
        end
      end
    end
  end
end
