# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillMissingNamespaceIdOnNotes, feature_category: :code_review_workflow do
  before do
    skip 'EE features not available' unless Gitlab.ee?
  end

  # Core tables
  let(:namespaces) { table(:namespaces) }
  let(:notes) { table(:notes) }
  let(:projects) { table(:projects) }
  let(:users) { table(:users) }
  let(:organizations) { table(:organizations) }
  let(:work_item_types) { table(:work_item_types) }
  let(:issues) { table(:issues) }

  # Security tables
  let(:vulnerability_scanners) { table(:vulnerability_scanners, database: :sec) }
  let(:vulnerability_identifiers) { table(:vulnerability_identifiers, database: :sec) }
  let(:vulnerability_occurrences) { table(:vulnerability_occurrences, database: :sec) }
  let(:vulnerabilities) { table(:vulnerabilities, database: :sec) }

  # Seed data
  let(:organization) do
    organizations.find_or_create_by!(path: 'default') do |org|
      org.name = 'default'
    end
  end

  let(:user_1) do
    users.find_or_create_by!(email: 'bob@example.com') do |user|
      user.name = 'bob'
      user.projects_limit = 1
      user.organization_id = organization.id
    end
  end

  let(:namespace_1) do
    namespaces.create!(
      name: 'namespace',
      path: 'namespace-path-1',
      organization_id: organization.id
    )
  end

  let(:project_namespace_2) do
    namespaces.create!(
      name: 'namespace',
      path: 'namespace-path-2',
      type: 'Project',
      organization_id: organization.id
    )
  end

  let!(:project_1) do
    projects.create!(
      name: 'project1',
      path: 'path1',
      namespace_id: namespace_1.id,
      project_namespace_id: project_namespace_2.id,
      visibility_level: 0,
      organization_id: organization.id
    )
  end

  def create_work_item_type(name: "Type #{SecureRandom.hex}")
    work_item_types.create!(
      id: SecureRandom.random_number(1_000_000),
      name: name
    )
  end

  def create_issue(title:, namespace:, author: user_1)
    work_item_type = create_work_item_type
    issues.create!(
      title: title,
      author_id: author.id,
      namespace_id: namespace.id,
      work_item_type_id: work_item_type.id
    )
  end

  subject(:migration) do
    described_class.new(
      start_id: notes.minimum(:id),
      end_id: notes.maximum(:id),
      batch_table: :notes,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  describe '#perform' do
    after do
      if ApplicationRecord.connection.table_exists?(:notes_archived)
        ApplicationRecord.connection.execute('TRUNCATE TABLE notes_archived')
      end
    end

    context 'when processing Vulnerability notes' do
      let!(:vulnerability_scanner) do
        vulnerability_scanners.create!(
          project_id: project_1.id,
          external_id: "test-scanner-#{SecureRandom.hex(4)}",
          name: 'Test Scanner'
        )
      end

      let!(:vulnerability_identifier) do
        vulnerability_identifiers.create!(
          project_id: project_1.id,
          fingerprint: SecureRandom.hex(20),
          external_type: 'cve',
          external_id: 'CVE-2024-TEST',
          name: 'Test Identifier'
        )
      end

      let!(:vulnerability_occurrence) do
        vulnerability_occurrences.create!(
          uuid: SecureRandom.uuid,
          location_fingerprint: SecureRandom.hex(20),
          project_id: project_1.id,
          scanner_id: vulnerability_scanner.id,
          primary_identifier_id: vulnerability_identifier.id,
          report_type: 1,
          severity: 1,
          name: 'Test Finding',
          metadata_version: '1.0',
          details: '{}',
          detection_method: 0
        )
      end

      let!(:vulnerability) do
        vulnerabilities.create!(
          project_id: project_1.id,
          author_id: user_1.id,
          title: 'Test Vulnerability',
          severity: 1,
          report_type: 1,
          state: 1,
          finding_id: vulnerability_occurrence.id
        )
      end

      let!(:vulnerability_note) do
        notes.create!(
          project_id: nil,
          namespace_id: nil,
          organization_id: organization.id, # Added to satisfy constraint
          noteable_type: 'Vulnerability',
          noteable_id: vulnerability.id,
          author_id: user_1.id
        )
      end

      it "updates namespace_id from Vulnerability's project namespace" do
        expect(vulnerability_note.namespace_id).to be_nil

        migration.perform

        vulnerability_note.reload
        expect(vulnerability_note.namespace_id).to eq(project_namespace_2.id)
      end

      it 'handles cross-database queries efficiently' do
        recorder = ActiveRecord::QueryRecorder.new { migration.perform }

        vulnerability_note.reload
        expect(vulnerability_note.namespace_id).to eq(project_namespace_2.id)

        # Verify CTEs are used
        expect(recorder.log).to be_any { |q|
          q.include?('WITH') && q.include?('Vulnerability')
        }
      end

      context 'with multiple vulnerabilities' do
        let!(:vulnerability_2) do
          vulnerabilities.create!(
            project_id: project_1.id,
            author_id: user_1.id,
            title: 'Test Vulnerability 2',
            severity: 2,
            report_type: 1,
            state: 1,
            finding_id: vulnerability_occurrence.id
          )
        end

        let!(:vulnerability_note_2) do
          notes.create!(
            project_id: nil,
            namespace_id: nil,
            organization_id: organization.id, # Added to satisfy constraint
            noteable_type: 'Vulnerability',
            noteable_id: vulnerability_2.id,
            author_id: user_1.id
          )
        end

        it 'updates all vulnerability notes in a single query' do
          recorder = ActiveRecord::QueryRecorder.new { migration.perform }

          vulnerability_note.reload
          vulnerability_note_2.reload

          expect(vulnerability_note.namespace_id).to eq(project_namespace_2.id)
          expect(vulnerability_note_2.namespace_id).to eq(project_namespace_2.id)

          # Should batch updates efficiently
          vulnerability_updates = recorder.log.select do |q|
            q.include?('UPDATE notes') && q.include?('Vulnerability')
          end
          expect(vulnerability_updates.size).to eq(1)
        end
      end

      context 'with wrong namespace from previous migration' do
        let!(:wrong_namespace) do
          namespaces.create!(
            name: 'wrong-namespace',
            path: 'wrong-namespace-path',
            organization_id: organization.id
          )
        end

        let!(:vulnerability_note_with_wrong_namespace) do
          notes.create!(
            project_id: nil,
            namespace_id: wrong_namespace.id, # Wrong namespace
            organization_id: organization.id, # Added to satisfy constraint
            noteable_type: 'Vulnerability',
            noteable_id: vulnerability.id,
            author_id: user_1.id
          )
        end

        it 'corrects the namespace_id' do
          expect(vulnerability_note_with_wrong_namespace.namespace_id).to eq(wrong_namespace.id)

          migration.perform

          vulnerability_note_with_wrong_namespace.reload
          expect(vulnerability_note_with_wrong_namespace.namespace_id).to eq(project_namespace_2.id)
        end
      end
    end

    context 'when vulnerability references are invalid' do
      let!(:orphaned_vulnerability_note) do
        notes.create!(
          project_id: nil,
          namespace_id: nil,
          organization_id: organization.id, # Added to satisfy constraint
          noteable_type: 'Vulnerability',
          noteable_id: 999_999, # Non-existent vulnerability
          author_id: user_1.id
        )
      end

      it 'archives orphaned vulnerability notes' do
        expect(Gitlab::BackgroundMigration::Logger).to receive(:warn).with(
          hash_including(
            message: 'Orphaned note to be archived',
            noteable_type: 'Vulnerability'
          )
        )
        expect(Gitlab::BackgroundMigration::Logger).to receive(:info).with(
          hash_including(message: 'Archived and deleted orphaned notes')
        )

        migration.perform

        expect { orphaned_vulnerability_note.reload }.to raise_error(ActiveRecord::RecordNotFound)

        archived_notes = ApplicationRecord.connection.select_all(
          'SELECT id FROM notes_archived WHERE id = $1',
          'query',
          [orphaned_vulnerability_note.id]
        )
        expect(archived_notes.count).to eq(1)
      end
    end
  end
end
