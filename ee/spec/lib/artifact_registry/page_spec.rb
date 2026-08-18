# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ArtifactRegistry::Page, feature_category: :artifact_registry do
  let(:nodes) do
    [
      ArtifactRegistry::Repository.new('name' => 'first'),
      ArtifactRegistry::Repository.new('name' => 'second')
    ]
  end

  describe 'readers' do
    subject(:page) do
      described_class.new(nodes: nodes, next_cursor: 'next-token', prev_cursor: 'prev-token')
    end

    it 'exposes the nodes array and the opaque next/prev cursors', :aggregate_failures do
      expect(page.nodes).to eq(nodes)
      expect(page.next_cursor).to eq('next-token')
      expect(page.prev_cursor).to eq('prev-token')
    end
  end

  describe 'the rows a page can carry' do
    {
      'Repository' => -> { ArtifactRegistry::Repository.new('name' => 'a-repo') },
      'MavenPackage' => -> { ArtifactRegistry::MavenPackage.new('artifact_id' => 'core') },
      'NpmPackage' => -> { ArtifactRegistry::NpmPackage.new('name' => '@acme/ui') },
      'Image' => -> { ArtifactRegistry::Image.new('name' => 'api-gateway') }
    }.each do |row_class, build_row|
      it "carries a #{row_class} row without inspecting it" do
        row = build_row.call

        expect(described_class.new(nodes: [row]).nodes).to eq([row])
      end
    end
  end

  context 'when the cursors are omitted (a single, unpaginated page)' do
    subject(:page) { described_class.new(nodes: nodes) }

    it 'defaults both cursors to nil', :aggregate_failures do
      expect(page.nodes).to eq(nodes)
      expect(page.next_cursor).to be_nil
      expect(page.prev_cursor).to be_nil
    end
  end

  context 'when there are no nodes' do
    subject(:page) { described_class.new(nodes: []) }

    it 'exposes an empty array without raising' do
      expect(page.nodes).to eq([])
    end
  end

  context 'when the nodes are nil' do
    subject(:page) { described_class.new(nodes: nil) }

    it 'coerces them to an empty array' do
      expect(page.nodes).to eq([])
    end
  end

  describe 'the exposed collection' do
    subject(:page) { described_class.new(nodes: nodes) }

    it 'is frozen so that consumers cannot mutate the page' do
      expect { page.nodes << ArtifactRegistry::Repository.new('name' => 'third') }
        .to raise_error(FrozenError)
    end
  end
end
