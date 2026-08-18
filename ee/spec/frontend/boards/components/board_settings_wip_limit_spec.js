import { GlFormInput, GlForm, GlCollapsibleListbox } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import BoardSettingsWipLimit from 'ee_component/boards/components/board_settings_wip_limit.vue';
import listUpdateLimitMetricsMutation from 'ee_component/boards/graphql/list_update_limit_metrics.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockLabelList } from 'jest/boards/mock_data';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { WIP_ITEMS, WIP_WEIGHT } from 'ee_else_ce/boards/constants';
import { mockUpdateListWipLimitResponse } from '../mock_data';

Vue.use(VueApollo);

describe('BoardSettingsWipLimit', () => {
  let wrapper;
  let mockApollo;
  const listId = mockLabelList.id;

  const findRemoveWipLimit = () => wrapper.findComponentByTestId('remove-limit');
  const findWipLimit = () => wrapper.findByTestId('wip-limit');
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findGlForm = () => wrapper.findComponent(GlForm);
  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  const listUpdateLimitMetricsMutationHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateListWipLimitResponse);

  const createComponent = ({
    localState = {},
    props = { maxIssueCount: 0, maxIssueWeight: 0 },
    injectedProps = {},
    listUpdateWipLimitMutationHandler = listUpdateLimitMetricsMutationHandler,
  }) => {
    mockApollo = createMockApollo([
      [listUpdateLimitMetricsMutation, listUpdateWipLimitMutationHandler],
    ]);

    wrapper = shallowMountExtended(BoardSettingsWipLimit, {
      apolloProvider: mockApollo,
      provide: injectedProps,
      propsData: {
        activeListId: listId,
        ...props,
      },
      data() {
        return localState;
      },
    });
  };

  const clickEdit = async () => {
    wrapper.findComponentByTestId('edit-button').vm.$emit('click');
    await nextTick();
  };

  const triggerEvent = async (type) => {
    if (type === 'focusout') {
      findGlForm().vm.$emit('focusout', {
        relatedTarget: null,
      });
    }

    if (type === 'enter') {
      findInput().trigger('keydown.enter', {
        relatedTarget: null,
      });
    }
    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  describe('when activeList is present', () => {
    it('renders "None" when no WIP limit is set', () => {
      createComponent({ props: { maxIssueCount: 0, maxIssueWeight: 0 } });

      expect(findWipLimit().text()).toBe('None');
    });

    describe('when WIP limit is based on number of issues', () => {
      it.each`
        num   | expected
        ${1}  | ${'Item - 1'}
        ${11} | ${'Items - 11'}
      `('renders $num', ({ num, expected }) => {
        createComponent({
          props: { maxIssueCount: num, maxIssueWeight: 0 },
        });

        expect(findWipLimit().text()).toBe(expected);
      });
    });

    describe('when WIP limit is based on weight', () => {
      it.each`
        weight | expected
        ${5}   | ${'Weight - 5'}
        ${10}  | ${'Weight - 10'}
      `('renders $weight', ({ weight, expected }) => {
        createComponent({
          props: { maxIssueCount: 0, maxIssueWeight: weight, currentLimitMetric: WIP_WEIGHT },
        });

        expect(findWipLimit().text()).toBe(expected);
      });
    });
  });

  describe('editing the WIP limit', () => {
    beforeEach(async () => {
      createComponent({ props: { maxIssueCount: 4, maxIssueWeight: 0 } });

      await clickEdit();
    });

    it('renders an input field', () => {
      expect(findInput().exists()).toBe(true);
    });

    it('renders a dropdown to select WIP category', () => {
      expect(findDropdown().exists()).toBe(true);
    });

    it('displays the correct initial input value', () => {
      expect(findInput().attributes('value')).toBe('4');
    });
  });

  describe('removing WIP limit', () => {
    beforeEach(() => {
      createComponent({
        props: { maxIssueCount: 4, maxIssueWeight: 5, currentLimitMetric: WIP_WEIGHT },
      });
    });

    it('resets WIP limit to 0 when remove button is clicked', async () => {
      expect(findWipLimit().text()).toContain('Weight - 5');

      findRemoveWipLimit().vm.$emit('click');
      await waitForPromises();
      await nextTick();

      expect(listUpdateLimitMetricsMutationHandler).toHaveBeenCalledWith({
        input: { listId, maxIssueCount: 0, maxIssueWeight: 0, limitMetric: WIP_WEIGHT },
      });
    });
  });

  describe('updating WIP limit', () => {
    it('should update limit based on selected category when focusout event occurs', async () => {
      createComponent({
        localState: { edit: true, currentWipLimit: 6, selectedWIPCategory: WIP_ITEMS },
      });

      await findDropdown().vm.$emit('select', WIP_ITEMS);
      await waitForPromises();

      await findInput().vm.$emit('input', 6);
      await waitForPromises();

      await triggerEvent('focusout');

      expect(listUpdateLimitMetricsMutationHandler).toHaveBeenCalledWith({
        input: {
          listId,
          maxIssueCount: 6,
          maxIssueWeight: 0,
          limitMetric: WIP_ITEMS,
        },
      });
    });
  });
});
