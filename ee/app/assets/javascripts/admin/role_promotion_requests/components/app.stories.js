import createMockApollo from 'helpers/mock_apollo_helper';
import {
  defaultProvide,
  processUserLicenseSeatRequestMutationFailure,
  processUserLicenseSeatRequestMutationPartialSuccess,
  processUserLicenseSeatRequestMutationSuccess,
  selfManagedUsersQueuedForRolePromotion,
} from 'ee_jest/admin/role_promotion_requests/mock_data';
import usersQueuedForLicenseSeat from '../graphql/users_queued_for_license_seat.query.graphql';
import processUserLicenseSeatRequestMutation from '../graphql/process_user_license_seat_request.mutation.graphql';
import RolePromotionRequestsApp from './app.vue';

const meta = {
  title: 'ee/admin/role_promotion_requests/app',
  component: RolePromotionRequestsApp,
};

export default meta;

const createTemplate = (config = {}) => {
  let { provide, apolloProvider } = config;

  if (provide == null) {
    provide = {};
  }

  if (apolloProvider == null) {
    const requestHandlers = [
      [usersQueuedForLicenseSeat, () => Promise.resolve(selfManagedUsersQueuedForRolePromotion)],
      [
        processUserLicenseSeatRequestMutation,
        ({ userId }) => {
          // Mimic different response types for different users:
          const { nodes } =
            selfManagedUsersQueuedForRolePromotion.data.selfManagedUsersQueuedForRolePromotion;
          if (userId === nodes[0].user.id) {
            return Promise.reject(new Error('Some network error'));
          }
          if (userId === nodes[1].user.id) {
            return Promise.resolve(processUserLicenseSeatRequestMutationFailure);
          }
          if (userId === nodes[2].user.id) {
            return Promise.resolve(processUserLicenseSeatRequestMutationPartialSuccess);
          }
          return Promise.resolve(processUserLicenseSeatRequestMutationSuccess);
        },
      ],
    ];
    apolloProvider = createMockApollo(requestHandlers);
  }

  return (args, { argTypes }) => ({
    components: { RolePromotionRequestsApp },
    apolloProvider,
    provide: {
      ...defaultProvide,
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<role-promotion-requests-app />',
  });
};

export const Default = {
  render: createTemplate(),
};

export const LoadingState = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [usersQueuedForLicenseSeat, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};
LoadingState.parameters = {
  a11y: {
    config: {
      rules: [
        {
          id: 'color-contrast',
          enabled: false,
        },
      ],
    },
  },
  docs: {
    description: {
      story:
        'Loading state table uses `:busy` prop from BootstrapVue `BTable` component. Apart from suppressing interaction, it also adds `opacity: 0.6` to the whole table.',
    },
  },
};

export const ErrorState = {
  render: (...args) => {
    const apolloProvider = createMockApollo([[usersQueuedForLicenseSeat, () => Promise.reject()]]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};
