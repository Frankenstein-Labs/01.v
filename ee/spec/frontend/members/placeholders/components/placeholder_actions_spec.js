import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { fetchGroupEnterpriseUsers } from 'ee_else_ce/api/groups_api';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import PlaceholderActions from '~/members/placeholders/components/placeholder_actions.vue';

import { mockSourceUsers } from 'jest/members/placeholders/mock_data';

import {
  mockEnterpriseUser1,
  mockEnterpriseUser2,
  mockEnterpriseUsersQueryResponse,
  mockEnterpriseUsersWithPaginationQueryResponse,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('ee_component/api/groups_api');

describe('PlaceholderActions', () => {
  let wrapper;

  const defaultProps = {
    sourceUser: mockSourceUsers[0],
  };

  const $toast = {
    show: jest.fn(),
  };

  const createComponent = ({ provide = {}, props = {} } = {}) => {
    wrapper = shallowMountExtended(PlaceholderActions, {
      apolloProvider: createMockApollo(),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...provide,
      },
      mocks: { $toast },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  afterEach(() => {
    fetchGroupEnterpriseUsers.mockClear();
  });

  describe('when restrictReassignmentToEnterprise is false', () => {
    beforeEach(() => {
      createComponent({
        provide: { restrictReassignmentToEnterprise: false },
      });
    });

    it('does not call fetchGroupEnterpriseUsers on listbox `shown` event', async () => {
      await findListbox().vm.$emit('shown');
      await waitForPromises();

      expect(fetchGroupEnterpriseUsers).not.toHaveBeenCalled();
    });
  });

  describe('when restrictReassignmentToEnterprise is true', () => {
    beforeEach(() => {
      createComponent({
        provide: { restrictReassignmentToEnterprise: true },
      });
    });

    it('calls fetchGroupEnterpriseUsers on listbox `shown` event', async () => {
      fetchGroupEnterpriseUsers.mockResolvedValueOnce(
        mockEnterpriseUsersWithPaginationQueryResponse,
      );

      await findListbox().vm.$emit('shown');

      expect(findListbox().props('loading')).toBe(true);
      expect(fetchGroupEnterpriseUsers).toHaveBeenCalledTimes(1);

      await waitForPromises();

      expect(findListbox().props('loading')).toBe(false);
      expect(findListbox().props('items')).toHaveLength(1);
    });

    describe('when the component is opened multiple times', () => {
      beforeEach(() => {
        fetchGroupEnterpriseUsers.mockResolvedValueOnce(
          mockEnterpriseUsersWithPaginationQueryResponse,
        );
      });

      it('does not call fetchGroupEnterpriseUsers again', async () => {
        await findListbox().vm.$emit('shown');
        await waitForPromises();

        await findListbox().vm.$emit('shown');
        await waitForPromises();

        expect(fetchGroupEnterpriseUsers).toHaveBeenCalledTimes(1);
      });
    });

    describe('when users query succeeds and has pagination', () => {
      beforeEach(async () => {
        fetchGroupEnterpriseUsers.mockResolvedValueOnce(
          mockEnterpriseUsersWithPaginationQueryResponse,
        );
        fetchGroupEnterpriseUsers.mockResolvedValueOnce(mockEnterpriseUsersQueryResponse());

        await findListbox().vm.$emit('shown');
        await waitForPromises();
      });

      describe('when "bottom-reached" event is emitted', () => {
        beforeEach(async () => {
          await findListbox().vm.$emit('bottom-reached');
        });

        it('calls fetchGroupEnterpriseUsers again to get next page', () => {
          expect(fetchGroupEnterpriseUsers).toHaveBeenCalledTimes(2);
        });

        it('appends query results to "enterpriseUsers"', () => {
          const allUsers = [mockEnterpriseUser2, mockEnterpriseUser1];

          expect(findListbox().props('items')).toHaveLength(allUsers.length);
        });
      });
    });

    describe('when users query succeeds and does not have pagination', () => {
      beforeEach(async () => {
        await findListbox().vm.$emit('shown');
        await waitForPromises();
      });

      describe('when "bottom-reached" event is emitted', () => {
        beforeEach(async () => {
          await findListbox().vm.$emit('bottom-reached');
        });

        it('does not call fetchGroupEnterpriseUsers again', () => {
          expect(fetchGroupEnterpriseUsers).toHaveBeenCalledTimes(1);
        });
      });
    });
  });
});
