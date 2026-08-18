# frozen_string_literal: true

FactoryBot.modify do
  factory :protected_tag_create_access_level, class: 'ProtectedTag::CreateAccessLevel' do
    user { nil }
    group { nil }
  end
end
