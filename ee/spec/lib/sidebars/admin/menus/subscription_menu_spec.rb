# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::SubscriptionMenu, feature_category: :navigation do
  it_behaves_like 'Admin menu with custom ability',
    link: '/admin/subscription',
    title: s_('Admin|Subscription'),
    icon: 'license',
    custom_ability: :read_admin_subscription

  it_behaves_like 'Admin menu without sub menus', active_routes: { controller: :subscriptions }
end
