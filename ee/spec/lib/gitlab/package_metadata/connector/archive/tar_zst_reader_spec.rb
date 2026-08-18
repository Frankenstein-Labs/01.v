# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::PackageMetadata::Connector::Archive::TarZstReader, feature_category: :software_composition_analysis do
  # Builds an in-memory .tar.zst archive from a { filename => contents } hash so
  # the tests exercise the real zstd decompression + tar walk without binary
  # fixtures.
  def build_archive(files)
    tar = StringIO.new
    Gem::Package::TarWriter.new(tar) do |writer|
      files.each do |name, contents|
        writer.add_file(name, 0o644) { |io| io.write(contents) }
      end
    end
    Zstd.compress(tar.string)
  end

  let(:chunk_one) { %({"advisory_xid":"a"}\n{"advisory_xid":"b"}\n) }
  let(:chunk_two) { %({"advisory_xid":"c"}\n) }

  describe '#each_entry' do
    context 'with a delta archive (NDJSON chunks, no checkpoint.json)' do
      let(:archive_bytes) do
        build_archive('00000001.ndjson' => chunk_one, '00000002.ndjson' => chunk_two)
      end

      subject(:reader) { described_class.new(archive_bytes) }

      it 'yields one entry per NDJSON file in tarball order' do
        names = reader.each_entry.map(&:name)

        expect(names).to eq(%w[00000001.ndjson 00000002.ndjson])
      end

      it 'exposes the chunk number parsed from the file name' do
        chunks = reader.each_entry.map(&:chunk)

        expect(chunks).to match_array([1, 2])
      end

      it 'exposes the file contents through the entry IO' do
        contents = reader.each_entry.map { |entry| entry.io.read }

        expect(contents).to match_array([chunk_one, chunk_two])
      end

      it 'returns an enumerator when called without a block' do
        expect(reader.each_entry).to be_a(Enumerator)
      end
    end

    context 'when the archive contains non-NDJSON files alongside chunks' do
      let(:archive_bytes) do
        build_archive(
          'checkpoint.json' => '{"until":1780656046}',
          'README.txt' => 'ignore me',
          '00/000000000.ndjson' => chunk_one
        )
      end

      subject(:reader) { described_class.new(archive_bytes) }

      it 'yields only the NDJSON entries, preserving the sharded path as the name' do
        names = reader.each_entry.map(&:name)

        expect(names).to contain_exactly('00/000000000.ndjson')
      end
    end
  end

  describe 'Entry#shard_index' do
    using RSpec::Parameterized::TableSyntax

    where(:entry_name, :expected) do
      '00/000000000.ndjson' | 0
      '0a/000000000.ndjson' | 10
      'ff/000000000.ndjson' | 255   # base-16: "ff".to_i would be 0
      'FF/000000000.ndjson' | 255   # uppercase: regex is case-insensitive
      '000000000.ndjson'    | nil   # flat delta entry, no shard dir
      'README/x.ndjson'     | nil   # non-hex directory
    end

    with_them do
      it 'parses the two-hex-digit shard directory as a base-16 index' do
        archive = build_archive(entry_name => chunk_one)
        entry = described_class.new(archive).each_entry.first

        expect(entry.shard_index).to eq(expected)
      end
    end
  end

  describe '#checkpoint_until' do
    subject(:checkpoint_until) { described_class.new(archive_bytes).checkpoint_until }

    context 'with a full-dataset archive carrying checkpoint.json' do
      let(:archive_bytes) do
        build_archive(
          'checkpoint.json' => '{"until":1780656046}',
          '00/000000000.ndjson' => chunk_one
        )
      end

      it { is_expected.to eq(1780656046) }
    end

    context 'with a delta archive that has no checkpoint.json' do
      let(:archive_bytes) { build_archive('00000001.ndjson' => chunk_one) }

      it { is_expected.to be_nil }
    end

    context 'when checkpoint.json is not a JSON object' do
      let(:archive_bytes) do
        build_archive('checkpoint.json' => '[1, 2, 3]', '00000001.ndjson' => chunk_one)
      end

      it { is_expected.to be_nil }
    end

    context 'when checkpoint.json is malformed' do
      let(:archive_bytes) do
        build_archive('checkpoint.json' => 'not-json', '00000001.ndjson' => chunk_one)
      end

      it 'returns nil rather than propagating a parse error' do
        expect(checkpoint_until).to be_nil
      end
    end
  end

  describe 'decompression failures' do
    subject(:reader) { described_class.new('not a zstd stream') }

    it 'wraps the underlying zstd error in DecompressionError' do
      expect { reader.each_entry.to_a }
        .to raise_error(described_class::DecompressionError, /zstd decompression failed/)
    end
  end

  describe 'memoization' do
    let(:archive_bytes) { build_archive('00000001.ndjson' => chunk_one) }

    it 'decompresses the archive only once across each_entry and checkpoint_until' do
      reader = described_class.new(archive_bytes)

      expect(Zstd).to receive(:decompress).once.and_call_original

      reader.each_entry.to_a
      reader.checkpoint_until
    end
  end
end
