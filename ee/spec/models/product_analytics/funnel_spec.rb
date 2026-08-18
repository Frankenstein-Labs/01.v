# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::Funnel, feature_category: :product_analytics do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :with_product_analytics_funnel, group: group) }
  let_it_be(:project_invalid_seconds) { create(:project, :with_invalid_seconds_product_analytics_funnel, group: group) }

  let_it_be(:project_invalid_step_name) do
    create(:project, :with_invalid_step_name_product_analytics_funnel, group: group)
  end

  let_it_be(:project_invalid_step_target) do
    create(:project, :with_invalid_step_target_product_analytics_funnel, group: group)
  end

  let(:query) do
    <<-SQL
        SELECT
          (SELECT max(derived_tstamp) FROM gitlab_project_#{project.id}.snowplow_events) as x,
          arrayJoin(range(1, 3)) AS level,
          sumIf(c, user_level >= level) AS count
        FROM
          (SELECT
             level AS user_level,
             count(*) AS c
           FROM (
               SELECT
                 user_id,
                 windowFunnel(3600, 'strict_order')(toDateTime(derived_tstamp),
                    page_urlpath = '/page1.html', page_urlpath = '/page2.html'
                 ) AS level
               FROM gitlab_project_#{project.id}.snowplow_events
               WHERE ${FILTER_PARAMS.funnel_example_1.date.filter('derived_tstamp')}
               GROUP BY user_id
               )
           GROUP BY level
          )
          GROUP BY level
	        ORDER BY level ASC
    SQL
  end

  before do
    allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
    stub_licensed_features(product_analytics: true)
  end

  subject(:funnel) { described_class.for_project(project).first }

  it { is_expected.to validate_numericality_of(:seconds_to_convert) }

  context 'when the funnel has invalid seconds' do
    subject(:funnel) { described_class.for_project(project_invalid_seconds).first }

    it { is_expected.to be_invalid }
  end

  context 'when the funnel has invalid step name' do
    subject(:funnel) { described_class.for_project(project_invalid_step_name).first }

    it { is_expected.to be_invalid }
  end

  context 'when the funnel has invalid step target' do
    subject(:funnel) { described_class.for_project(project_invalid_step_target).first }

    it { is_expected.to be_invalid }
  end

  describe '.for_project' do
    subject(:funnels) { described_class.for_project(project) }

    it 'returns a collection of funnels' do
      expect(funnels).to be_a(Array)
      expect(funnels.first).to be_a(described_class)
      expect(funnels.first.name).to eq('funnel_example_1')
      expect(funnels.first.project).to eq(project)
      expect(funnels.first.seconds_to_convert).to eq(3600)
    end

    it 'has a collection of steps' do
      expect(funnels.first.steps.size).to eq(2)
      expect(funnels.first.steps).to be_a(Array)
      expect(funnels.first.steps.first).to be_a(ProductAnalytics::FunnelStep)
      expect(funnels.first.steps.first.name).to eq('view_page_1')
      expect(funnels.first.steps.first.target).to eq('/page1.html')
      expect(funnels.first.steps.first.action).to eq('pageview')
    end

    context 'when the funnel directory includes a file that is not a yaml file' do
      before do
        project.repository.create_file(
          project.creator,
          '.gitlab/product_analytics/funnels/randomfile.txt',
          'not a yaml file',
          message: 'Add funnel definition',
          branch_name: 'master'
        )
      end

      it 'does not include the file in the collection' do
        expect(funnels.size).to eq(1)
      end
    end

    context 'when the project does not have a funnels directory' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :repository, group: group) }

      it { is_expected.to be_empty }
    end
  end

  describe '.from_diff' do
    context 'when a file is created' do
      let_it_be(:project) { create(:project, :repository, group: group) }

      before_all do
        create_valid_funnel
      end

      subject(:funnel) { described_class.from_diff(project.repository.commit.deltas.last, project: project) }

      it { is_expected.to be_a(described_class) }

      it 'has the correct values', :aggregate_failures do
        expect(funnel.name).to eq('example1')
        expect(funnel.previous_name).to be_nil
        expect(funnel.project).to eq(project)
        expect(funnel.seconds_to_convert).to eq(3600)
        expect(funnel.steps.size).to eq(2)
        expect(funnel.steps.first.name).to eq('view_page_1')
        expect(funnel.steps.first.target).to eq('/page1.html')
        expect(funnel.steps.first.action).to eq('pageview')
      end
    end

    context 'when a file content is updated without renaming the file' do
      let_it_be(:project) { create(:project, :repository, group: group) }

      before_all do
        create_valid_funnel
        update_contents_of_funnel
      end

      subject(:funnel) do
        described_class.from_diff(project.repository.commit.deltas.last, project: project,
          commit: project.repository.commit)
      end

      it { is_expected.to be_a(described_class) }

      it 'has the correct values', :aggregate_failures do
        expect(funnel.name).to eq('example1')
        expect(funnel.previous_name).to be_nil
        expect(funnel.project).to eq(project)
        expect(funnel.seconds_to_convert).to eq(3600)
        expect(funnel.steps.size).to eq(2)
        expect(funnel.steps.first.name).to eq('view_page_2')
        expect(funnel.steps.first.target).to eq('/page2.html')
        expect(funnel.steps.first.action).to eq('pageview')
      end
    end

    context 'when a file is renamed' do
      let_it_be(:project) { create(:project, :repository, group: group) }

      before_all do
        create_valid_funnel
        rename_funnel
      end

      subject(:funnel) do
        described_class.from_diff(project.repository.commit.deltas.last, project: project,
          commit: project.repository.commit)
      end

      it { is_expected.to be_a(described_class) }

      it 'has the correct values', :aggregate_failures do
        expect(funnel.name).to eq('example2')
        expect(funnel.previous_name).to eq('example1')
        expect(funnel.project).to eq(project)
        expect(funnel.seconds_to_convert).to eq(3600)
        expect(funnel.steps.size).to eq(2)
        expect(funnel.steps.first.name).to eq('view_page_1')
        expect(funnel.steps.first.target).to eq('/page1.html')
        expect(funnel.steps.first.action).to eq('pageview')
      end
    end
  end

  describe '#to_h' do
    subject { described_class.for_project(project).first.to_h }

    let(:object) do
      {
        name: 'funnel_example_1',
        schema: query,
        steps: ["page_urlpath = '/page1.html'", "page_urlpath = '/page2.html'"]
      }
    end

    it { is_expected.to eq(object) }

    context 'when the funnel has invalid seconds' do
      subject { described_class.for_project(project_invalid_seconds).first.to_h }

      it { is_expected.to be_nil }
    end

    context 'when the funnel has invalid step name' do
      subject { described_class.for_project(project_invalid_step_name).first.to_h }

      it { is_expected.to be_nil }
    end

    context 'when the funnel has invalid step target' do
      subject { described_class.for_project(project_invalid_step_target).first.to_h }

      it { is_expected.to be_nil }
    end
  end

  describe '#to_json' do
    subject { described_class.for_project(project).first.to_json }

    let(:object) do
      {
        name: 'funnel_example_1',
        schema: query,
        steps: ["page_urlpath = '/page1.html'", "page_urlpath = '/page2.html'"]
      }.to_json
    end

    it { is_expected.to eq(object) }

    context 'when the funnel has invalid seconds' do
      subject { described_class.for_project(project_invalid_seconds).first.to_json }

      it { is_expected.to eq('null') }
    end

    context 'when the funnel has invalid step name' do
      subject { described_class.for_project(project_invalid_step_name).first.to_json }

      it { is_expected.to eq('null') }
    end

    context 'when the funnel has invalid step target' do
      subject { described_class.for_project(project_invalid_step_target).first.to_json }

      it { is_expected.to eq('null') }
    end
  end

  describe '#to_sql' do
    subject { described_class.for_project(project).first.to_sql }

    it { is_expected.to eq(query) }

    context 'when the funnel has invalid seconds' do
      subject { described_class.for_project(project_invalid_seconds).first.to_sql }

      it { is_expected.to be_nil }
    end

    context 'when the funnel has invalid step name' do
      subject { described_class.for_project(project_invalid_step_name).first.to_sql }

      it { is_expected.to be_nil }
    end

    context 'when the funnel has invalid step target' do
      subject { described_class.for_project(project_invalid_step_target).first.to_sql }

      it { is_expected.to be_nil }
    end
  end

  private

  def create_valid_funnel
    project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_1.yaml')),
      message: 'Add funnel',
      branch_name: 'master'
    )
  end

  def update_contents_of_funnel
    project.repository.update_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_changed.yaml')),
      message: 'Update funnel',
      branch_name: 'master'
    )
  end

  def rename_funnel
    project.repository.update_file(
      project.creator,
      '.gitlab/analytics/funnels/example2.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_1.yaml')),
      message: 'Rename funnel',
      branch_name: 'master',
      previous_path: '.gitlab/analytics/funnels/example1.yml'
    )
  end
end
