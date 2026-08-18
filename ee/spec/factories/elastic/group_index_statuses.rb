# frozen_string_literal: true

FactoryBot.define do
  factory :group_index_status, class: 'Elastic::GroupIndexStatus' do
    group { association(:group) }
  end
end
