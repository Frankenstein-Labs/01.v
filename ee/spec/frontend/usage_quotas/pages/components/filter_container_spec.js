import { GlFilteredSearch } from '@gitlab/ui';
import { nextTick } from 'vue';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import FilterContainer from 'ee/usage_quotas/pages/components/filter_container.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('FilterContainer', () => {
  let wrapper;

  const findGlFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  const createComponent = () => {
    wrapper = shallowMountExtended(FilterContainer);
  };

  beforeEach(() => {
    createComponent();
  });

  describe('passes the expected filterTokens to GlFilteredSearch', () => {
    it.each`
      type           | label                  | optionLabel   | value    | operator
      ${'active'}    | ${'Deployment status'} | ${'active'}   | ${true}  | ${OPERATORS_IS}
      ${'active'}    | ${'Deployment status'} | ${'inactive'} | ${false} | ${OPERATORS_IS}
      ${'versioned'} | ${'Environment'}       | ${'main'}     | ${false} | ${OPERATORS_IS}
      ${'versioned'} | ${'Environment'}       | ${'prefixed'} | ${true}  | ${OPERATORS_IS}
    `(
      `includes an option to set type "$label" (internal type=$type) to "$optionLabel" which returns the value $value`,
      ({ type, label, optionLabel, value, operator }) => {
        expect(findGlFilteredSearch().props('availableTokens')).toContainEqual(
          expect.objectContaining({
            type,
            title: label,
            operators: operator,
            options: expect.arrayContaining([
              expect.objectContaining({
                title: optionLabel,
                value,
              }),
            ]),
          }),
        );
      },
    );
  });

  it.each`
    description                   | filterValueFromChild                                                                           | expectedEmittedValue
    ${'no filter'}                | ${[]}                                                                                          | ${{}}
    ${'only active'}              | ${[{ type: 'active', value: { data: true } }]}                                                 | ${{ active: true }}
    ${'only inactive'}            | ${[{ type: 'active', value: { data: false } }]}                                                | ${{ active: false }}
    ${'only versioned'}           | ${[{ type: 'versioned', value: { data: true } }]}                                              | ${{ versioned: true }}
    ${'only unversioned'}         | ${[{ type: 'versioned', value: { data: false } }]}                                             | ${{ versioned: false }}
    ${'active and versioned'}     | ${[{ type: 'active', value: { data: true } }, { type: 'versioned', value: { data: true } }]}   | ${{ active: true, versioned: true }}
    ${'inactive and versioned'}   | ${[{ type: 'active', value: { data: false } }, { type: 'versioned', value: { data: true } }]}  | ${{ active: false, versioned: true }}
    ${'active and unversioned'}   | ${[{ type: 'active', value: { data: true } }, { type: 'versioned', value: { data: false } }]}  | ${{ active: true, versioned: false }}
    ${'inactive and unversioned'} | ${[{ type: 'active', value: { data: false } }, { type: 'versioned', value: { data: false } }]} | ${{ active: false, versioned: false }}
  `(
    'emits the correct filter object when selecting $description',
    async ({ filterValueFromChild, expectedEmittedValue }) => {
      findGlFilteredSearch().vm.$emit('submit', filterValueFromChild);
      await nextTick();
      expect(wrapper.emitted('update')).toEqual([[expectedEmittedValue]]);
    },
  );
});
