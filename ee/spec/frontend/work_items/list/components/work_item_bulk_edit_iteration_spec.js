import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import groupIterationsQuery from 'ee/sidebar/queries/group_iterations.query.graphql';
import WorkItemBulkEditIteration from 'ee_component/work_items/list/components/work_item_bulk_edit_iteration.vue';
import { groupIterationsResponse } from 'jest/work_items/mock_data';
import { BULK_EDIT_NO_VALUE } from '~/work_items/constants';

jest.mock('~/alert');

Vue.use(VueApollo);

const listResults = [
  {
    options: [
      {
        text: 'Jul 6 – 19, 2022',
        title: null,
        value: 'gid://gitlab/Iteration/1194',
      },
    ],
    text: 'Minima aut consequatur magnam vero doloremque accusamus maxime repellat voluptatem qui.',
  },
  {
    options: [
      {
        text: 'Jul 6 – 19, 2022',
        title: null,
        value: 'gid://gitlab/Iteration/1185',
      },
    ],
    text: 'Quo velit perspiciatis saepe aut omnis voluptas ab eos.',
  },
  {
    options: [
      {
        text: 'Jun 22 – Jul 19, 2022',
        title: null,
        value: 'gid://gitlab/Iteration/1124',
      },
    ],
    text: 'Quod voluptates quidem ea eaque eligendi ex corporis.',
  },
];

describe('WorkItemBulkEditIteration component', () => {
  let wrapper;

  const iterationSearchQueryHandler = jest.fn().mockResolvedValue(groupIterationsResponse);

  const createComponent = ({
    props = {},
    searchQueryHandler = iterationSearchQueryHandler,
  } = {}) => {
    wrapper = mount(WorkItemBulkEditIteration, {
      apolloProvider: createMockApollo([[groupIterationsQuery, searchQueryHandler]]),
      propsData: {
        fullPath: 'group/project',
        isGroup: true,
        ...props,
      },
      stubs: {
        GlCollapsibleListbox,
        GlFormGroup: true,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const openListboxAndSelect = async (value) => {
    findListbox().vm.$emit('shown');
    findListbox().vm.$emit('select', value);
    await waitForPromises();
  };

  it('renders the form group', () => {
    createComponent();

    expect(findFormGroup().attributes('label')).toBe('Iteration');
  });

  it('renders a header and reset button', () => {
    createComponent();

    expect(findListbox().props()).toMatchObject({
      headerText: 'Select iteration',
      resetButtonLabel: 'Reset',
    });
  });

  it('resets the selected iteration when the Reset button is clicked', async () => {
    createComponent();

    await openListboxAndSelect('gid://gitlab/Iteration/1124');

    expect(findListbox().props('selected')).toBe('gid://gitlab/Iteration/1124');

    findListbox().vm.$emit('reset');
    await nextTick();

    expect(findListbox().props('selected')).toEqual([]);
  });

  describe('iterations query', () => {
    it('is not called before dropdown is shown', () => {
      createComponent();

      expect(iterationSearchQueryHandler).not.toHaveBeenCalled();
    });

    it('is called when dropdown is shown', async () => {
      createComponent();

      findListbox().vm.$emit('shown');
      await nextTick();

      expect(iterationSearchQueryHandler).toHaveBeenCalled();
    });

    it('emits an error when there is an error in the call', async () => {
      createComponent({ searchQueryHandler: jest.fn().mockRejectedValue(new Error('error!')) });

      findListbox().vm.$emit('shown');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        error: new Error('error!'),
        message: 'Failed to load iterations. Please try again.',
      });
    });
  });

  describe('listbox items', () => {
    it('renders all iterations grouped by cadence and "No iteration" by default', async () => {
      createComponent();

      findListbox().vm.$emit('shown');
      await waitForPromises();

      expect(findListbox().props('items')).toEqual([
        {
          text: 'No iteration',
          textSrOnly: true,
          options: [{ text: 'No iteration', value: BULK_EDIT_NO_VALUE }],
        },
        ...listResults,
      ]);
    });

    describe('with search', () => {
      it('displays search results', async () => {
        createComponent();

        findListbox().vm.$emit('shown');
        findListbox().vm.$emit('search', 'search query');
        await waitForPromises();

        expect(findListbox().props('items')).toEqual(listResults);
        expect(iterationSearchQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            title: '"search query"',
          }),
        );
      });
    });
  });

  describe('listbox text', () => {
    describe('with no selected iteration', () => {
      it('renders "Select iteration"', () => {
        createComponent();

        expect(findListbox().props('toggleText')).toBe('Select iteration');
      });
    });

    describe('with selected iteration', () => {
      it('renders the iteration cadence period', async () => {
        createComponent();

        await openListboxAndSelect('gid://gitlab/Iteration/1124');

        expect(findListbox().props('toggleText')).toBe('Jun 22 – Jul 19, 2022');
      });
    });

    describe('with "No iteration"', () => {
      it('renders "No iteration"', async () => {
        createComponent();

        await openListboxAndSelect(BULK_EDIT_NO_VALUE);

        expect(findListbox().props('toggleText')).toBe('No iteration');
      });
    });
  });
});
