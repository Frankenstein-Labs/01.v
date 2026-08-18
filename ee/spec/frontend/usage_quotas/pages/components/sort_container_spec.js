import { GlSorting } from '@gitlab/ui';
import { nextTick } from 'vue';
import { SORT_OPTION } from 'ee/usage_quotas/pages/constants';
import SortContainer from 'ee/usage_quotas/pages/components/sort_container.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('SortContainer', () => {
  let wrapper;

  const findGlSortComponent = () => wrapper.findComponent(GlSorting);

  const createComponent = () => {
    wrapper = shallowMountExtended(SortContainer);
  };

  beforeEach(() => {
    createComponent();
  });

  it('passes the correct sort options to the GlSorting component', () => {
    expect(findGlSortComponent().props('sortOptions')).toEqual([
      {
        value: SORT_OPTION.CREATED,
        text: 'Created Date',
      },
      {
        value: SORT_OPTION.UPDATED,
        text: 'Updated Date',
      },
    ]);
  });

  it.each`
    sortAttribute          | sortDirectionAscending | expectResult
    ${SORT_OPTION.CREATED} | ${true}                | ${'CREATED_ASC'}
    ${SORT_OPTION.CREATED} | ${false}               | ${'CREATED_DESC'}
    ${SORT_OPTION.UPDATED} | ${true}                | ${'UPDATED_ASC'}
    ${SORT_OPTION.UPDATED} | ${false}               | ${'UPDATED_DESC'}
  `(
    `emits $expectResult when selecting $sortAttribute with ascending direction set to $sortDirectionAscending`,
    async ({ sortAttribute, sortDirectionAscending, expectResult }) => {
      findGlSortComponent().vm.$emit('sortByChange', sortAttribute);
      findGlSortComponent().vm.$emit('sortDirectionChange', sortDirectionAscending);

      await nextTick();

      const events = wrapper.emitted('update');

      expect(events[events.length - 1]).toEqual([expectResult]);
    },
  );
});
