# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Pages::DeploymentUploader, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:pages_deployment) { create(:pages_deployment, project: project) }
  let(:uploader) { described_class.new(pages_deployment, :file) }

  describe '#trim_filename_if_needed' do
    context 'when on Geo primary node' do
      before do
        stub_primary_site
      end

      where(:input_filename, :expected_output, :description) do
        [
          ['short_filename.zip', 'short_filename.zip', 'under 60 characters'],
          ["#{'a' * 70}.zip", "#{'a' * 70}.zip"[-60..], 'over 60 characters'],
          ["#{'a' * 56}.zip", "#{'a' * 56}.zip", 'exactly 60 characters'],
          ['very_long_file_name_with_underscores_and_numbers_123456789_and_more_text.tar.gz',
            'very_long_file_name_with_underscores_and_numbers_123456789_and_more_text.tar.gz'[-60..],
            'complex with multi-part extension']
        ]
      end

      with_them do
        it "correctly trims filename when #{params[:description]}" do
          result = uploader.send(:trim_filename_if_needed, input_filename)

          expect(result).to eq(expected_output)

          if input_filename.length > 60
            expect(result.length).to eq(60)
          else
            expect(result).to eq(input_filename)
          end
        end
      end

      it "handles nil input by returning nil" do
        expect(uploader.send(:trim_filename_if_needed, nil)).to be_nil
      end

      it "handles empty string by returning empty string" do
        expect(uploader.send(:trim_filename_if_needed, "")).to eq("")
      end
    end

    context 'when on Geo secondary node' do
      before do
        stub_secondary_site
      end

      it "does not trim filename on secondary node" do
        long_filename = "#{'deployment' * 10}.tar.gz"
        result = uploader.send(:trim_filename_if_needed, long_filename)

        expect(result).to eq(long_filename)
        expect(result.length).to be > 60
      end

      it "preserves original filename regardless of length" do
        filenames = [
          'short.zip',
          "#{'a' * 70}.zip",
          'very_long_file_name_with_underscores_and_numbers_123456789_and_more_text.tar.gz'
        ]

        filenames.each do |filename|
          result = uploader.send(:trim_filename_if_needed, filename)
          expect(result).to eq(filename)
        end
      end

      it "handles nil input by returning nil even on secondary" do
        expect(uploader.send(:trim_filename_if_needed, nil)).to be_nil
      end

      it "handles empty string by returning empty string even on secondary" do
        expect(uploader.send(:trim_filename_if_needed, "")).to eq("")
      end
    end

    context 'when on org migration target node' do
      let_it_be(:org_migration_target_node, freeze: true) { create(:geo_node, selective_sync_type: 'organizations') }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
        org_migration_target_node.organizations << project.organization
      end

      it "does not trim filename on org migration target node" do
        long_filename = "#{'deployment' * 10}.tar.gz"
        result = uploader.send(:trim_filename_if_needed, long_filename)

        expect(result).to eq(long_filename)
        expect(result.length).to be > 60
      end
    end

    context 'when Geo is not enabled' do
      before do
        stub_geo_setting(enabled: false)
      end

      it "applies trimming logic when Geo is disabled" do
        long_filename = "#{'deployment' * 10}.tar.gz"
        result = uploader.send(:trim_filename_if_needed, long_filename)

        expect(result.length).to eq(60)
        expect(result).to eq(long_filename[-60..])
      end
    end

    context 'when model project is nil' do
      let(:pages_deployment_without_project) { build(:pages_deployment, project: nil) }
      let(:uploader_without_project) { described_class.new(pages_deployment_without_project, :file) }

      it "applies trimming logic when project is nil" do
        long_filename = "#{'deployment' * 10}.tar.gz"
        result = uploader_without_project.send(:trim_filename_if_needed, long_filename)

        expect(result.length).to eq(60)
        expect(result).to eq(long_filename[-60..])
      end
    end
  end
end
