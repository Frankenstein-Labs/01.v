# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_elasticsearch_form', feature_category: :global_search do
  include RenderedHtml

  let(:admin) { build_stubbed(:admin) }

  let(:elastic_reindexing_task)    { build(:elastic_reindexing_task) }
  let(:elasticsearch_available)    { false }
  let(:es_indexing)                { false }
  let(:halted_migrations)          { false }
  let(:page)                       { rendered_html }
  let(:pause_indexing)             { false }
  let(:pending_migrations)         { false }
  let(:projects_not_indexed_count) { 0 }
  let(:projects_not_indexed)       { [] }

  let(:subtask) do
    build_stubbed(
      :elastic_reindexing_subtask,
      documents_count: 0,
      documents_count_target: 0
    )
  end

  let(:fake_subtasks) { [subtask] }

  let(:task) do
    build_stubbed(:elastic_reindexing_task).tap do |t|
      allow(fake_subtasks).to receive(:order_by_alias_name_asc).and_return(fake_subtasks)

      allow(t).to receive_messages(subtasks: fake_subtasks, in_progress?: true, error_message: nil, state: :in_progress)
    end
  end

  before do
    assign(:application_setting, application_setting)
    assign(:elasticsearch_reindexing_task, elastic_reindexing_task)
    assign(:projects_not_indexed_count, projects_not_indexed_count)
    assign(:projects_not_indexed, projects_not_indexed)
    assign(:last_elasticsearch_reindexing_task, task)

    allow(Elastic::DataMigrationService).to receive_messages(halted_migrations?: halted_migrations,
      pending_migrations?: pending_migrations)
    allow(Elastic::IndexSetting).to receive(:every_alias).and_return([])
    allow(Search::Elastic::Helper).to receive_message_chain(:default, :ping?).and_return(elasticsearch_available)
    allow(Gitlab::CurrentSettings).to receive_messages(elasticsearch_indexing?: es_indexing,
      elasticsearch_pause_indexing?: pause_indexing)
    allow(view).to receive(:current_user) { admin }
    allow(view).to receive(:expanded).and_return(true)
  end

  describe 'es indexing' do
    let(:application_setting) { build(:application_setting) }
    let(:button_text) { 'Index the instance' }

    context 'when indexing is enabled' do
      let(:es_indexing) { true }

      it 'hides index button when indexing is disabled' do
        render

        expect(rendered).to have_css('a.btn-confirm', text: button_text)
      end

      context 'when indexing is enabled' do
        let(:es_indexing) { true }
        let(:pause_indexing) { false }
        let(:task) do
          build_stubbed(:elastic_reindexing_task).tap do |t|
            allow(t).to receive(:in_progress?).and_return(false) # Ensure task is not in progress
          end
        end

        before do
          assign(:last_elasticsearch_reindexing_task, task)

          allow(Gitlab::CurrentSettings).to receive_messages(elasticsearch_indexing?: es_indexing,
            elasticsearch_pause_indexing?: pause_indexing)
        end

        it 'renders an enabled pause checkbox' do
          render

          expect(rendered).to have_css('input[id=application_setting_elasticsearch_pause_indexing]')
          expect(rendered)
            .not_to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
        end
      end

      context 'when pending migrations exist' do
        using RSpec::Parameterized::TableSyntax

        let(:elasticsearch_available) { true }
        let(:pending_migrations) { true }
        let(:migration) { Elastic::DataMigrationService.migrations.first }
        let(:task) do
          build_stubbed(:elastic_reindexing_task, state: :success, in_progress: false)
        end

        before do
          allow(Elastic::DataMigrationService).to receive(:pending_migrations).and_return([migration])
          allow(migration).to receive_messages(running?: running, pause_indexing?: pause_indexing)
          assign(:last_elasticsearch_reindexing_task, task)
        end

        where(:running, :pause_indexing, :disabled) do
          false | false | false
          false | true  | false
          true  | false | false
          true  | true  | true
        end

        with_them do
          it 'renders pause checkbox with disabled set appropriately' do
            render

            if disabled
              expect(rendered)
                .to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
            else
              expect(rendered)
                .not_to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
            end
          end
        end
      end
    end

    context 'when indexing is disabled' do
      let(:es_indexing) { false }

      it 'shows index button when indexing is enabled' do
        render

        expect(rendered).not_to have_css('a.btn-confirm', text: button_text)
      end

      it 'renders a disabled pause checkbox' do
        render

        expect(rendered).to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
      end
    end
  end

  describe 'shard setting' do
    context 'when number of shards is set' do
      let(:application_setting) { build(:application_setting, elasticsearch_worker_number_of_shards: 4) }

      it 'has field with "Number of shards for non-code indexing" label and correct value' do
        render
        expect(rendered).to have_field('Number of shards for non-code indexing')
        expect(page.find_field('Number of shards for non-code indexing').value).to eq('4')
      end
    end
  end

  describe 'aws' do
    context 'when elasticsearch_aws_secret_access_key is not set' do
      let(:application_setting) { build(:application_setting) }

      it 'has field with "AWS Secret Access Key" label and no value' do
        render
        expect(rendered).to have_field('AWS Secret Access Key', type: 'password')
        expect(page.find_field('AWS Secret Access Key').value).to be_blank
      end
    end

    context 'when elasticsearch_aws_secret_access_key is set' do
      let(:application_setting) do
        build(:application_setting, elasticsearch_aws_secret_access_key: 'elasticsearch_aws_secret_access_key')
      end

      it 'has field with "Enter new AWS Secret Access Key" label and a masked value' do
        render
        expect(rendered).to have_field('Enter new AWS Secret Access Key', type: 'password')
        expect(page.find_field('Enter new AWS Secret Access Key').value).to eq(ApplicationSetting::MASK_PASSWORD)
      end
    end
  end

  describe 'zero-downtime elasticsearch reindexing' do
    let(:application_setting) { build(:application_setting) }
    let(:subtask) { build_stubbed(:elastic_reindexing_subtask) }
    let(:task) do
      build_stubbed(:elastic_reindexing_task).tap do |t|
        allow(t).to receive_message_chain(:subtasks, :order_by_alias_name_asc).and_return([subtask])
        allow(t).to receive_messages(in_progress?: true, error_message: nil)
      end
    end

    before do
      assign(:application_setting, application_setting)
      assign(:last_elasticsearch_reindexing_task, task)
    end

    context 'when task is in progress' do
      let(:task) { build(:elastic_reindexing_task, state: :reindexing) }

      it 'renders a disabled pause checkbox' do
        render

        expect(rendered).to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
      end

      it 'renders a disabled trigger cluster reindexing link' do
        render

        expect(rendered).to have_button('Trigger cluster reindexing', disabled: true)
      end
    end

    context 'without extended details' do
      let(:task) { build(:elastic_reindexing_task) }
      let(:application_setting) { build_stubbed(:application_setting) }

      before do
        assign(:application_setting, application_setting)
        assign(:last_elasticsearch_reindexing_task, task)
        assign(:elasticsearch_reindexing_human_state, "starting")
        assign(:elasticsearch_reindexing_human_state_color, "tip")

        allow(view).to receive(:expanded).and_return(true)
      end

      it 'renders the task' do
        render

        expect(rendered).to have_selector('[role="alert"]', text: /Status: starting/)
        expect(rendered).not_to have_selector('[role="alert"]', text: /Error: error-message/)
      end
    end

    context 'with extended details' do
      let(:application_setting) { build(:application_setting) }
      let(:task) do
        build_stubbed(:elastic_reindexing_task, state: :reindexing, error_message: 'error-message').tap do |t|
          allow(t).to receive_messages(in_progress?: true, state: :reindexing, documents_count: 50,
            documents_count_target: 100)
        end
      end

      let(:subtask) do
        build_stubbed(:elastic_reindexing_subtask,
          elastic_reindexing_task: task,
          documents_count_target: 100,
          documents_count: 50
        )
      end

      let(:ordered_subtasks) { [subtask] }
      let(:elasticsearch_available) { true }

      before do
        assign(:application_setting, application_setting)
        assign(:last_elasticsearch_reindexing_task, task)

        allow(task).to receive(:subtasks).and_return(ordered_subtasks)
        allow(ordered_subtasks).to receive_messages(count: 1, any?: true, order_by_alias_name_asc: ordered_subtasks)

        assign(:elasticsearch_reindexing_human_state, "reindexing")
        assign(:elasticsearch_reindexing_human_state_color, "info")

        allow(License).to receive(:feature_available?).with(:elastic_search).and_return(true)
        allow(License).to receive(:current).and_return(true)
        allow(Elastic::IndexSetting).to receive(:exists?).and_return(true)
      end

      it 'renders the task information' do
        render
        expect(rendered).to have_selector('[role="alert"]', text: /Status: reindexing/)
        expect(rendered).to have_selector('[role="alert"]', text: /Error: error-message/)
      end
    end

    context 'when there are 0 documents expected' do
      let(:task) do
        build_stubbed(:elastic_reindexing_task, state: :reindexing)
      end

      let(:subtask) do
        build_stubbed(
          :elastic_reindexing_subtask,
          elastic_reindexing_task: task,
          documents_count_target: 0,
          documents_count: 0
        )
      end

      before do
        allow(task).to receive_message_chain(:subtasks, :order_by_alias_name_asc).and_return([subtask])
        allow(task.subtasks).to receive_messages(any?: true, count: 1)
        assign(:last_elasticsearch_reindexing_task, task)
        assign(:application_setting, build(:application_setting))
        assign(:projects_not_indexed_count, 0)
        assign(:projects_not_indexed, [])
        assign(:elasticsearch_reindexing_human_state, "successfully indexed")
        assign(:elasticsearch_reindexing_human_state_color, "success")
      end

      it 'renders successfully indexed' do
        render

        expect(rendered).to have_selector('[role="alert"]', text: /Status: successfully indexed/)
        expect(rendered).not_to have_selector('[role="alert"]', text: /Error: error-message/)
      end
    end
  end

  describe 'limited indexing' do
    context 'when there are elasticsearch indexed namespaces' do
      let(:application_setting) { build(:application_setting, elasticsearch_limit_indexing: true) }

      it 'shows the input' do
        render
        expect(rendered).to have_selector('.js-namespaces-indexing-restrictions')
      end

      context 'when there are too many elasticsearch indexed namespaces' do
        before do
          allow(view).to receive(:elasticsearch_too_many_namespaces?).and_return(true)
        end

        it 'hides the input' do
          render
          expect(rendered).not_to have_selector('.js-namespaces-indexing-restrictions')
        end
      end
    end

    context 'when there are elasticsearch indexed projects' do
      let(:application_setting) { build(:application_setting, elasticsearch_limit_indexing: true) }

      before do
        allow(view).to receive(:elasticsearch_too_many_projects?).and_return(false)
      end

      it 'shows the input' do
        render
        expect(rendered).to have_selector('.js-projects-indexing-restrictions')
      end

      context 'when there are too many elasticsearch indexed projects' do
        before do
          allow(view).to receive(:elasticsearch_too_many_projects?).and_return(true)
        end

        it 'hides the input' do
          render
          expect(rendered).not_to have_selector('.js-projects-indexing-restrictions')
        end
      end
    end
  end

  describe 'elasticsearch migrations' do
    let(:application_setting) { build(:application_setting) }

    it 'does not show the retry migration card' do
      render

      expect(rendered).not_to include('Advanced search migration halted')
      expect(rendered).not_to include('Retry migration')
    end

    context 'when Advanced search migration halted' do
      let(:elasticsearch_available) { true }
      let(:halted_migrations) { true }
      let(:migration) { Elastic::DataMigrationService.migrations.last }

      before do
        allow(Elastic::DataMigrationService).to receive(:halted_migration).and_return(migration)
      end

      context 'when there is no reindexing' do
        before do
          allow(task).to receive(:in_progress?).and_return(false)
        end

        it 'shows the retry migration card' do
          render

          expect(rendered).to include('Advanced search migration halted')
          expect(rendered).to have_css('a', text: 'Retry migration')
          expect(rendered).not_to have_css('a[disabled="disabled"]', text: 'Retry migration')
        end
      end

      context 'when there is a reindexing task in progress' do
        before do
          assign(:last_elasticsearch_reindexing_task, build(:elastic_reindexing_task))
        end

        it 'shows the retry migration card with retry button disabled' do
          render

          expect(rendered).to include('Advanced search migration halted')
          expect(rendered).to have_css('a[disabled="disabled"]', text: 'Retry migration')
        end
      end
    end

    context 'when elasticsearch is unreachable' do
      let(:elasticsearch_available) { false }

      it 'does not show the retry migration card' do
        render

        expect(rendered).not_to include('Advanced search migration halted')
        expect(rendered).not_to include('Retry migration')
      end
    end
  end

  describe 'indexing status' do
    let(:projects_not_indexed_max_shown) { 50 }
    let(:application_setting) { build(:application_setting) }

    before do
      assign(:initial_queue_size, initial_queue_size)
      assign(:incremental_queue_size, incremental_queue_size)
    end

    context 'when there are projects being indexed' do
      let(:initial_queue_size) { 10 }
      let(:incremental_queue_size) { 10 }

      context 'when there are projects in initial queue' do
        let(:initial_queue_size) { 20 }
        let(:incremental_queue_size) { 0 }

        it 'shows count of items in this queue' do
          render

          expect(rendered).to have_selector('[data-testid="initial_queue_size"]', text: '20')
        end
      end

      context 'when there are projects in incremental queue' do
        let(:initial_queue_size) { 0 }
        let(:incremental_queue_size) { 30 }

        it 'shows count of items in this queue' do
          render

          expect(rendered).to have_selector('[data-testid="incremental_queue_size"]', text: '30')
        end
      end
    end

    context 'when there are items in dead queue' do
      let(:initial_queue_size) { 0 }
      let(:incremental_queue_size) { 0 }

      before do
        assign(:dead_queue_size, 15)
      end

      it 'shows count of items in dead queue' do
        render

        expect(rendered).to have_selector('[data-testid="dead_queue_size"]', text: '15')
      end
    end

    context 'when there are projects not indexed' do
      context 'when there is 20 projects not indexed' do
        let(:namespace) { instance_double(Namespace, human_name: "Namespace 1") }
        let(:projects_not_indexed) { build_stubbed_list(:project, 20, :repository) }
        let(:projects_not_indexed_count) { 20 }
        let(:initial_queue_size) { 10 }
        let(:incremental_queue_size) { 10 }

        before do
          assign(:projects_not_indexed, projects_not_indexed)
          assign(:initial_queue_size, initial_queue_size)
          assign(:incremental_queue_size, incremental_queue_size)
          assign(:projects_not_indexed_count, projects_not_indexed_count)

          render
        end

        it 'shows count of 20 projects not indexed' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_size"]', text: '20')
        end

        it 'doesn’t show text “Only first 50 of not indexed projects is shown"' do
          expect(rendered).not_to include('Only first 50 of not indexed projects is shown')
        end

        it 'shows 20 items in the list .project-row' do
          expect(rendered).to have_selector('[data-testid="not_indexed_project_row"]', count: 20)
        end

        context 'when on gitlab.com don\'t show 20 not indexed projects', :saas do
          it 'does not shows the list' do
            expect(rendered).not_to have_selector('.indexing-projects-list')
          end

          it 'does not show the count of projects not indexed' do
            expect(rendered).not_to have_selector('[data-testid="projects_not_indexed_size"]')
          end
        end
      end

      context 'when there is 100 projects not indexed' do
        let(:namespace) { instance_double(Namespace, human_name: "Namespace 1") }
        let(:projects_not_indexed) { build_stubbed_list(:project, 100, :repository) }
        let(:projects_not_indexed_count) { 100 }
        let(:initial_queue_size) { 10 }
        let(:incremental_queue_size) { 10 }

        before do
          assign(:projects_not_indexed, projects_not_indexed)
          assign(:initial_queue_size, initial_queue_size)
          assign(:incremental_queue_size, incremental_queue_size)
          assign(:projects_not_indexed_count, projects_not_indexed_count)

          render
        end

        it 'shows count of 100 projects not indexed' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_size"]', text: '100')
        end

        it 'shows text “Only first 50 of not indexed projects is shown"' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_max_shown"]',
            text: 'Only first 50 of not indexed projects is shown')
        end

        it 'shows 100 items in the list .project-row' do
          # Under real conditions this will never have 100 items
          # since we are limiting ElasticProjectsNotIndexedFinder items
          # but for this test we are mocking the @projects_not_indexed
          # directly so limit is not applied
          expect(rendered).to have_selector('[data-testid="not_indexed_project_row"]', count: 100)
        end

        context 'when on gitlab.com don\'t show any not indexed projects', :saas do
          it 'does not shows the list' do
            expect(rendered).not_to have_selector('.indexing-projects-list')
          end

          it 'does not show the count of projects not indexed' do
            expect(rendered).not_to have_selector('[data-testid="projects_not_indexed_size"]')
          end
        end
      end

      context 'when there is 0 projects not indexed' do
        let(:incremental_queue_size) { 10 }
        let(:initial_queue_size) { 10 }
        let(:namespace) { instance_double(Namespace, human_name: "Namespace 1") }
        let(:projects_not_indexed_count) { 0 }
        let(:projects_not_indexed) { [] }

        before do
          assign(:projects_not_indexed, projects_not_indexed)
          assign(:initial_queue_size, initial_queue_size)
          assign(:incremental_queue_size, incremental_queue_size)
          assign(:projects_not_indexed_count, projects_not_indexed_count)

          render
        end

        it 'shows count of 0 projects not indexed' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_size"]', text: '0')
        end

        it 'does not show the list' do
          expect(rendered).not_to have_selector('.indexing-projects-list')
        end
      end
    end
  end
end
