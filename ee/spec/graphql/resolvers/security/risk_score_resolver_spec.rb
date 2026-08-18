# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::RiskScoreResolver, :elastic_delete_by_query, :sidekiq_inline, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_risk_score) do
    context = { current_user: user }
    context[:project_id] = project_id_filter if defined?(project_id_filter)
    resolve(described_class, obj: operate_on, args: {}, ctx: context)
  end

  let(:current_user) { user }
  let(:resolved_value) { resolved_risk_score }

  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }
  let_it_be(:project3) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  let_it_be(:vulnerabilities) do
    [
      create(:vulnerability, :with_finding, severity: :low, report_type: :sast, project: project1),
      create(:vulnerability, :with_finding, severity: :medium, report_type: :dast, project: project1),
      create(:vulnerability, :with_finding, severity: :high, report_type: :dependency_scanning, project: project1),
      create(:vulnerability, :with_finding, severity: :critical, report_type: :sast, project: project2)
    ]
  end

  describe '#resolve' do
    before do
      stub_licensed_features(security_dashboard: true)
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    shared_examples 'returns risk score data' do
      context 'when the current user has access' do
        before_all do
          group.add_developer(user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(*vulnerabilities)
          ensure_elasticsearch_index!
        end

        it 'returns risk score data with correct structure' do
          result = resolved_risk_score

          expect(result).to include(
            score: be_a(Numeric),
            rating: be_in(%w[low medium high critical unknown]),
            project_count: be_a(Numeric)
          )
        end

        it 'returns valid rating based on score' do
          result = resolved_risk_score
          score = result[:score]
          rating = result[:rating]

          expected_rating = case score
                            when 0..25.9 then 'low'
                            when 26..50.9 then 'medium'
                            when 51..75.9 then 'high'
                            when 76..100 then 'critical'
                            else 'unknown'
                            end

          expect(rating).to eq(expected_rating)
        end

        context 'when by_project data is present' do
          it 'includes project-level risk scores' do
            result = resolved_risk_score

            if result[:by_project].present?
              expect(result[:by_project]).to be_an(Array)

              expect(result[:by_project]).to all(
                include(
                  project: be_a(Project),
                  score: be_a(Numeric),
                  rating: be_in(%w[low medium high critical unknown])
                )
              )
            end
          end

          it 'includes only accessible projects' do
            result = resolved_risk_score

            if result[:by_project].present?
              project_ids = result[:by_project].map { |p| p[:project].id }
              accessible_project_ids = operate_on.projects.pluck(:id)

              expect(project_ids).to all(be_in(accessible_project_ids))
            end
          end
        end

        context 'when Elasticsearch returns risk_score_by_project with actual project data' do
          before do
            allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
              allow(finder).to receive(:execute).and_return({
                total_risk_score: 0.655,
                total_project_count: 3,
                risk_score_by_project: {
                  project1.id => 0.505,
                  project2.id => 0.752,
                  project3.id => 0.308
                }
              })
            end
          end

          it 'returns by_project data with correct project objects and scores' do
            result = resolved_risk_score

            expect(result).to include(
              score: 65.5,
              rating: 'high',
              project_count: 3
            )

            if result[:by_project].present?
              expect(result[:by_project]).to be_an(Array)
              expect(result[:by_project].length).to eq(3)

              # Verify each project data contains the correct structure
              result[:by_project].each do |project_data|
                expect(project_data).to include(
                  project: be_a(Project),
                  score: be_a(Numeric),
                  rating: be_a(String)
                )

                # Verify the project is one of our test projects
                expect([project1.id, project2.id, project3.id]).to include(project_data[:project].id)
              end
            end
          end

          it 'maps project IDs to actual project objects correctly' do
            result = resolved_risk_score

            if result[:by_project].present?
              expect(result[:by_project]).to be_present

              # Extract project IDs from the result
              returned_project_ids = result[:by_project].map { |p| p[:project].id }

              # Verify all expected projects are included
              expect(returned_project_ids).to match_array([project1.id, project2.id, project3.id])

              # Verify each project has the correct score from Elasticsearch
              project1_data = result[:by_project].find { |p| p[:project].id == project1.id }
              expect(project1_data[:score]).to eq(50.5)
              expect(project1_data[:rating]).to eq('medium')

              project2_data = result[:by_project].find { |p| p[:project].id == project2.id }
              expect(project2_data[:score]).to eq(75.2)
              expect(project2_data[:rating]).to eq('high')

              project3_data = result[:by_project].find { |p| p[:project].id == project3.id }
              expect(project3_data[:score]).to eq(30.8)
              expect(project3_data[:rating]).to eq('medium')
            end
          end

          it 'correctly calculates ratings for each project score' do
            result = resolved_risk_score

            if result[:by_project].present?
              expect(result[:by_project]).to be_present

              result[:by_project].each do |project_data|
                score = project_data[:score]
                rating = project_data[:rating]

                expected_rating = case score
                                  when 0..25.9 then 'low'
                                  when 26..50.9 then 'medium'
                                  when 51..75.9 then 'high'
                                  when 76..100 then 'critical'
                                  else 'unknown'
                                  end

                expect(rating).to eq(expected_rating)
              end
            end
          end
        end

        context 'with project_id filter' do
          let(:project_id_filter) { [project1.id] }

          it 'filters by specific projects' do
            result = resolved_risk_score

            expect(result).to include(
              score: be_a(Numeric),
              rating: be_in(%w[low medium high critical unknown])
            )
          end

          it 'only includes filtered projects in by_project data' do
            result = resolved_risk_score

            if result[:by_project].present?
              project_ids = result[:by_project].map { |p| p[:project].id }
              expect(project_ids).to all(be_in(project_id_filter))
            end
          end
        end

        context 'with multiple project_id filters' do
          let(:project_id_filter) { [project1.id, project2.id] }

          it 'includes all filtered projects' do
            result = resolved_risk_score

            expect(result).to include(
              score: be_a(Numeric),
              rating: be_in(%w[low medium high critical unknown])
            )

            if result[:by_project].present?
              project_ids = result[:by_project].map { |p| p[:project].id }
              expect(project_ids).to match_array(project_id_filter & operate_on.projects.pluck(:id))
            end
          end
        end

        context 'when Elasticsearch returns empty data' do
          before do
            allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
              allow(finder).to receive(:execute).and_return({})
            end
          end

          it 'returns nil' do
            result = resolved_risk_score
            expect(result).to be_nil
          end
        end

        context 'when Elasticsearch returns data without by_project' do
          before do
            allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
              allow(finder).to receive(:execute).and_return({
                total_risk_score: 0.5,
                total_project_count: 2,
                risk_score_by_project: nil
              })
            end
          end

          it 'returns score without by_project data' do
            result = resolved_risk_score

            expect(result).to include(
              score: 50,
              rating: 'medium',
              project_count: 2
            )
            expect(result[:by_project]).to be_nil
          end
        end

        context 'when Elasticsearch returns empty by_project hash' do
          before do
            allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
              allow(finder).to receive(:execute).and_return({
                total_risk_score: 0.5,
                total_project_count: 0,
                risk_score_by_project: {}
              })
            end
          end

          it 'returns score without by_project data' do
            result = resolved_risk_score

            expect(result).to include(
              score: 50,
              rating: 'medium',
              project_count: 0
            )
            expect(result[:by_project]).to be_nil
          end
        end

        context 'when Elasticsearch fails' do
          before do
            allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
              allow(finder).to receive(:execute).and_raise(StandardError, 'ES connection failed')
            end
          end

          it 'returns nil and tracks the error' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))

            result = resolved_risk_score

            expect(result).to be_nil
          end
        end

        context 'when risk score is nil' do
          before do
            allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
              allow(finder).to receive(:execute).and_return({
                total_risk_score: nil,
                total_project_count: 0,
                risk_score_by_project: nil
              })
            end
          end

          it 'returns unknown rating for nil score' do
            result = resolved_risk_score

            expect(result).to include(
              score: nil,
              rating: 'unknown',
              project_count: 0
            )
          end
        end
      end

      context 'when calcultating rating for specific score' do
        before_all do
          group.add_developer(user)
        end

        shared_examples 'returns correct rating' do |score, expected_rating|
          before do
            allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
              allow(finder).to receive(:execute).and_return({
                total_risk_score: score,
                total_project_count: 1,
                risk_score_by_project: nil
              })
            end
          end

          it "returns '#{expected_rating}' rating for score #{score}" do
            result = resolved_risk_score
            expect(result[:rating]).to eq(expected_rating)
          end
        end

        context 'when low risk scores' do
          it_behaves_like 'returns correct rating', 0, 'low'
          it_behaves_like 'returns correct rating', 0.1, 'low'
          it_behaves_like 'returns correct rating', 0.259, 'low'
        end

        context 'when medium risk scores' do
          it_behaves_like 'returns correct rating', 0.26, 'medium'
          it_behaves_like 'returns correct rating', 0.4, 'medium'
          it_behaves_like 'returns correct rating', 0.509, 'medium'
        end

        context 'when high risk scores' do
          it_behaves_like 'returns correct rating', 0.51, 'high'
          it_behaves_like 'returns correct rating', 0.65, 'high'
          it_behaves_like 'returns correct rating', 0.759, 'high'
        end

        context 'when critical risk scores' do
          it_behaves_like 'returns correct rating', 0.76, 'critical'
          it_behaves_like 'returns correct rating', 0.9, 'critical'
          it_behaves_like 'returns correct rating', 1.0, 'critical'
        end

        context 'when risk scores is not known' do
          it_behaves_like 'returns correct rating', -0.01, 'unknown'
          it_behaves_like 'returns correct rating', 1.01, 'unknown'
          it_behaves_like 'returns correct rating', nil, 'unknown'
        end
      end
    end

    shared_examples 'returns nil' do
      it 'returns nil' do
        expect(resolved_risk_score).to be_nil
      end
    end

    context 'when operated on an organization' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:org_root_group_a) { create(:group, organization: organization) }
      let_it_be(:org_root_group_b) { create(:group, organization: organization) }
      let_it_be(:org_project_a) { create(:project, :public, group: org_root_group_a, organization: organization) }
      let_it_be(:org_project_b) { create(:project, :public, group: org_root_group_b, organization: organization) }
      let_it_be(:org_owner) { create(:organization_user, :owner, organization: organization).user }

      let_it_be(:org_vulnerabilities) do
        [
          create(:vulnerability, :with_finding_risk_score, :confirmed, severity: :high, project: org_project_a),
          create(:vulnerability, :with_finding_risk_score, :detected, severity: :critical, project: org_project_b)
        ]
      end

      let(:user) { org_owner }
      let(:operate_on) { organization }

      before do
        set_elasticsearch_migration_to(:backfill_organization_id_in_vulnerabilities)
        Elastic::ProcessBookkeepingService.track!(*org_vulnerabilities)
        ensure_elasticsearch_index!
      end

      it 'resolves the risk score with a by-project breakdown aggregated across the organization',
        :aggregate_failures do
        result = resolved_risk_score

        expect(result).to include(
          score: be_a(Numeric),
          rating: be_in(%w[low medium high critical unknown]),
          project_count: 2
        )
        expect(result[:by_project].map { |entry| entry[:project].id })
          .to match_array([org_project_a.id, org_project_b.id])
      end
    end

    context 'when operated on a group' do
      let(:operate_on) { group }

      it_behaves_like 'returns risk score data'

      context 'when ES total count exceeds returned buckets due to subgroup projects' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:subgroup_project1) { create(:project, group: subgroup) }
        let_it_be(:subgroup_project2) { create(:project, group: subgroup) }

        before_all do
          group.add_developer(user)
        end

        before do
          es_buckets = {
            project1.id => 0.5,
            project2.id => 0.6,
            project3.id => 0.4,
            subgroup_project1.id => 0.7,
            subgroup_project2.id => 0.3
          }

          allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
            allow(finder).to receive(:execute).and_return({
              total_risk_score: 0.55,
              total_project_count: 109,
              risk_score_by_project: es_buckets
            })
          end
        end

        it 'includes subgroup projects in by_project' do
          result = resolved_risk_score

          expect(result[:by_project].length).to eq(5)

          expect(result[:project_count]).to eq(109)

          project_ids = result[:by_project].map { |p| p[:project].id }

          expect(project_ids).to match_array([
            project1.id,
            project2.id,
            project3.id,
            subgroup_project1.id,
            subgroup_project2.id
          ])
        end
      end

      # #security
      context 'when user has read_vulnerability but not read_project on private projects' do
        let_it_be(:private_project) { create(:project, :private, group: group) }
        let_it_be(:attacker) { create(:user) }
        let_it_be(:member_role) do
          create(:member_role, :minimal_access, namespace: group, read_vulnerability: true)
        end

        subject(:resolved_risk_score_for_attacker) do
          resolve(described_class, obj: group, args: {}, ctx: { current_user: attacker })
        end

        before_all do
          create(:group_member, :minimal_access, member_role: member_role, source: group, user: attacker)
        end

        before do
          stub_licensed_features(security_dashboard: true, custom_roles: true)
          allow_next_instance_of(::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder) do |finder|
            allow(finder).to receive(:execute).and_return({
              total_risk_score: 0.5,
              total_project_count: 1,
              risk_score_by_project: {
                private_project.id => 0.5
              }
            })
          end
        end

        it 'does not expose private project data to unauthorized user' do
          result = resolved_risk_score_for_attacker

          if result && result[:by_project].present?
            project_ids = result[:by_project].map { |p| p[:project].id }
            expect(project_ids).not_to include(private_project.id)
          end
        end
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end

      context 'when security_dashboard feature flag is disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it_behaves_like 'returns resource not available'
      end

      context 'when validating advanced vulnerability management' do
        before_all do
          group.add_developer(user)
        end

        it_behaves_like 'validates advanced vulnerability management'
      end

      it 'maps parameters as expected' do
        group.add_developer(user)

        context = {
          current_user: user,
          project_id: project1.id,
          tracked_ref_ids: 123
        }
        expected_params = {
          project_id: project1.id,
          group_by: :project,
          security_project_tracked_context_id: 123,
          has_resolution: false
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder)
          .to receive(:new)
          .with(group, expected_params)
          .and_call_original

        resolve(described_class, obj: operate_on, args: {}, ctx: context)
      end
    end

    context 'when operated on a project' do
      let(:operate_on) { project1 }

      it_behaves_like 'returns risk score data'

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available'
      end

      context 'when security_dashboard feature flag is disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it_behaves_like 'returns resource not available'
      end

      context 'when validating advanced vulnerability management' do
        before_all do
          project1.add_developer(user)
        end

        it_behaves_like 'validates advanced vulnerability management'
      end

      it 'maps parameters as expected' do
        project1.add_developer(user)

        context = {
          current_user: user,
          project_id: project1.id,
          tracked_ref_ids: 123
        }
        expected_params = {
          project_id: project1.id,
          security_project_tracked_context_id: 123,
          has_resolution: false
        }

        expect(Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder)
          .to receive(:new)
          .with(project1, expected_params)
          .and_call_original

        resolve(described_class, obj: operate_on, args: {}, ctx: context)
      end
    end

    context 'when operated on an instance security dashboard' do
      let(:operate_on) { InstanceSecurityDashboard.new(user) }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(security_dashboard: true)
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      end

      it 'skips authorization check for instance security dashboard' do
        expect(described_class).not_to receive(:authorize!)
      end
    end
  end
end
