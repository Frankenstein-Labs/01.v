# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks::DuplicateDefaultTrackedContextsCheck, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  subject(:check) { described_class.new(project) }

  describe '#fix!' do
    context 'with locking' do
      let_it_be(:context1) do
        create(:security_project_tracked_context, :tracked, project: project, is_default: true, context_name: 'main')
      end

      let_it_be(:context2) do
        create(:security_project_tracked_context, :tracked, project: project, is_default: true, context_name: 'master')
      end

      before do
        allow(project).to receive(:default_branch).and_return('main')
      end

      it 'obtains an exclusive lease for the project' do
        expect(check).to receive(:in_lock)
          .with(
            "vulnerabilities:consistency_checks:duplicate_default_tracked_contexts:#{project.id}",
            ttl: 30.minutes,
            retries: 0
          )
          .and_call_original

        check.fix!
      end

      it 'skips when another process holds the lock' do
        allow(check).to receive(:in_lock)
          .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

        expect { check.fix! }.not_to change { Security::ProjectTrackedContext.count }
        expect(check).to have_received(:in_lock)
      end

      it 'logs a message when skipping due to lock contention' do
        allow(check).to receive(:in_lock)
          .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

        expect(check).to receive(:log).with('Skipping - another process is handling this project')

        check.fix!
      end
    end

    context 'when there are no duplicate default contexts' do
      let_it_be(:tracked_context) { create(:security_project_tracked_context, :default, project: project) }

      it 'does nothing' do
        expect { check.fix! }.not_to change { Security::ProjectTrackedContext.count }
      end
    end

    context 'when there are duplicate default contexts' do
      let_it_be(:context1) do
        create(:security_project_tracked_context, :tracked, project: project, is_default: true, context_name: 'main')
      end

      let_it_be(:context2) do
        create(:security_project_tracked_context, :tracked, project: project, is_default: true, context_name: 'master')
      end

      before do
        allow(project).to receive(:default_branch).and_return('main')
      end

      it 'collapses duplicates into one' do
        expect { check.fix! }.to change {
          Security::ProjectTrackedContext.where(project: project, is_default: true).count
        }.from(2).to(1)
      end

      it 'keeps the context matching the default branch' do
        check.fix!

        expect(Security::ProjectTrackedContext.find_by(id: context1.id)).to be_present
        expect(Security::ProjectTrackedContext.find_by(id: context2.id)).to be_nil
      end

      context 'with references in related tables' do
        let_it_be(:occurrence) do
          create(:vulnerabilities_finding, project: project, security_project_tracked_context_id: context2.id)
        end

        let_it_be(:vulnerability_read) do
          create(:vulnerability_read, project: project, security_project_tracked_context_id: context2.id)
        end

        let_it_be(:vulnerability_statistic) do
          create(:vulnerability_statistic, project: project, security_project_tracked_context_id: context2.id)
        end

        let_it_be(:vulnerability_historical_statistic) do
          create(:vulnerability_historical_statistic, project: project,
            security_project_tracked_context_id: context2.id)
        end

        let_it_be(:sbom_occurrence_ref) do
          create(:sbom_occurrence_ref, project: project, tracked_context: context2)
        end

        it 'updates references to the surviving context' do
          check.fix!

          expect(occurrence.reload.security_project_tracked_context_id).to eq(context1.id)
          expect(vulnerability_read.reload.security_project_tracked_context_id).to eq(context1.id)
          expect(vulnerability_statistic.reload.security_project_tracked_context_id).to eq(context1.id)
          expect(vulnerability_historical_statistic.reload.security_project_tracked_context_id).to eq(context1.id)
        end

        it 'deletes sbom occurrence refs linked to duplicate contexts' do
          expect { check.fix! }.to change { Sbom::OccurrenceRef.where(id: sbom_occurrence_ref.id).count }.from(1).to(0)
        end

        it 'syncs vulnerability reads to Elasticsearch' do
          expect(Vulnerabilities::EsHelper)
            .to receive(:sync_elasticsearch)
            .with([vulnerability_read.vulnerability_id])

          check.fix!
        end
      end
    end

    context 'when no context matches the default branch' do
      let_it_be(:context1) do
        create(:security_project_tracked_context, :tracked, project: project,
          is_default: true, context_name: 'feature-a')
      end

      let_it_be(:context2) do
        create(:security_project_tracked_context, :tracked, project: project,
          is_default: true, context_name: 'feature-b')
      end

      before do
        allow(project).to receive(:default_branch).and_return('main')
      end

      it 'updates the oldest context to match the default branch' do
        check.fix!

        survivor = Security::ProjectTrackedContext.find(context1.id)
        expect(survivor.context_name).to eq('main')
      end
    end

    context 'when the oldest context already matches the default branch' do
      let_it_be(:context1) do
        create(:security_project_tracked_context, :tracked, project: project,
          is_default: true, context_name: 'main')
      end

      let_it_be(:context2) do
        create(:security_project_tracked_context, :tracked, project: project,
          is_default: true, context_name: 'feature')
      end

      before do
        allow(project).to receive(:default_branch).and_return('main')
      end

      it 'keeps the oldest context without updating its name' do
        expect(context1.id).to be < context2.id

        check.fix!

        survivor = Security::ProjectTrackedContext.find(context1.id)
        expect(survivor.context_name).to eq('main')
        expect(Security::ProjectTrackedContext.find_by(id: context2.id)).to be_nil
      end
    end
  end
end
