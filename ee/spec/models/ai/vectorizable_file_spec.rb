# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::VectorizableFile, feature_category: :mlops do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_length_of(:name).is_at_most(255) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:file) }
  end

  describe 'AttachmentUploader' do
    it 'uploads the attachment when supplied' do
      file = create(:ai_vectorizable_file)
      expect(file.file.read).to start_with("Lorem")
    end

    it 'returns an error when the supplied file is too large' do
      file = create(:ai_vectorizable_file)
      allow(file.file).to receive(:size).and_return(Gitlab::CurrentSettings.max_attachment_size.megabytes.to_i + 1)
      file.valid?

      expect(file.errors.full_messages).to include("File is too big (should be at most 100 MiB)")
    end
  end

  describe '#uploads_sharding_key' do
    it 'returns project_id' do
      project = build_stubbed(:project)
      file = build_stubbed(:ai_vectorizable_file, project: project)

      expect(file.uploads_sharding_key).to eq(project_id: project.id)
    end
  end
end
