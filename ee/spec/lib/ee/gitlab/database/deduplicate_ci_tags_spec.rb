# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::DeduplicateCiTags, :aggregate_failures, feature_category: :runner_core do
  let_it_be(:sec_connection, freeze: false) { ::SecApplicationRecord.connection }
  let_it_be(:ci_connection, freeze: false) { ::Ci::ApplicationRecord.connection }
  let_it_be(:project_id) { 1 }
  let_it_be(:dast_site_id) do
    sec_connection.select_value(<<~SQL)
      INSERT INTO dast_sites (created_at, updated_at, project_id, url)
        VALUES (NOW(), NOW(), #{project_id}, 'url') RETURNING id
    SQL
  end

  let_it_be(:dast_site_profile_id) do
    sec_connection.select_value(<<~SQL)
      INSERT INTO dast_site_profiles (created_at, updated_at, project_id, dast_site_id, name)
        VALUES (NOW(), NOW(), #{project_id}, #{dast_site_id}, 'dast site profile') RETURNING id
    SQL
  end

  let_it_be(:dast_scanner_profile_id) do
    sec_connection.select_value(<<~SQL)
      INSERT INTO dast_scanner_profiles (created_at, updated_at, project_id, name)
        VALUES (NOW(), NOW(), #{project_id}, 'dast scanner profile') RETURNING id
    SQL
  end

  let(:dast_profile1_id) { create_dast_profile_id('dast profile') }
  let(:dast_profile2_id) { create_dast_profile_id('other dast profile') }
  let(:tag_ids) { ci_connection.select_values("INSERT INTO tags (name) VALUES ('tag1'), ('tag2') RETURNING id") }
  let!(:tagging_ids) do
    sec_connection.select_values(<<~SQL)
      INSERT INTO dast_profiles_tags (dast_profile_id, tag_id, project_id, tag_name)
      VALUES (#{dast_profile1_id}, #{tag_ids.first}, #{project_id}, 'tag_name'),
             (#{dast_profile1_id}, #{tag_ids.second}, #{project_id}, 'tag_name'),
             (#{dast_profile2_id}, #{tag_ids.first}, #{project_id}, 'tag_name')
      RETURNING id;
    SQL
  end

  let(:logger) { instance_double(Logger) }
  let(:dry_run) { false }
  let(:service) { described_class.new(logger: logger, dry_run: dry_run) }

  describe '#execute' do
    subject(:execute) { service.execute }

    before do
      allow(logger).to receive(:info)
    end

    it 'does not change number of tags' do
      expect { execute }.to not_change { table_count('tags') }

      expect(logger).to have_received(:info).with('No duplicate tags found in ci database')
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(deduplicate_ci_tags: true)
        allow(logger).to receive(:error)
      end

      it 'refuses to run' do
        expect { execute }.to not_change { table_count('tags') }

        expect(logger).to have_received(:error).with('This rake task is not optimized for .com')
      end
    end

    context 'when duplicate tags exist' do
      let(:duplicate_tag_ids) do
        ci_connection.select_values("INSERT INTO tags (name) VALUES ('tag1'), ('tag2') RETURNING id")
      end

      let(:duplicate_dast_profile_tagging_ids) do
        sec_connection.select_values(<<~SQL)
          INSERT INTO dast_profiles_tags (dast_profile_id, tag_id, project_id, tag_name)
            VALUES (#{dast_profile1_id}, #{duplicate_tag_ids.second}, #{project_id}, 'tag_name'),
                   (#{dast_profile2_id}, #{duplicate_tag_ids.first}, #{project_id}, 'tag_name')
            RETURNING id
        SQL
      end

      around do |example|
        ci_connection.transaction do
          tagging_ids

          # allow a scenario where multiple tags with same name coexist
          ci_connection.execute('DROP INDEX index_tags_on_name')

          duplicate_dast_profile_tagging_ids

          example.run
        end
      end

      it 'deletes duplicate tag and updates dast_profiles_tags' do
        expect { execute }
          .to change { table_count('tags') }.by(-2)
          .and not_change { tagging_relationship_for(tagging_ids.second) }
          .and change { tagging_relationship_for(duplicate_dast_profile_tagging_ids.first) }
            .from(dast_profile1_id => duplicate_tag_ids.second)
            .to(dast_profile1_id => tag_ids.second)
          .and change { tagging_relationship_for(duplicate_dast_profile_tagging_ids.second) }
            .from(dast_profile2_id => duplicate_tag_ids.first)
            .to(dast_profile2_id => tag_ids.first)

        expect(logger).to have_received(:info).with('Deduplicating 2 tags for ci database')
        expect(logger).to have_received(:info).with('Done')
      end

      context 'and dry_run is true' do
        let(:dry_run) { true }

        it 'does not change number of tags or dast_profiles_tags tag_ids' do
          expect { execute }.to not_change { table_count('tags') }
            .and not_change { tagging_relationship_for(tagging_ids.second) }
            .and not_change { tagging_relationship_for(duplicate_dast_profile_tagging_ids.first) }
            .and not_change { tagging_relationship_for(duplicate_dast_profile_tagging_ids.second) }

          expect(logger).to have_received(:info).with('DRY RUN:')
          expect(logger).to have_received(:info).with('Deduplicating 2 tags for ci database')
          expect(logger).to have_received(:info).with('Done')
        end
      end
    end
  end

  private

  def table_count(table_name)
    ci_connection.select_value("SELECT COUNT(*) FROM #{table_name}")
  end

  def create_dast_profile_id(name)
    sec_connection.select_value(<<~SQL)
      INSERT INTO dast_profiles (
          created_at, updated_at, project_id, dast_site_profile_id, dast_scanner_profile_id, name, description)
        VALUES (NOW(), NOW(), #{project_id}, #{dast_site_profile_id}, #{dast_scanner_profile_id}, '#{name}', '')
        RETURNING id
    SQL
  end

  def tagging_relationship_for(tagging_id)
    sec_connection.execute(<<~SQL).values.to_h
      SELECT dast_profile_id, tag_id FROM dast_profiles_tags WHERE id = #{tagging_id}
    SQL
  end
end
