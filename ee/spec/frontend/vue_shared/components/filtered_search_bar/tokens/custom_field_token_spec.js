import { GlFilteredSearchTokenSegment } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import customFieldOptionsQuery from 'ee/work_items/graphql/work_item_custom_field_select_options.query.graphql';
import CustomFieldToken from 'ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue';

jest.mock('~/alert');
Vue.use(VueApollo);

const mockCustomField = {
  id: 'gid://gitlab/IssuableCustomField/1',
  name: 'Priority',
  fieldType: 'SINGLE_SELECT',
  selectOptions: [
    {
      id: 'gid://gitlab/IssuableCustomFieldOption/1',
      value: 'High',
    },
    {
      id: 'gid://gitlab/IssuableCustomFieldOption/2',
      value: 'Medium',
    },
    {
      id: 'gid://gitlab/IssuableCustomFieldOption/3',
      value: 'Low',
    },
  ],
};

const mockCustomFieldToken = {
  field: {
    id: 'gid://gitlab/IssuableCustomField/1',
    name: 'Priority',
  },
};

const mockCustomFieldOptionsResponse = {
  data: {
    customField: mockCustomField,
  },
};

const defaultStubs = {
  Portal: true,
  GlFilteredSearchSuggestionList: {
    template: '<div></div>',
    methods: {
      getValue: () => '=',
    },
  },
};

describe('CustomFieldToken', () => {
  let wrapper;
  let mockApollo;

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const customFieldQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(mockCustomFieldOptionsResponse);
  const customFieldQueryHandlerError = jest.fn().mockRejectedValue({});

  function createComponent(options = {}, customFieldQueryHandler = customFieldQueryHandlerSuccess) {
    mockApollo = createMockApollo([[customFieldOptionsQuery, customFieldQueryHandler]]);
    const {
      config = mockCustomFieldToken,
      value = { data: '' },
      active = false,
      stubs = defaultStubs,
    } = options;
    wrapper = mount(CustomFieldToken, {
      apolloProvider: mockApollo,
      propsData: {
        config,
        value,
        active,
        cursorPosition: 'start',
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: function fakeAlignSuggestions() {},
        suggestionsListClass: () => 'custom-class',
        termsAsTokens: () => false,
      },
      stubs,
    });
  }

  describe('when request succeeds', () => {
    beforeEach(async () => {
      createComponent();
      findBaseToken().vm.$emit('fetch-suggestions');
      await waitForPromises();
    });

    it('calls query with correct variables', () => {
      expect(customFieldQueryHandlerSuccess).toHaveBeenCalledWith({
        fieldId: mockCustomFieldToken.field.id,
      });
    });

    it('sets response to `options`', () => {
      expect(findBaseToken().props('suggestions')).toEqual(mockCustomField.selectOptions);
    });

    it('sets `loading` to false when request completes', () => {
      expect(findBaseToken().props('suggestionsLoading')).toBe(false);
    });
  });

  describe('when request fails', () => {
    beforeEach(() => {
      createComponent({}, customFieldQueryHandlerError);
      findBaseToken().vm.$emit('fetch-suggestions');
      return waitForPromises();
    });

    it('calls `createAlert` with alert error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Options could not be loaded for field: Priority. Please try again.',
        captureError: true,
        error: expect.any(Object),
      });
    });

    it('sets `loading` to false when request completes', () => {
      expect(findBaseToken().props('suggestionsLoading')).toBe(false);
    });
  });

  it('does not make a query request when fieldId is undefined', async () => {
    createComponent({
      config: { field: undefined },
    });

    findBaseToken().vm.$emit('fetch-suggestions');
    await waitForPromises();

    expect(customFieldQueryHandlerSuccess).not.toHaveBeenCalled();
  });

  it('renders token item when value is selected', async () => {
    createComponent({
      value: { data: '1' },
    });

    findBaseToken().vm.$emit('fetch-suggestions');
    await waitForPromises();

    const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);
    expect(tokenSegments).toHaveLength(3);
  });

  it('passes correct props to BaseToken', async () => {
    createComponent();

    findBaseToken().vm.$emit('fetch-suggestions');
    await waitForPromises();

    const baseTokenProps = findBaseToken().props();
    expect(baseTokenProps.active).toBe(false);
    expect(baseTokenProps.config).toEqual(mockCustomFieldToken);
    expect(baseTokenProps.suggestions).toEqual(mockCustomField.selectOptions);
  });
});
