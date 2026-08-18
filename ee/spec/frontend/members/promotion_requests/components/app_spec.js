import { GlLink, GlAlert, GlKeysetPagination, GlTable } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import projectPendingMemberApprovalsQueryMockData from 'test_fixtures/graphql/members/promotion_requests/project_pending_member_approvals.json';
import groupPendingMemberApprovalsQueryMockData from 'test_fixtures/graphql/members/promotion_requests/group_pending_member_approvals.json';
import GroupPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/group_pending_member_approvals.query.graphql';
import ProjectPendingMemberApprovalsQuery from 'ee/members/promotion_requests/graphql/project_pending_member_approvals.query.graphql';
import { CONTEXT_TYPE } from 'ee/members/constants';
import PromotionRequestsApp from 'ee/members/promotion_requests/components/app.vue';
import UserAvatar from 'ee/members/promotion_requests/components/user_avatar.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEFAULT_PER_PAGE } from '~/api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import UserDate from '~/vue_shared/components/user_date.vue';
import { groupDefaultProvide, projectDefaultProvide } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('PromotionRequestsApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findGlTable = () => wrapper.findComponent(GlTable);
  const findGlKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findGlAlert = () => wrapper.findComponent(GlAlert);

  const pendingMemberApprovalsQueryHandler = jest.fn();

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = mountExtended(PromotionRequestsApp, {
      provide: {
        ...provide,
      },
      apolloProvider: createMockApollo([
        [GroupPendingMemberApprovalsQuery, pendingMemberApprovalsQueryHandler],
        [ProjectPendingMemberApprovalsQuery, pendingMemberApprovalsQueryHandler],
      ]),
    });

    return nextTick();
  };

  const findTable = () => wrapper.findComponent(GlTable);

  beforeEach(() => {
    pendingMemberApprovalsQueryHandler.mockReset();
  });

  describe('mounted', () => {
    it('renders a description paragraph with a link to the feature documentation', async () => {
      await createComponent({ provide: groupDefaultProvide });
      const descriptionElement = wrapper.findByTestId('description');
      expect(descriptionElement.text()).toBe(
        'Role promotions must be approved by an administrator. This setting can be changed in the Admin area. Learn more.',
      );

      expect(descriptionElement.findComponent(GlLink).attributes('href')).toBe(
        '/help/administration/settings/sign_up_restrictions#turn-on-administrator-approval-for-role-promotions',
      );
    });
  });

  describe.each([
    {
      context: CONTEXT_TYPE.GROUP,
      provide: groupDefaultProvide,
      mockData: groupPendingMemberApprovalsQueryMockData,
      result: groupPendingMemberApprovalsQueryMockData.data.group.pendingMemberApprovals,
    },
    {
      context: CONTEXT_TYPE.PROJECT,
      provide: projectDefaultProvide,
      mockData: projectPendingMemberApprovalsQueryMockData,
      result: projectPendingMemberApprovalsQueryMockData.data.project.pendingMemberApprovals,
    },
  ])('$context promotion requests', ({ provide, mockData, result }) => {
    beforeEach(async () => {
      pendingMemberApprovalsQueryHandler.mockResolvedValue(mockData);
      await createComponent({ provide });
      await waitForPromises();
    });

    describe('Pending promotion requests table', () => {
      it('renders the table with rows corresponding to mocked data', () => {
        expect(findTable().exists()).toBe(true);

        expect(findTable().findAll('tbody > tr')).toHaveLength(result.nodes.length);
      });

      it('renders the mocked data properly inside a row', () => {
        const firstRowCells = findTable().findAll('tbody > tr').at(0).findAll('td');
        const userAvatar = firstRowCells.at(0).findComponent(UserAvatar);
        expect(userAvatar.props('user')).toEqual(result.nodes[0].user);
        expect(firstRowCells.at(1).text()).toBe(result.nodes[0].newAccessLevel.stringValue);
        expect(firstRowCells.at(2).text()).toBe(result.nodes[0].requestedBy.name);
        expect(firstRowCells.at(3).findComponent(UserDate).exists()).toBe(true);
        expect(firstRowCells.at(3).findComponent(UserDate).props('date')).toBe(
          result.nodes[0].createdAt,
        );
      });
    });

    describe('pagination', () => {
      it('will display the pagination', () => {
        const pagination = findGlKeysetPagination();
        const { endCursor, hasNextPage, hasPreviousPage, startCursor } = result.pageInfo;

        expect(pagination.props()).toEqual(
          expect.objectContaining({ endCursor, hasNextPage, hasPreviousPage, startCursor }),
        );
      });

      it('will emit pagination', async () => {
        const pagination = findGlKeysetPagination();
        const after = result.pageInfo.endCursor;
        pagination.vm.$emit('next', after);
        await waitForPromises();
        expect(pendingMemberApprovalsQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after,
            first: null,
            last: DEFAULT_PER_PAGE,
          }),
        );
      });
    });

    describe('Loading state', () => {
      beforeEach(async () => {
        pendingMemberApprovalsQueryHandler.mockReturnValue(new Promise(() => {}));
        createComponent({ provide });
        await waitForPromises();
      });

      it('will set :busy on the GlTable', () => {
        const table = findGlTable();
        expect(table.attributes()).toEqual(expect.objectContaining({ 'aria-busy': 'true' }));
      });

      it('will set disabled on the GlKeysetPagination props', () => {
        const pagination = findGlKeysetPagination();
        expect(pagination.props()).toEqual(expect.objectContaining({ disabled: true }));
      });
    });

    describe('Error state', () => {
      beforeEach(async () => {
        jest.spyOn(Sentry, 'captureException');
        pendingMemberApprovalsQueryHandler.mockRejectedValue({ error: Error('Error') });
        createComponent({ provide });
        await waitForPromises();
      });

      afterEach(() => {
        Sentry.captureException.mockRestore();
      });

      it('will display an error alert', () => {
        expect(findGlAlert().exists()).toBe(true);
      });

      it('will report the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      });
    });
  });
});
