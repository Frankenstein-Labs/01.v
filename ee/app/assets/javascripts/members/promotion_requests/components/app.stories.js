import projectPendingMemberApprovalsQueryMockData from 'test_fixtures/graphql/members/promotion_requests/project_pending_member_approvals.json';
import groupPendingMemberApprovalsQueryMockData from 'test_fixtures/graphql/members/promotion_requests/group_pending_member_approvals.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  groupDefaultProvide,
  projectDefaultProvide,
} from 'ee_jest/members/promotion_requests/mock_data';
import GroupPendingMemberApprovalsQuery from '../graphql/group_pending_member_approvals.query.graphql';
import ProjectPendingMemberApprovalsQuery from '../graphql/project_pending_member_approvals.query.graphql';
import PromotionRequestsTabApp from './app.vue';

const meta = {
  title: 'ee/members/promotion_requests/app.vue',
  component: PromotionRequestsTabApp,
  parameters: {
    a11y: {
      config: {
        rules: [
          {
            id: 'aria-required-children',
            enabled: false,
          },
          {
            id: 'color-contrast',
            enabled: false,
          },
        ],
      },
    },
  },
};

export default meta;

const createTemplate = (config = {}) => {
  let { provide, apolloProvider } = config;

  if (provide == null) {
    provide = {};
  }

  if (apolloProvider == null) {
    const requestHandlers = [
      [
        GroupPendingMemberApprovalsQuery,
        () => Promise.resolve(groupPendingMemberApprovalsQueryMockData),
      ],
    ];
    apolloProvider = createMockApollo(requestHandlers);
  }

  return (args, { argTypes }) => ({
    components: { PromotionRequestsTabApp },
    apolloProvider,
    provide: {
      canManageMembers: true,
      ...groupDefaultProvide,
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<promotion-requests-tab-app />',
  });
};

export const Default = {
  render: createTemplate(),
};

export const LoadingState = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [GroupPendingMemberApprovalsQuery, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

export const ErrorState = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [GroupPendingMemberApprovalsQuery, () => Promise.reject()],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

export const ProjectLevelView = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [
        ProjectPendingMemberApprovalsQuery,
        () => Promise.resolve(projectPendingMemberApprovalsQueryMockData),
      ],
    ]);

    return createTemplate({
      provide: projectDefaultProvide,
      apolloProvider,
    })(...args);
  },
};
