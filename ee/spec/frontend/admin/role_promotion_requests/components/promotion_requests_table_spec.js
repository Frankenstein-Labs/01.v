import { GlTable } from '@gitlab/ui';
import PromotionRequestsTable from 'ee/admin/role_promotion_requests/components/promotion_requests_table.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { defaultProvide, selfManagedUsersQueuedForRolePromotion } from '../mock_data';

describe('PromotionRequestsTable', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);

  const list =
    selfManagedUsersQueuedForRolePromotion.data.selfManagedUsersQueuedForRolePromotion.nodes;

  const createComponent = () => {
    wrapper = mountExtended(PromotionRequestsTable, {
      propsData: {
        list,
        isLoading: false,
      },
      provide: defaultProvide,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('renders pending promotion users table', () => {
    it('renders the table with rows corresponding to the mocked data', () => {
      expect(findTable().exists()).toBe(true);

      expect(findTable().findAll('tbody > tr')).toHaveLength(list.length);
    });

    it('renders promotions requests inside the table', () => {
      const firstRowCells = findTable().findAll('tbody > tr').at(0).findAll('td');

      expect(firstRowCells.at(0).text()).toContain('@jacquelin');
      expect(firstRowCells.at(1).text()).toBe('DEVELOPER');
      expect(firstRowCells.at(2).text()).toBe('Nov 03, 2023');
    });

    describe('actions', () => {
      it('emits approve event', () => {
        wrapper.findByRole('button', { name: 'Approve' }).trigger('click');
        expect(wrapper.emitted('approve')).toStrictEqual([[list[0].user.id]]);
      });

      it('emits reject event', () => {
        wrapper.findByRole('button', { name: 'Reject' }).trigger('click');
        expect(wrapper.emitted('reject')).toStrictEqual([[list[0].user.id]]);
      });
    });
  });
});
