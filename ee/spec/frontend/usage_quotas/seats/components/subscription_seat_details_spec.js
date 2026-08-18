import { GlBadge, GlTableLite } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { cloneDeep } from 'lodash-es';
import SubscriptionSeatDetails from 'ee/usage_quotas/seats/components/subscription_seat_details.vue';
import SubscriptionSeatDetailsLoader from 'ee/usage_quotas/seats/components/subscription_seat_details_loader.vue';
import { createAlert } from '~/alert';
import { mockMemberDetails } from 'ee_jest/usage_quotas/seats/mock_data';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';

jest.mock('~/alert');
jest.mock('ee/api');
jest.mock('ee/api/groups_api');

Vue.use(VueApollo);

describe('SubscriptionSeatDetails', () => {
  let wrapper;

  const createComponent = ({
    membershipsResolver = { memberships: mockMemberDetails, hasIndirectMembership: false },
    mountFn = shallowMount,
  } = {}) => {
    const seatMemberId = 1;

    const resolvers = {
      Query: {
        billableMemberDetails() {
          return membershipsResolver;
        },
      },
    };

    const apolloProvider = createMockApollo([], resolvers);

    wrapper = mountFn(SubscriptionSeatDetails, {
      apolloProvider,
      propsData: {
        seatMemberId,
      },
      provide: {
        namespaceId: 1,
      },
      stubs: {
        GlTableLite,
      },
    });
  };

  const findRoleCell = () => wrapper.find('tbody td:nth-child(4)');

  describe('loading state', () => {
    it('displays skeleton loader', () => {
      // creating a resolver that doesn't resolve will trigger the loader
      const membershipsResolver = jest.fn();
      createComponent({ membershipsResolver });

      expect(wrapper.findComponent(SubscriptionSeatDetailsLoader).isVisible()).toBe(true);
    });
  });

  describe('error state', () => {
    beforeEach(() => {
      createComponent({
        membershipsResolver: jest.fn().mockRejectedValue(new Error('GraphQL networkError')),
      });
      return waitForPromises();
    });

    it('calls createAlert with error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while getting a billable member details.',
      });
    });
  });

  describe('membership role', () => {
    it('shows base role if there is no custom role', async () => {
      createComponent({ mountFn: mount });
      await waitForPromises();
      expect(findRoleCell().text()).toBe('Owner');
    });

    describe('when there is a custom role', () => {
      beforeEach(() => {
        const items = cloneDeep(mockMemberDetails);
        items[0].access_level.custom_role = { id: 1, name: 'Custom role name' };
        const membershipResolver = { memberships: items, hasIndirectMembership: false };
        createComponent({ mountFn: mount, membershipsResolver: membershipResolver });
        return waitForPromises();
      });

      it('shows custom role name', () => {
        expect(findRoleCell().text()).toContain('Custom role name');
      });

      it('shows custom role badge', () => {
        expect(wrapper.findComponent(GlBadge).text()).toBe('Custom role');
      });
    });
  });
});
