# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSubscriptionUserAddOnAssignmentVersions,
  feature_category: :value_stream_management do
  let(:add_ons_details) do
    {
      duo_enterprise: { name: 3, description: 'Add-on for GitLab Duo Enterprise.' },
      duo_core: { name: 5, description: 'Add-on for GitLab Duo Core.' }
    }
  end.freeze

  let!(:organizations) { table(:organizations) }
  let!(:users) { table(:users) }
  let!(:namespaces) { table(:namespaces) }
  let!(:add_ons) { table(:subscription_add_ons) }
  let!(:add_on_purchases) { table(:subscription_add_on_purchases) }
  let!(:user_add_on_assignments) { table(:subscription_user_add_on_assignments) }
  let!(:user_add_on_assignment_versions) { table(:subscription_user_add_on_assignment_versions) }

  let!(:user) do
    users.create!(name: 'Test User', email: 'test@example.com', projects_limit: 5, organization_id: organization.id)
  end
  let!(:another_user) do
    users.create!(name: 'Another User', email: 'another@example.com', projects_limit: 5,
      organization_id: organization.id)
  end

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }

  let!(:namespace) do
    namespaces.create!(
      name: 'test-namespace',
      path: 'test-namespace',
      type: 'Group',
      organization_id: organization.id
    ).tap { |ns| ns.update!(traversal_ids: [ns.id]) }
  end

  let!(:add_on) do
    add_ons.create!(
      name: add_ons_details[:duo_core][:name],
      description: 'GitLab Duo Add-on'
    )
  end

  let!(:add_on_purchase) do
    add_on_purchases.create!(
      subscription_add_on_id: add_on.id,
      namespace_id: namespace.id,
      organization_id: organization.id,
      quantity: 10,
      started_at: 1.month.ago,
      expires_on: 1.year.from_now,
      purchase_xid: 'test-purchase-xid'
    )
  end

  let(:migration_args) do
    {
      start_id: user_add_on_assignments.minimum(:id),
      end_id: user_add_on_assignments.maximum(:id),
      batch_table: :subscription_user_add_on_assignments,
      batch_column: :id,
      sub_batch_size: 2,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  subject(:migration) { described_class.new(**migration_args) }

  describe '#perform' do
    context 'when there are assignments without versions' do
      let!(:assignment_without_version) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      let!(:assignment_without_version_2) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: another_user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      it 'creates version records for assignments without versions' do
        expect { migration.perform }
          .to change { user_add_on_assignment_versions.count }.by(2)

        version_1 = user_add_on_assignment_versions.find_by(item_id: assignment_without_version.id)
        version_2 = user_add_on_assignment_versions.find_by(item_id: assignment_without_version_2.id)

        expect(version_1).to have_attributes(
          organization_id: organization.id,
          item_id: assignment_without_version.id,
          purchase_id: add_on_purchase.id,
          user_id: user.id,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'create',
          namespace_path: "#{namespace.id}/",
          add_on_name: add_on.name.to_s,
          whodunnit: 'backfill_migration'
        )

        expect(version_2).to have_attributes(
          organization_id: organization.id,
          item_id: assignment_without_version_2.id,
          purchase_id: add_on_purchase.id,
          user_id: another_user.id,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'create',
          namespace_path: "#{namespace.id}/",
          add_on_name: add_on.name.to_s,
          whodunnit: 'backfill_migration'
        )
      end

      context 'when namespace has traversal path' do
        let!(:namespace_with_path) do
          namespaces.create!(
            name: 'parent-group',
            path: 'parent-group',
            type: 'Group',
            organization_id: organization.id
          ).tap { |ns| ns.update!(traversal_ids: [ns.id]) }
        end

        let!(:sub_namespace) do
          namespaces.create!(
            name: 'sub-group',
            path: 'sub-group',
            type: 'Group',
            parent_id: namespace_with_path.id,
            organization_id: organization.id
          ).tap { |ns| ns.update!(traversal_ids: [namespace_with_path.id, ns.id]) }
        end

        let!(:add_on_purchase_with_path) do
          add_on_purchases.create!(
            subscription_add_on_id: add_on.id,
            namespace_id: sub_namespace.id,
            organization_id: organization.id,
            quantity: 5,
            started_at: 1.month.ago,
            expires_on: 1.year.from_now,
            purchase_xid: 'test-purchase-xid-2'
          )
        end

        let!(:assignment_with_path) do
          user_add_on_assignments.create!(
            add_on_purchase_id: add_on_purchase_with_path.id,
            user_id: user.id,
            organization_id: organization.id,
            created_at: 1.week.ago,
            updated_at: 1.week.ago
          )
        end

        it 'creates version with correct namespace path' do
          expect { migration.perform }
            .to change { user_add_on_assignment_versions.count }.by(3)

          version = user_add_on_assignment_versions.find_by(item_id: assignment_with_path.id)

          expect(version).to have_attributes(
            namespace_path: "#{namespace_with_path.id}/#{sub_namespace.id}/",
            organization_id: organization.id
          )
        end
      end
    end

    context 'when assignment already has a version' do
      let!(:assignment_with_version) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      let!(:existing_version) do
        user_add_on_assignment_versions.create!(
          organization_id: organization.id,
          item_id: assignment_with_version.id,
          purchase_id: add_on_purchase.id,
          user_id: user.id,
          created_at: 1.week.ago,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'create',
          namespace_path: "#{organization.id}/",
          add_on_name: add_on.name,
          whodunnit: 'test',
          object: { id: assignment_with_version.id }.to_json
        )
      end

      it 'does not create duplicate version records' do
        expect { migration.perform }
          .not_to change { user_add_on_assignment_versions.count }
      end
    end

    context 'when assignment has destroy event but no create event' do
      let!(:assignment_with_destroy_only) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 2.weeks.ago,
          updated_at: 2.weeks.ago
        )
      end

      let!(:destroy_version) do
        user_add_on_assignment_versions.create!(
          organization_id: organization.id,
          item_id: assignment_with_destroy_only.id,
          purchase_id: add_on_purchase.id,
          user_id: user.id,
          created_at: 1.week.ago,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'destroy',
          namespace_path: "#{namespace.id}/",
          add_on_name: add_on.name,
          whodunnit: 'test',
          object: { id: assignment_with_destroy_only.id }.to_json
        )
      end

      it 'creates a create version for the assignment' do
        expect { migration.perform }
          .to change { user_add_on_assignment_versions.count }.by(1)

        create_version = user_add_on_assignment_versions
          .where(item_id: assignment_with_destroy_only.id, event: 'create')
          .first

        expect(create_version).to have_attributes(
          organization_id: organization.id,
          item_id: assignment_with_destroy_only.id,
          purchase_id: add_on_purchase.id,
          user_id: user.id,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'create',
          namespace_path: "#{namespace.id}/",
          add_on_name: add_on.name.to_s,
          whodunnit: 'backfill_migration'
        )

        destroy_version.reload
        expect(destroy_version.whodunnit).to eq('test')
      end

      context 'with multiple assignments having destroy but no create' do
        let!(:another_assignment_with_destroy_only) do
          user_add_on_assignments.create!(
            add_on_purchase_id: add_on_purchase.id,
            user_id: another_user.id,
            organization_id: organization.id,
            created_at: 2.weeks.ago,
            updated_at: 2.weeks.ago
          )
        end

        let!(:another_destroy_version) do
          user_add_on_assignment_versions.create!(
            organization_id: organization.id,
            item_id: another_assignment_with_destroy_only.id,
            purchase_id: add_on_purchase.id,
            user_id: another_user.id,
            created_at: 1.week.ago,
            item_type: 'GitlabSubscriptions::UserAddOnAssignment',
            event: 'destroy',
            namespace_path: "#{namespace.id}/",
            add_on_name: add_on.name,
            whodunnit: 'test',
            object: { id: another_assignment_with_destroy_only.id }.to_json
          )
        end

        it 'creates create versions for all assignments with destroy but no create' do
          expect { migration.perform }
            .to change { user_add_on_assignment_versions.count }.by(2)

          [assignment_with_destroy_only, another_assignment_with_destroy_only].each do |assignment|
            create_version = user_add_on_assignment_versions
              .where(item_id: assignment.id, event: 'create')
              .first

            expect(create_version).to be_present
            expect(create_version.event).to eq('create')
            expect(create_version.whodunnit).to eq('backfill_migration')
          end
        end
      end
    end

    context 'when assignment has both create and destroy events' do
      let!(:assignment_with_both_events) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 2.weeks.ago,
          updated_at: 2.weeks.ago
        )
      end

      let!(:create_version) do
        user_add_on_assignment_versions.create!(
          organization_id: organization.id,
          item_id: assignment_with_both_events.id,
          purchase_id: add_on_purchase.id,
          user_id: user.id,
          created_at: 2.weeks.ago,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'create',
          namespace_path: "#{namespace.id}/",
          add_on_name: add_on.name,
          whodunnit: 'test',
          object: { id: assignment_with_both_events.id }.to_json
        )
      end

      let!(:destroy_version) do
        user_add_on_assignment_versions.create!(
          organization_id: organization.id,
          item_id: assignment_with_both_events.id,
          purchase_id: add_on_purchase.id,
          user_id: user.id,
          created_at: 1.week.ago,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'destroy',
          namespace_path: "#{namespace.id}/",
          add_on_name: add_on.name,
          whodunnit: 'test',
          object: { id: assignment_with_both_events.id }.to_json
        )
      end

      it 'does not create additional version records' do
        expect { migration.perform }
          .not_to change { user_add_on_assignment_versions.count }
      end
    end

    context 'when there are no assignments to backfill' do
      it 'does not create any version records' do
        expect { migration.perform }
          .not_to change { user_add_on_assignment_versions.count }
      end
    end

    context 'when batch processing multiple assignments' do
      let!(:assignments) do
        (1..5).map do |i|
          user_add_on_assignments.create!(
            add_on_purchase_id: add_on_purchase.id,
            user_id: users.create!(name: 'Test User', email: "test#{i}@example.com", projects_limit: 5,
              organization_id: organization.id).id,
            organization_id: organization.id,
            created_at: i.days.ago,
            updated_at: i.days.ago
          )
        end
      end

      it 'processes all assignments in the batch' do
        expect { migration.perform }
          .to change { user_add_on_assignment_versions.count }.by(5)

        assignments.each do |assignment|
          version = user_add_on_assignment_versions.find_by(item_id: assignment.id)
          expect(version).to be_present
          expect(version.organization_id).to eq(organization.id)
          expect(version.item_id).to eq(assignment.id)
          expect(version.purchase_id).to eq(add_on_purchase.id)
        end
      end
    end

    context 'when sub_batch_size is smaller than total assignments' do
      let(:migration_args) do
        {
          start_id: user_add_on_assignments.minimum(:id),
          end_id: user_add_on_assignments.maximum(:id),
          batch_table: :subscription_user_add_on_assignments,
          batch_column: :id,
          sub_batch_size: 1,
          pause_ms: 0,
          connection: ApplicationRecord.connection
        }
      end

      let!(:assignment_1) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      let!(:assignment_2) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: another_user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      it 'processes assignments in smaller batches' do
        expect { migration.perform }
          .to change { user_add_on_assignment_versions.count }.by(2)

        [assignment_1, assignment_2].each do |assignment|
          version = user_add_on_assignment_versions.find_by(item_id: assignment.id)
          expect(version).to be_present
        end
      end
    end

    context 'when assignments have different add-on purchases' do
      let!(:another_add_on) do
        add_ons.create!(
          name: add_ons_details[:duo_enterprise][:name],
          description: 'Another Add-on Description'
        )
      end

      let!(:another_add_on_purchase) do
        add_on_purchases.create!(
          subscription_add_on_id: another_add_on.id,
          namespace_id: namespace.id,
          organization_id: organization.id,
          quantity: 5,
          started_at: 1.month.ago,
          expires_on: 1.year.from_now,
          purchase_xid: 'another-purchase-xid'
        )
      end

      let!(:assignment_1) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      let!(:assignment_2) do
        user_add_on_assignments.create!(
          add_on_purchase_id: another_add_on_purchase.id,
          user_id: another_user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      it 'creates versions with correct add-on information' do
        expect { migration.perform }
          .to change { user_add_on_assignment_versions.count }.by(2)

        version_1 = user_add_on_assignment_versions.find_by(item_id: assignment_1.id)
        version_2 = user_add_on_assignment_versions.find_by(item_id: assignment_2.id)

        expect(version_1.add_on_name).to eq(add_on.name.to_s)
        expect(version_1.purchase_id).to eq(add_on_purchase.id)

        expect(version_2.add_on_name).to eq(another_add_on.name.to_s)
        expect(version_2.purchase_id).to eq(another_add_on_purchase.id)
      end
    end

    context 'when there are mixed assignments with and without versions' do
      let!(:assignment_without_version) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      let!(:assignment_with_version) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: another_user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      let!(:existing_version) do
        user_add_on_assignment_versions.create!(
          organization_id: organization.id,
          item_id: assignment_with_version.id,
          purchase_id: add_on_purchase.id,
          user_id: another_user.id,
          created_at: 1.week.ago,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'create',
          namespace_path: "#{organization.id}/",
          add_on_name: add_on.name,
          whodunnit: 'test',
          object: { id: assignment_with_version.id }.to_json
        )
      end

      let!(:assignment_with_destroy_only) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase.id,
          user_id: users.create!(name: 'Test User 3', email: 'test3@example.com', projects_limit: 5,
            organization_id: organization.id).id,
          organization_id: organization.id,
          created_at: 2.weeks.ago,
          updated_at: 2.weeks.ago
        )
      end

      let!(:destroy_only_version) do
        user_add_on_assignment_versions.create!(
          organization_id: organization.id,
          item_id: assignment_with_destroy_only.id,
          purchase_id: add_on_purchase.id,
          user_id: assignment_with_destroy_only.user_id,
          created_at: 1.week.ago,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'destroy',
          namespace_path: "#{organization.id}/",
          add_on_name: add_on.name,
          whodunnit: 'test',
          object: { id: assignment_with_destroy_only.id }.to_json
        )
      end

      it 'only creates versions for assignments without existing versions and assignments with destroy but no create' do
        expect { migration.perform }
          .to change { user_add_on_assignment_versions.count }.by(2)

        new_version = user_add_on_assignment_versions.find_by(item_id: assignment_without_version.id)
        expect(new_version).to be_present
        expect(new_version.user_id).to eq(user.id)
        expect(new_version.event).to eq('create')

        create_version_for_destroy_only = user_add_on_assignment_versions
          .where(item_id: assignment_with_destroy_only.id, event: 'create')
          .first
        expect(create_version_for_destroy_only).to be_present
        expect(create_version_for_destroy_only.user_id).to eq(assignment_with_destroy_only.user_id)

        existing_version.reload
        expect(existing_version.whodunnit).to eq('test')
      end
    end

    context 'when add_on_purchase has no namespace_id' do
      let!(:add_on_purchase_without_namespace) do
        add_on_purchases.create!(
          subscription_add_on_id: add_on.id,
          namespace_id: nil,
          organization_id: organization.id,
          quantity: 5,
          started_at: 1.month.ago,
          expires_on: 1.year.from_now,
          purchase_xid: 'test-purchase-no-namespace'
        )
      end

      let!(:assignment_without_namespace) do
        user_add_on_assignments.create!(
          add_on_purchase_id: add_on_purchase_without_namespace.id,
          user_id: user.id,
          organization_id: organization.id,
          created_at: 1.week.ago,
          updated_at: 1.week.ago
        )
      end

      it 'creates version with organization-only path when namespace_id is nil' do
        expect { migration.perform }
          .to change { user_add_on_assignment_versions.count }.by(1)

        version = user_add_on_assignment_versions.find_by(item_id: assignment_without_namespace.id)

        expect(version).to have_attributes(
          organization_id: organization.id,
          item_id: assignment_without_namespace.id,
          purchase_id: add_on_purchase_without_namespace.id,
          user_id: user.id,
          item_type: 'GitlabSubscriptions::UserAddOnAssignment',
          event: 'create',
          namespace_path: "#{organization.id}/",
          add_on_name: add_on.name.to_s,
          whodunnit: 'backfill_migration'
        )
      end
    end
  end
end
