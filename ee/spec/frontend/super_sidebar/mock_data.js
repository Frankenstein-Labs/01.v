import { PROMO_URL } from '~/constants';
import invalidUrl from '~/lib/utils/invalid_url';
import { userMenuMockPipelineMinutes, userMenuMockStatus } from 'jest/super_sidebar/mock_data';

export const userMenuMockData = {
  name: 'Orange Fox',
  username: 'thefox',
  admin_mode: {
    user_is_admin: false,
    admin_mode_feature_enabled: false,
    admin_mode_active: false,
  },
  avatar_url: invalidUrl,
  status: userMenuMockStatus,
  pipeline_minutes: userMenuMockPipelineMinutes,
};

export const createNewMenuGroups = [
  {
    name: 'This group',
    items: [
      {
        text: 'New project/repository',
        href: '/projects/new?namespace_id=22',
      },
      {
        text: 'New subgroup',
        href: '/groups/new?parent_id=22#create-group-pane',
      },
      {
        text: 'New epic',
        component: 'create_new_work_item_modal',
      },
      {
        text: 'Invite members',
        component: 'invite_members',
      },
    ],
  },
  {
    name: 'GitLab',
    items: [
      {
        text: 'New project/repository',
        href: '/projects/new',
      },
      {
        text: 'New group',
        href: '/groups/new',
      },
      {
        text: 'New snippet',
        href: '/-/snippets/new',
      },
    ],
  },
];

export const mergeRequestMenuGroup = [
  {
    name: 'Merge requests',
    items: [
      {
        text: 'Assigned',
        href: '/dashboard/merge_requests?assignee_username=root',
        count: 4,
        extraAttrs: {
          'data-track-action': 'click_link',
          'data-track-label': 'merge_requests_assigned',
          'data-track-property': 'nav_core_menu',
          class: 'dashboard-shortcuts-merge_requests',
        },
      },
      {
        text: 'Review requests',
        href: '/dashboard/merge_requests?reviewer_username=root',
        count: 0,
        extraAttrs: {
          'data-track-action': 'click_link',
          'data-track-label': 'merge_requests_to_review',
          'data-track-property': 'nav_core_menu',
          class: 'dashboard-shortcuts-review_requests',
        },
      },
    ],
  },
];

export const sidebarData = {
  is_logged_in: true,
  is_admin: false,
  current_menu_items: [{ text: 'test' }],
  current_context: {},
  current_context_header: 'Your work',
  name: 'Administrator',
  username: 'root',
  avatar_url: 'path/to/img_administrator',
  logo_url: 'path/to/logo',
  user_counts: {
    last_update: Date.now(),
    todos: 3,
    assigned_issues: 1,
    assigned_merge_requests: 3,
    review_requested_merge_requests: 1,
  },
  create_new_menu_groups: createNewMenuGroups,
  merge_request_menu: mergeRequestMenuGroup,
  support_path: '/support',
  compare_plans_url: `${PROMO_URL}/pricing`,
  display_whats_new: true,
  whats_new_most_recent_release_items_count: 5,
  whats_new_version_digest: 1,
  show_version_check: false,
  gitlab_version: { major: 16, minor: 0 },
  gitlab_version_check: { severity: 'success' },
  gitlab_com_and_canary: false,
  search: {},
  pinned_items: [],
  panel_type: 'your_work',
  shortcut_links: [
    {
      title: 'Shortcut link',
      href: '/shortcut-link',
      css_class: 'shortcut-link-class',
    },
  ],
};

export const sidebarDataCountResponse = ({
  openIssuesCount = 8,
  openMergeRequestsCount = 236456,
  openEpicsCount = null,
  openWorkItemsCount = 5,
} = {}) => {
  return {
    data: {
      namespace: {
        id: 'gid://gitlab/Project/11',
        sidebar: {
          openIssuesCount,
          openMergeRequestsCount,
          openEpicsCount,
          openWorkItemsCount,
          __typename: 'NamespaceSidebar',
        },
        __typename: 'Namespace',
      },
    },
  };
};
