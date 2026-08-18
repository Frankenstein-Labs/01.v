# frozen_string_literal: true

# This should be included on any Replicator which uses event names defined.

RSpec.shared_examples 'replicator event constants' do
  it 'defines EVENT_CREATED' do
    expect(::Geo::ReplicatorEvents::EVENT_CREATED).to eq('created')
  end

  it 'defines EVENT_UPDATED' do
    expect(::Geo::ReplicatorEvents::EVENT_UPDATED).to eq('updated')
  end

  it 'defines EVENT_DELETED' do
    expect(::Geo::ReplicatorEvents::EVENT_DELETED).to eq('deleted')
  end
end
