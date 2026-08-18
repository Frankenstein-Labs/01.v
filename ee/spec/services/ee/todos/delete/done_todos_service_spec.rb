# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Todos::Delete::DoneTodosService, feature_category: :notifications do
  let!(:todo1) { create(:todo, state: :done) }
  let!(:todo2) { create(:todo, state: :done) }
  let!(:todo3) { create(:todo, state: :done) }
  let!(:todo4) { create(:todo, state: :pending) }

  it 'deletes todos specified in the argument' do
    expect do
      described_class.new.execute(Todo.where(id: [todo1.id, todo2.id]))
    end.to change { Todo.count }.by(-2)

    expect { todo1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect { todo2.reload }.to raise_error(ActiveRecord::RecordNotFound)

    expect(Todo.find(todo3.id)).to be_present
  end

  it 'deletes only done todos specified in the argument' do
    expect do
      described_class.new.execute(Todo.where(id: [todo1.id, todo2.id, todo4.id]))
    end.to change { Todo.count }.by(-2)

    expect { todo1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect { todo2.reload }.to raise_error(ActiveRecord::RecordNotFound)

    expect(Todo.find(todo3.id)).to be_present
    expect(Todo.find(todo4.id)).to be_present
  end
end
