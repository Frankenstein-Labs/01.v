# frozen_string_literal: true

FactoryBot.define do
  factory :xray_report, class: 'Projects::XrayReport' do
    project
    lang { 'ruby' }
    payload do
      {
        'file_paths' => ['Gemfile.lock'],
        'libs' =>
          [
            { 'name' => 'bcrypt (3.1.20)' },
            { 'name' => 'logger (1.5.3)' }
          ]
      }
    end
  end
end
