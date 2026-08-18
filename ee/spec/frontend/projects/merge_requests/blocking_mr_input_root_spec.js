import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { ENTER_KEY, TAB_KEY } from '~/lib/utils/keys';
import BlockingMrInputRoot from 'ee/projects/merge_requests/blocking_mr_input_root.vue';
import RelatedIssuableInput from '~/related_issues/components/related_issuable_input.vue';

describe('blocking mr input root', () => {
  let wrapper;

  const getInput = () => wrapper.findComponent(RelatedIssuableInput);
  const addTokenizedInput = (input) => {
    getInput().vm.$emit('add-issuable-form-input', {
      untouchedRawReferences: [input],
      touchedReference: '',
    });
  };
  const addInput = (input) => {
    getInput().vm.$emit('add-issuable-form-input', {
      untouchedRawReferences: [],
      touchedReference: input,
    });
  };
  const removeRef = (index) => {
    getInput().vm.$emit('pending-issuable-remove-request', index);
  };
  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(BlockingMrInputRoot, { propsData });
  };

  it('does not keep duplicate references', () => {
    createComponent();
    const input = '!1';

    addTokenizedInput(input);
    addTokenizedInput(input);

    expect(wrapper.vm.references).toEqual(['!1']);
  });

  it('updates input value to empty string when adding a tokenized input', () => {
    createComponent();

    addTokenizedInput('foo');

    expect(wrapper.vm.inputValue).toBe('');
  });

  it('updates input value to ref when typing into input (before adding whitespace)', () => {
    createComponent();

    addInput('foo');

    expect(wrapper.vm.inputValue).toBe('foo');
  });

  it('does not reorder when adding a ref that already exists', () => {
    const input = '!1';
    createComponent({
      existingRefs: [input, '!2'],
    });

    addTokenizedInput(input, wrapper);

    expect(wrapper.vm.references).toEqual(['!1', '!2']);
  });

  it('does not add empty reference on blur', () => {
    createComponent();

    getInput().vm.$emit('add-issuable-form-blur', '');

    expect(wrapper.vm.references).toHaveLength(0);
  });

  describe('"finish" keystrokes (Enter or Tab)', () => {
    const mockEvent = {
      preventDefault: jest.fn(),
      stopPropagation: jest.fn(),
      ctrlKey: false,
      key: ENTER_KEY,
      metaKey: false,
    };

    beforeEach(() => {
      mockEvent.ctrlKey = false;
      mockEvent.key = ENTER_KEY;
      mockEvent.metaKey = false;
      mockEvent.preventDefault.mockReset();
      mockEvent.stopPropagation.mockReset();
    });

    it.each`
      description | event
      ${'tabs'}   | ${mockEvent}
      ${'enters'} | ${mockEvent}
    `('prevent the default event behavior for $description', ({ event }) => {
      createComponent();

      getInput().vm.$emit('add-issuable-finish-entry', { value: 'x', event });

      expect(event.preventDefault).toHaveBeenCalledTimes(1);
      expect(event.stopPropagation).toHaveBeenCalledTimes(1);
    });

    it('do not add empty references', () => {
      createComponent();

      getInput().vm.$emit('add-issuable-finish-entry', { value: '', event: mockEvent });

      expect(wrapper.vm.references).toHaveLength(0);
    });

    it('add new tokens', () => {
      createComponent();

      getInput().vm.$emit('add-issuable-finish-entry', { value: '!1', event: mockEvent });
      getInput().vm.$emit('add-issuable-finish-entry', { value: '!2', event: mockEvent });

      expect(wrapper.vm.references).toEqual(['!1', '!2']);
    });

    describe('with modifiers', () => {
      it.each`
        modifier  | event
        ${'Cmd'}  | ${{ ...mockEvent, metaKey: true, key: TAB_KEY }}
        ${'Ctrl'} | ${{ ...mockEvent, ctrlKey: true, key: TAB_KEY }}
      `('$modifier does not affect the Tab handler', ({ event }) => {
        createComponent();

        getInput().vm.$emit('add-issuable-finish-entry', { value: '!1', event });

        expect(event.preventDefault).toHaveBeenCalledTimes(1);
        expect(event.stopPropagation).toHaveBeenCalledTimes(1);
        expect(wrapper.vm.references).toEqual(['!1']);
      });

      it.each`
        modifier  | event
        ${'Cmd'}  | ${{ ...mockEvent, metaKey: true }}
        ${'Ctrl'} | ${{ ...mockEvent, ctrlKey: true }}
      `('$modifier skips the special handler for Enter', ({ event }) => {
        createComponent();

        getInput().vm.$emit('add-issuable-finish-entry', { value: '!1', event });

        expect(event.preventDefault).toHaveBeenCalledTimes(0);
        expect(event.stopPropagation).toHaveBeenCalledTimes(0);
        expect(wrapper.vm.references).toEqual([]);
      });
    });
  });

  describe('hidden inputs', () => {
    const createHiddenInputExpectation = (selector) => (bool) => {
      // eslint-disable-next-line no-underscore-dangle
      expect(wrapper.find(selector).element._value).toBe(bool);
    };

    describe('update_blocking_merge_request_refs', () => {
      const expectShouldUpdateRefsToBe = createHiddenInputExpectation(
        'input[name="merge_request[update_blocking_merge_request_refs]"]',
      );

      it('is false when nothing happens', () => {
        createComponent();

        expectShouldUpdateRefsToBe(false);
      });

      it('is true after a ref is removed', async () => {
        createComponent({ existingRefs: ['!1'] });
        removeRef(0);

        await nextTick();
        expectShouldUpdateRefsToBe(true);
      });

      it('is true after a ref is added', async () => {
        createComponent();
        addTokenizedInput('foo');

        await nextTick();
        expectShouldUpdateRefsToBe(true);
      });
    });

    describe('remove_hidden_blocking_merge_requests', () => {
      const expectRemoveHiddenBlockingMergeRequestsToBe = createHiddenInputExpectation(
        'input[name="merge_request[update_blocking_merge_request_refs]"]',
      );
      const makeComponentWithHiddenMrs = () => {
        const hiddenMrsRef = '2 inaccessible merge requests';
        createComponent({
          containsHiddenBlockingMrs: true,
          existingRefs: ['!1', '!2', hiddenMrsRef],
        });
      };

      it('is true when nothing has happened', () => {
        makeComponentWithHiddenMrs();

        expectRemoveHiddenBlockingMergeRequestsToBe(false);
      });

      it('is false when removing any other MRs', () => {
        makeComponentWithHiddenMrs();

        expectRemoveHiddenBlockingMergeRequestsToBe(false);
      });

      it('is false when ref has been removed', async () => {
        makeComponentWithHiddenMrs();
        removeRef(2);

        await nextTick();
        expectRemoveHiddenBlockingMergeRequestsToBe(true);
      });
    });
  });
});
