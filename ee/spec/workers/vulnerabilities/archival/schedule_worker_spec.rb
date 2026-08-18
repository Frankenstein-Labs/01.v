# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::ScheduleWorker, feature_category: :vulnerability_management do
  describe '#perform', :aggregate_failures, :clean_gitlab_redis_shared_state do
    let(:worker) { described_class.new }

    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_2) { create(:group) }
    let_it_be(:group_3) { create(:group) }
    let_it_be(:group_4) { create(:group) }
    let_it_be_with_refind(:project_with_vulnerabilities_1) { create(:project, group: group_1) }
    let_it_be_with_refind(:project_with_vulnerabilities_2) { create(:project, group: group_2) }
    let_it_be_with_refind(:project_with_vulnerabilities_3) { create(:project, group: group_3) }
    let_it_be_with_refind(:project_without_vulnerabilities) { create(:project, group: group_4) }

    subject(:schedule) { worker.perform }

    around do |example|
      travel_to('2024-01-01') { example.run }
    end

    before do
      project_with_vulnerabilities_1.project_setting.update!(has_vulnerabilities: true)
      project_with_vulnerabilities_2.project_setting.update!(has_vulnerabilities: true)
      project_with_vulnerabilities_3.project_setting.update!(has_vulnerabilities: true)

      stub_feature_flags(vulnerability_archival: [group_2, group_3, group_4])

      stub_const("#{described_class}::BATCH_SIZE", 1)

      allow(Vulnerabilities::Archival::ArchiveWorker).to receive(:bulk_perform_in)
    end

    it 'schedules the archival only for the feature enabled projects with vulnerabilities' do
      schedule

      expect(Vulnerabilities::Archival::ArchiveWorker).to have_received(:bulk_perform_in).twice

      expect(Vulnerabilities::Archival::ArchiveWorker)
        .to have_received(:bulk_perform_in).with(30, [[project_with_vulnerabilities_2.id, '2023-01-01']])

      expect(Vulnerabilities::Archival::ArchiveWorker)
        .to have_received(:bulk_perform_in).with(60, [[project_with_vulnerabilities_3.id, '2023-01-01']])
    end

    describe 'progressive working' do
      let(:redis_key) { "CursorStore:#{described_class::REDIS_CURSOR_KEY}" }

      describe 'running from the previous checkpoint' do
        before do
          latest_iteration_information = { project_id: project_with_vulnerabilities_2.id, index: 2 }.to_json

          Gitlab::Redis::SharedState.with do |redis|
            redis.set(redis_key, latest_iteration_information)
          end
        end

        it 'schedules jobs for only the remaining projects' do
          schedule

          expect(Vulnerabilities::Archival::ArchiveWorker).to have_received(:bulk_perform_in).once

          expect(Vulnerabilities::Archival::ArchiveWorker)
            .to have_received(:bulk_perform_in).with(60, [[project_with_vulnerabilities_3.id, '2023-01-01']])
        end
      end

      describe 'storing the latest iteration information on redis' do
        def data_on_redis
          redis_data = Gitlab::Redis::SharedState.with { |redis| redis.get(redis_key) }

          Gitlab::Json.parse(redis_data)
        end

        context 'when there was a scheduling of a job' do
          it 'stores the information on redis' do
            schedule

            expect(Vulnerabilities::Archival::ArchiveWorker).to have_received(:bulk_perform_in).twice
            expect(data_on_redis).to match({ 'project_id' => project_with_vulnerabilities_3.id, 'index' => 3 })
          end
        end

        context 'when the feature was not enabled for any of the projects in the last batch' do
          let_it_be(:last_project_with_group) { create(:project, :in_group) }

          before do
            last_project_with_group.project_setting.update!(has_vulnerabilities: true)

            latest_iteration_information = { project_id: project_with_vulnerabilities_3.id, index: 3 }.to_json

            Gitlab::Redis::SharedState.with do |redis|
              redis.set(redis_key, latest_iteration_information)
            end
          end

          it 'stores the information on redis' do
            schedule

            expect(Vulnerabilities::Archival::ArchiveWorker).not_to have_received(:bulk_perform_in)
            expect(data_on_redis).to match({ 'project_id' => last_project_with_group.id, 'index' => 3 })
          end
        end
      end
    end
  end
end
