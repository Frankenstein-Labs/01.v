# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuablePolicy, :models, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:non_member) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:planner) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:developer) { create(:user) }

  def permissions(user, issue)
    described_class.new(user, issue)
  end

  describe '#rules' do
    shared_examples 'issuable resource links access' do
      it 'disallows non members' do
        expect(permissions(non_member, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(non_member, incident_issue)).to be_disallowed(:read_issuable_resource_link)
      end

      it 'disallows guests' do
        expect(permissions(guest, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(guest, incident_issue)).to be_disallowed(:read_issuable_resource_link)
      end

      it 'disallows planners' do
        expect(permissions(planner, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(planner, incident_issue)).to be_disallowed(:read_issuable_resource_link)
      end

      it 'disallows all on non-incident issue type' do
        expect(permissions(non_member, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(guest, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(developer, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(planner, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(reporter, issue)).to be_disallowed(:admin_issuable_resource_link)
        expect(permissions(non_member, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(guest, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(developer, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(planner, issue)).to be_disallowed(:read_issuable_resource_link)
        expect(permissions(reporter, issue)).to be_disallowed(:read_issuable_resource_link)
      end
    end

    shared_examples 'measure comment temperature' do
      describe 'measure_comment_temperature' do
        let(:user) { developer }
        let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

        subject { permissions(user, issue) }

        where(:feature_flag_enabled, :user_allowed, :expected_result) do
          true  | true  | be_allowed(:measure_comment_temperature)
          true  | false | be_disallowed(:measure_comment_temperature)
          false | true  | be_disallowed(:measure_comment_temperature)
          false | false | be_disallowed(:measure_comment_temperature)
        end

        with_them do
          before do
            stub_feature_flags(comment_temperature: feature_flag_enabled)
            allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
            allow(authorizer).to receive(:allowed?).and_return(user_allowed)
          end

          it { is_expected.to expected_result }
        end
      end
    end

    context 'in a public project' do
      let_it_be(:project) { create(:project, :public) }
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be(:guest_issue) { create(:issue, project: project, author: guest) }
      let_it_be(:planner_issue) { create(:issue, project: project, author: planner) }
      let_it_be(:reporter_issue) { create(:issue, project: project, author: reporter) }
      let_it_be(:incident_issue) { create(:incident, project: project, author: developer) }

      before_all do
        project.add_guest(guest)
        project.add_planner(planner)
        project.add_reporter(reporter)
        project.add_developer(developer)
      end

      it 'disallows non-members from creating and deleting metric images' do
        expect(permissions(non_member, issue)).to be_allowed(:read_issuable_metric_image)
        expect(permissions(non_member, issue)).to be_disallowed(:upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      it 'allows guests to read, create metric images, and delete them in their own issues' do
        expect(permissions(guest, issue)).to be_allowed(:read_issuable_metric_image)
        expect(permissions(guest, issue)).to be_disallowed(:upload_issuable_metric_image, :delete_issuable_metric_image)

        expect(permissions(guest, guest_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      it 'allows planners to create and delete metric images' do
        expect(permissions(planner, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
        expect(permissions(planner, planner_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      it 'allows reporters to create and delete metric images' do
        expect(permissions(reporter, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
        expect(permissions(reporter, reporter_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      context 'Create, read, delete issuable resource links' do
        context 'when available' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:issuable_resource_links_available?).with(project).and_return(true)
          end

          it_behaves_like 'issuable resource links access'
          it_behaves_like 'measure comment temperature'

          it 'allows developers' do
            expect(permissions(developer, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(developer, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end

          it 'allows reporters' do
            expect(permissions(reporter, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(reporter, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end
        end

        context 'when not available' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:issuable_resource_links_available?).with(project).and_return(false)
          end

          it_behaves_like 'issuable resource links access'
          it_behaves_like 'measure comment temperature'

          it 'disallows developers' do
            expect(permissions(developer, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
            expect(permissions(developer, incident_issue)).to be_disallowed(:read_issuable_resource_link)
          end

          it 'disallows reporters' do
            expect(permissions(reporter, incident_issue)).to be_disallowed(:admin_issuable_resource_link)
            expect(permissions(reporter, incident_issue)).to be_disallowed(:read_issuable_resource_link)
          end
        end
      end
    end

    context 'in a private project' do
      let_it_be(:project) { create(:project, :private) }
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be(:guest_issue) { create(:issue, project: project, author: guest) }
      let_it_be(:planner_issue) { create(:issue, project: project, author: planner) }
      let_it_be(:reporter_issue) { create(:issue, project: project, author: reporter) }
      let_it_be(:incident_issue) { create(:incident, project: project, author: developer) }

      before_all do
        project.add_guest(guest)
        project.add_planner(planner)
        project.add_reporter(reporter)
        project.add_developer(developer)
      end

      it 'disallows non-members from creating and deleting metric images' do
        expect(permissions(non_member, issue)).to be_disallowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      it 'allows guests to read metric images, and create + delete in their own issues' do
        expect(permissions(guest, issue)).to be_allowed(:read_issuable_metric_image)
        expect(permissions(guest, issue)).to be_disallowed(:upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)

        expect(permissions(guest, guest_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      it 'allows planners to create and delete metric images' do
        expect(permissions(planner, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
        expect(permissions(planner, planner_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      it 'allows reporters to create and delete metric images' do
        expect(permissions(reporter, issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
        expect(permissions(reporter, reporter_issue)).to be_allowed(:read_issuable_metric_image, :upload_issuable_metric_image, :update_issuable_metric_image, :delete_issuable_metric_image)
      end

      context 'Create, read, delete issuable resource links' do
        context 'when available' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:issuable_resource_links_available?).with(project).and_return(true)
          end

          it_behaves_like 'issuable resource links access'
          it_behaves_like 'measure comment temperature'

          it 'allows developers' do
            expect(permissions(developer, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(developer, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end

          it 'allows reporters' do
            expect(permissions(reporter, incident_issue)).to be_allowed(:admin_issuable_resource_link)
            expect(permissions(reporter, incident_issue)).to be_allowed(:read_issuable_resource_link)
          end
        end
      end
    end

    describe 'trigger_amazon_q' do
      let_it_be(:group) { create(:group, :private) }
      let_it_be_with_reload(:project) { create(:project, :private, group: group) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let_it_be(:guest_issue) { create(:issue, project: project, author: guest) }
      let(:user) { developer }
      let(:amazon_q_enabled) { true }

      before_all do
        project.add_guest(guest)
        project.add_reporter(reporter)
        project.add_developer(developer)
      end

      where(:user_role, :issuable_type, :duo_features_enabled, :amazon_q_enabled, :expected_result) do
        :developer  | :guest_issue         | true  | true  | :be_allowed
        :developer  | :non_persisted_issue | true  | true  | :be_allowed
        :developer  | :merge_request       | true  | true  | :be_allowed
        :non_member | :merge_request       | true  | true  | :be_disallowed
        :developer  | :epic                | true  | true  | :be_disallowed
        :reporter   | :guest_issue         | true  | true  | :be_disallowed
        :developer  | :guest_issue         | false | true  | :be_disallowed
        :developer  | :guest_issue         | true  | false | :be_disallowed
      end

      with_them do
        it 'returns the correct permission' do
          user = send(user_role)
          issuable = case issuable_type
                     when :guest_issue then guest_issue
                     when :non_persisted_issue then build(:issue, project: project)
                     when :merge_request then merge_request
                     when :epic then build(:epic, group: project.group)
                     end

          if duo_features_enabled == false
            project.update!(duo_features_enabled: false)
            project.namespace.namespace_settings.update!(duo_features_enabled: true)
          end

          allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)

          expect(permissions(user, issuable)).to send(expected_result, :trigger_amazon_q)
        end
      end
    end
  end
end
