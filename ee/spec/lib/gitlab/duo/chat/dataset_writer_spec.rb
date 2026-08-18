# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::DatasetWriter, feature_category: :duo_chat do
  let(:output_dir) { '/tmp/dataset' }

  subject(:writer) { described_class.new(output_dir) }

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe '#initialize' do
    it 'creates the output directory if it does not exist' do
      expect { writer }.not_to raise_error
    end

    it 'creates a new file' do
      expect { writer }.to change { Dir["#{output_dir}/*.jsonl"].count }.by(1)
    end

    it 'creates a file with a random hex name and .jsonl extension' do
      allow(SecureRandom).to receive(:hex).and_return('abc123')

      writer
      expect(Dir["#{output_dir}/*.jsonl"].first).to eq("#{output_dir}/abc123.jsonl")
    end
  end

  describe '#write' do
    let(:completion) { { 'text' => 'Hello world' } }

    it 'writes the completion to the current file as JSON' do
      path = writer.send(:current_file).path
      writer.write(completion)
      writer.close
      expect(File.read(path)).to eq("{\"text\":\"Hello world\"}\n")
    end
  end
end
